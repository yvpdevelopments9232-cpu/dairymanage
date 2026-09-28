import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import '../services/app_db.dart';

class StaffNotifier extends AsyncNotifier<List<Staff>> {
  dynamic get _supabase => AppDb.client;

  @override
  Future<List<Staff>> build() async {
    return _fetchStaff();
  }

  Future<List<Staff>> _fetchStaff() async {
    final response = await _supabase
        .from('staff')
        .select('*')
        .order('name');
    
    return (response as List).map((e) => Staff.fromJson(e)).toList();
  }

  Future<void> addStaff({
    required String name,
    String? phone,
    String? role,
    required double salaryAmount,
    required String salaryType,
  }) async {
    await _supabase.from('staff').insert({
      'name': name,
      'phone': phone,
      'role': role,
      'salary_amount': salaryAmount,
      'salary_type': salaryType,
    });
    ref.invalidateSelf();
  }
}

final staffProvider = AsyncNotifierProvider<StaffNotifier, List<Staff>>(() => StaffNotifier());

class StaffTransactionNotifier extends AsyncNotifier<List<StaffTransaction>> {
  dynamic get _supabase => AppDb.client;
  String? _staffId;

  @override
  Future<List<StaffTransaction>> build() async {
    return [];
  }

  Future<void> loadTransactions(String staffId) async {
    _staffId = staffId;
    state = const AsyncValue.loading();
    try {
      final response = await _supabase
          .from('staff_transactions')
          .select('*')
          .eq('staff_id', staffId)
          .order('transaction_date', ascending: false)
          .order('created_at', ascending: false);
          
      state = AsyncValue.data((response as List).map((e) => StaffTransaction.fromJson(e)).toList());
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> addTransaction({
    required String staffId,
    required String date,
    required String type,
    required double amount,
    String? remarks,
  }) async {
    await _supabase.from('staff_transactions').insert({
      'staff_id': staffId,
      'transaction_date': date,
      'type': type,
      'amount': amount,
      'remarks': remarks,
    });
    ref.invalidate(staffProvider);
    if (_staffId == staffId) {
      await loadTransactions(staffId);
    }
  }
}

final staffTransactionProvider = AsyncNotifierProvider<StaffTransactionNotifier, List<StaffTransaction>>(() => StaffTransactionNotifier());
