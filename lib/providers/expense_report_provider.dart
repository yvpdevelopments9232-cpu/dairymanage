import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import '../services/app_db.dart';

class ExpenseReportState {
  final double totalRevenue;
  final double productProfit;
  final double milkSaleCost;
  final double milkCost;
  final double purchaseCost;
  final double expenseCost;
  final List<Expense> expenses;

  double get milkProfit => milkSaleCost - milkCost;
  double get netProfit => productProfit + milkProfit - expenseCost;

  ExpenseReportState({
    required this.totalRevenue,
    required this.productProfit,
    required this.milkSaleCost,
    required this.milkCost,
    required this.purchaseCost,
    required this.expenseCost,
    required this.expenses,
  });
}

class ExpenseReportNotifier extends AsyncNotifier<ExpenseReportState> {
  dynamic get _supabase => AppDb.client;
  String? _startDate;
  String? _endDate;

  @override
  Future<ExpenseReportState> build() async {
    return _fetchReport();
  }

  void setDateRange(String start, String end) {
    _startDate = start;
    _endDate = end;
    ref.invalidateSelf();
  }

  Future<ExpenseReportState> _fetchReport() async {
    if (_startDate == null || _endDate == null) {
      return ExpenseReportState(
        totalRevenue: 0,
        productProfit: 0,
        milkSaleCost: 0,
        milkCost: 0,
        purchaseCost: 0,
        expenseCost: 0,
        expenses: [],
      );
    }

    double revenue = 0;
    double productProfit = 0;
    double milkSale = 0;
    double milk = 0;
    double purchase = 0;
    double expenseTotal = 0;
    List<Expense> expenseList = [];

    // 1. Fetch Sales (Revenue)
    final salesRes = await _supabase.from('sales')
        .select('grand_total')
        .gte('sale_date', _startDate!)
        .lte('sale_date', _endDate!);
    for (var s in salesRes) revenue += (s['grand_total'] ?? 0).toDouble();

    // 2. Fetch Product Profit from sale_items (Selling Rate - Purchase Rate) * Quantity
    try {
      final saleItemsRes = await _supabase
          .from('sale_items')
          .select('quantity, rate, products(purchase_rate), sales!inner(sale_date)')
          .gte('sales.sale_date', _startDate!)
          .lte('sales.sale_date', _endDate!);

      for (var row in saleItemsRes as List) {
        final qty = (row['quantity'] ?? 0).toDouble();
        final rate = (row['rate'] ?? 0).toDouble();
        final pRate = (row['products']?['purchase_rate'] ?? 0).toDouble();
        productProfit += (qty * (rate - pRate));
      }
    } catch (_) {}

    // 3. Fetch Milk Sales to Main Dairy (Milk Sale Cost)
    try {
      final mainDairyRes = await _supabase.from('main_dairy_collections')
          .select('total_amount')
          .gte('collection_date', _startDate!)
          .lte('collection_date', _endDate!);
      for (var m in mainDairyRes) milkSale += (m['total_amount'] ?? 0).toDouble();
    } catch (_) {}

    // 4. Fetch Milk Collections (Total Milk Purchase Cost from Farmers)
    final milkRes = await _supabase.from('milk_collections')
        .select('total_amount')
        .gte('collection_date', _startDate!)
        .lte('collection_date', _endDate!);
    for (var m in milkRes) milk += (m['total_amount'] ?? 0).toDouble();

    // 5. Fetch Purchases (Total Stock Purchases from Dealers)
    final purRes = await _supabase.from('purchases')
        .select('grand_total')
        .gte('purchase_date', _startDate!)
        .lte('purchase_date', _endDate!);
    for (var p in purRes) purchase += (p['grand_total'] ?? 0).toDouble();

    // 6. Fetch Operational Expenses
    final expRes = await _supabase.from('expenses')
        .select('*')
        .gte('expense_date', _startDate!)
        .lte('expense_date', _endDate!)
        .order('expense_date');
    for (var e in expRes) {
      final exp = Expense.fromJson(e);
      expenseList.add(exp);
      expenseTotal += exp.amount;
    }

    return ExpenseReportState(
      totalRevenue: revenue,
      productProfit: productProfit,
      milkSaleCost: milkSale,
      milkCost: milk,
      purchaseCost: purchase,
      expenseCost: expenseTotal,
      expenses: expenseList,
    );
  }
}

final expenseReportProvider = AsyncNotifierProvider<ExpenseReportNotifier, ExpenseReportState>(
  () => ExpenseReportNotifier(),
);
