import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import '../services/app_db.dart';
import 'package:intl/intl.dart';

class ExpenseNotifier extends AsyncNotifier<List<Expense>> {
  dynamic get _supabase => AppDb.client;
  String _currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  String get currentDate => _currentDate;

  @override
  Future<List<Expense>> build() async {
    return _fetchExpenses();
  }

  Future<List<Expense>> _fetchExpenses() async {
    final response = await _supabase
        .from('expenses')
        .select('*')
        .eq('expense_date', _currentDate)
        .order('created_at', ascending: false);

    return (response as List).map((e) => Expense.fromJson(e)).toList();
  }

  void setDate(String date) {
    _currentDate = date;
    ref.invalidateSelf();
  }

  Future<void> addExpense({
    required String category,
    String? description,
    required double amount,
    required String paymentMode,
    String? remarks,
  }) async {
    await _supabase.from('expenses').insert({
      'expense_date': _currentDate,
      'category': category,
      'description': description,
      'amount': amount,
      'payment_mode': paymentMode,
      'remarks': remarks,
    });
    ref.invalidateSelf();
  }

  Future<void> deleteExpense(String id) async {
    await _supabase.from('expenses').delete().eq('id', id);
    ref.invalidateSelf();
  }
}

final expenseProvider = AsyncNotifierProvider<ExpenseNotifier, List<Expense>>(
  () => ExpenseNotifier(),
);
