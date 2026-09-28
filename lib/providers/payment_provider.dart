import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import 'auth_provider.dart';

class PaymentNotifier extends AsyncNotifier<List<Payment>> {
  @override
  Future<List<Payment>> build() async {
    return _fetchPayments();
  }

  Future<List<Payment>> _fetchPayments() async {
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase.from('payments').select('*, farmers(name), customers(name), suppliers(name)').order('created_at', ascending: false).limit(100);
    return (response as List).map((json) => Payment.fromJson(json)).toList();
  }

  Future<void> addPayment({
    required String partyType,
    required String partyId,
    required String paymentType, // 'In' or 'Out'
    required double amount,
    required String paymentMode,
    String? referenceNo,
    String? remarks,
    String? paymentDate,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      final data = {
        'payment_date': paymentDate ?? DateTime.now().toIso8601String().split('T')[0],
        'party_type': partyType,
        'payment_type': paymentType,
        'amount': amount,
        'payment_mode': paymentMode,
        'reference_no': referenceNo,
        'remarks': remarks,
      };

      if (partyType == 'Farmer') data['farmer_id'] = partyId;
      if (partyType == 'Customer') data['customer_id'] = partyId;
      if (partyType == 'Supplier') data['supplier_id'] = partyId;

      await supabase.from('payments').insert(data);
      state = await AsyncValue.guard(() => _fetchPayments());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updatePayment(String id, double amount, String remarks, String paymentDate) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('payments').update({
        'amount': amount,
        'remarks': remarks,
        'payment_date': paymentDate,
      }).eq('id', id);
      state = await AsyncValue.guard(() => _fetchPayments());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deletePayment(String id) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('payments').delete().eq('id', id);
      state = await AsyncValue.guard(() => _fetchPayments());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final paymentProvider = AsyncNotifierProvider<PaymentNotifier, List<Payment>>(() {
  return PaymentNotifier();
});
