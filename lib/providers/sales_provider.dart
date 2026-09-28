import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import 'auth_provider.dart';

class SalesNotifier extends AsyncNotifier<List<Sale>> {
  @override
  Future<List<Sale>> build() async {
    return _fetchSales();
  }

  Future<List<Sale>> _fetchSales() async {
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase.from('sales').select('*, customers(name), farmers(name)').order('sale_date', ascending: false).limit(50);
    return (response as List).map((json) => Sale.fromJson(json)).toList();
  }

  Future<void> addSale({
    required String partyId,
    required String partyType, // 'Customer' or 'Farmer'
    required String productId,
    required double qty,
    required double rate,
    required double paidAmount,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      final totalAmount = qty * rate;
      final invoiceNo = 'INV-${DateTime.now().millisecondsSinceEpoch}';

      final insertData = {
        'invoice_no': invoiceNo,
        'sale_date': DateTime.now().toIso8601String().split('T')[0],
        'subtotal': totalAmount,
        'paid_amount': paidAmount,
        'payment_mode': 'Cash',
      };
      
      if (partyType == 'Customer') {
        insertData['customer_id'] = partyId;
      } else {
        insertData['farmer_id'] = partyId;
      }

      // 1. Insert into sales
      final saleRes = await supabase.from('sales').insert(insertData).select().single();
      final saleId = saleRes['id'];

      // 2. Insert into sale_items
      await supabase.from('sale_items').insert({
        'sale_id': saleId,
        'product_id': productId,
        'quantity': qty,
        'rate': rate,
      });

      // 3. Insert payment record if paid
      if (paidAmount > 0) {
        final paymentData = {
          'payment_date': DateTime.now().toIso8601String().split('T')[0],
          'party_type': partyType,
          'payment_type': 'In', 
          'amount': paidAmount,
          'payment_mode': 'Cash',
          'remarks': 'Paid for Sale $invoiceNo',
        };
        if (partyType == 'Customer') {
          paymentData['customer_id'] = partyId;
        } else {
          paymentData['farmer_id'] = partyId;
        }
        await supabase.from('payments').insert(paymentData);
      }

      state = await AsyncValue.guard(() => _fetchSales());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final salesProvider = AsyncNotifierProvider<SalesNotifier, List<Sale>>(() {
  return SalesNotifier();
});
