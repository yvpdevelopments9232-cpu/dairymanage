import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import 'auth_provider.dart';

class SupplierNotifier extends AsyncNotifier<List<Supplier>> {
  @override
  Future<List<Supplier>> build() async {
    return _fetchSuppliers();
  }

  Future<List<Supplier>> _fetchSuppliers() async {
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase.from('suppliers').select().order('name');
    return (response as List).map((json) => Supplier.fromJson(json)).toList();
  }

  Future<void> addSupplier(Supplier supplier) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('suppliers').insert({
        'name': supplier.name,
        'mobile': supplier.mobile,
        'address': supplier.address,
        'product_type': supplier.productType,
        'opening_balance': supplier.openingBalance,
        'current_balance': supplier.openingBalance,
        'payment_terms': supplier.paymentTerms,
        'status': true,
      });
      state = await AsyncValue.guard(() => _fetchSuppliers());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateSupplier(String id, Supplier supplier) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('suppliers').update({
        'name': supplier.name,
        'mobile': supplier.mobile,
        'address': supplier.address,
        'product_type': supplier.productType,
        'payment_terms': supplier.paymentTerms,
      }).eq('id', id);
      state = await AsyncValue.guard(() => _fetchSuppliers());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteSupplier(String id) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('suppliers').delete().eq('id', id);
      state = await AsyncValue.guard(() => _fetchSuppliers());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> makePayment(String supplierId, double amount, String remarks) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      // 1. Insert into payments (Outward payment to supplier)
      await supabase.from('payments').insert({
        'payment_date': DateTime.now().toIso8601String().split('T')[0],
        'party_type': 'Supplier',
        'supplier_id': supplierId,
        'payment_type': 'Out',
        'amount': amount,
        'payment_mode': 'Cash',
        'remarks': remarks,
      });
      // (The process_payment_ledger trigger will automatically reduce the supplier's balance!)
      
      state = await AsyncValue.guard(() => _fetchSuppliers());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final supplierProvider = AsyncNotifierProvider<SupplierNotifier, List<Supplier>>(() {
  return SupplierNotifier();
});
