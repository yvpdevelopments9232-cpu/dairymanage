import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import 'auth_provider.dart';

class PurchaseNotifier extends AsyncNotifier<List<Purchase>> {
  @override
  Future<List<Purchase>> build() async {
    return _fetchPurchases();
  }

  Future<List<Purchase>> _fetchPurchases() async {
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase.from('purchases').select('*, suppliers(name)').order('purchase_date', ascending: false).limit(50);
    return (response as List).map((json) => Purchase.fromJson(json)).toList();
  }

  Future<void> addPurchase({
    required String supplierId,
    required String productId,
    required double qty,
    required double purchaseRate,
    required double sellingRate,
    required double paidAmount,
    String? vehicleNo,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      final totalAmount = qty * purchaseRate;
      final invoiceNo = 'PUR-${DateTime.now().millisecondsSinceEpoch}';

      // 1. Update the product's master prices if they changed
      await supabase.from('products').update({
        'purchase_rate': purchaseRate,
        'selling_rate': sellingRate,
      }).eq('id', productId);

      // 2. Insert into purchases
      final purchaseRes = await supabase.from('purchases').insert({
        'invoice_no': invoiceNo,
        'purchase_date': DateTime.now().toIso8601String().split('T')[0],
        'supplier_id': supplierId,
        'subtotal': totalAmount,
        'paid_amount': paidAmount,
        'vehicle_no': vehicleNo,
      }).select().single();

      final purchaseId = purchaseRes['id'];

      // 3. Insert into purchase_items (This triggers the stock increase!)
      await supabase.from('purchase_items').insert({
        'purchase_id': purchaseId,
        'product_id': productId,
        'quantity': qty,
        'purchase_rate': purchaseRate,
      });

      // 4. If PaidAmount > 0, insert a payment record to the supplier
      if (paidAmount > 0) {
        await supabase.from('payments').insert({
          'payment_date': DateTime.now().toIso8601String().split('T')[0],
          'party_type': 'Supplier',
          'supplier_id': supplierId,
          'payment_type': 'Out',
          'amount': paidAmount,
          'payment_mode': 'Cash',
          'remarks': 'Paid on Purchase $invoiceNo',
        });
      }

      state = await AsyncValue.guard(() => _fetchPurchases());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final purchaseProvider = AsyncNotifierProvider<PurchaseNotifier, List<Purchase>>(() {
  return PurchaseNotifier();
});
