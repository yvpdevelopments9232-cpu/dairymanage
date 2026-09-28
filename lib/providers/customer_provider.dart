import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import 'auth_provider.dart';

class CustomersNotifier extends AsyncNotifier<List<Customer>> {
  
  @override
  Future<List<Customer>> build() async {
    return _fetchCustomers();
  }

  Future<List<Customer>> _fetchCustomers() async {
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase.from('customers').select().order('name');
    return (response as List).map((json) => Customer.fromJson(json)).toList();
  }

  Future<void> addCustomer(String name, String mobile, String address, String type, double creditLimit) async {
    final supabase = ref.read(supabaseClientProvider);
    
    final newCustomer = {
      'name': name,
      'mobile': mobile,
      'address': address,
      'customer_type': type,
      'credit_limit': creditLimit,
      'opening_balance': 0,
      'status': true,
    };
    
    state = const AsyncValue.loading();
    
    try {
      await supabase.from('customers').insert(newCustomer);
      state = await AsyncValue.guard(() => _fetchCustomers());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateCustomer(String id, String name, String mobile, String address, String type, double creditLimit) async {
    final supabase = ref.read(supabaseClientProvider);
    
    final updatedData = {
      'name': name,
      'mobile': mobile,
      'address': address,
      'customer_type': type,
      'credit_limit': creditLimit,
    };
    
    state = const AsyncValue.loading();
    
    try {
      await supabase.from('customers').update(updatedData).eq('id', id);
      state = await AsyncValue.guard(() => _fetchCustomers());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteCustomer(String id) async {
    final supabase = ref.read(supabaseClientProvider);
    
    state = const AsyncValue.loading();
    try {
      await supabase.from('customers').delete().eq('id', id);
      state = await AsyncValue.guard(() => _fetchCustomers());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final customersProvider = AsyncNotifierProvider<CustomersNotifier, List<Customer>>(() {
  return CustomersNotifier();
});
