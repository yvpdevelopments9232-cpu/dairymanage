import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'auth_provider.dart';

class DashboardStats {
  final double cowMilk;
  final double buffaloMilk;
  final double cowAvgFat;
  final double cowAvgSnf;
  final double buffaloAvgFat;
  final double buffaloAvgSnf;
  
  final double collectionAmount;
  final double milkSoldLtr;
  final double salesAmount;
  final double profit;
  final double totalStockValue;
  final List<Map<String, dynamic>> stockDetails;

  DashboardStats({
    required this.cowMilk,
    required this.buffaloMilk,
    required this.cowAvgFat,
    required this.cowAvgSnf,
    required this.buffaloAvgFat,
    required this.buffaloAvgSnf,
    required this.collectionAmount,
    required this.milkSoldLtr,
    required this.salesAmount,
    required this.profit,
    required this.totalStockValue,
    required this.stockDetails,
  });
}

class DashboardNotifier extends AsyncNotifier<DashboardStats> {
  String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Future<DashboardStats> build() async {
    return _fetchStats();
  }

  Future<void> setDate(String date) async {
    currentDate = date;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchStats());
  }

  Future<DashboardStats> _fetchStats() async {
    final supabase = ref.read(supabaseClientProvider);
    
    // 1. Fetch milk collections for the selected date
    final collectionsRes = await supabase
        .from('milk_collections')
        .select('milk_type, quantity, total_amount, fat, snf, rate')
        .eq('collection_date', currentDate);
        
    double cowMilk = 0, buffMilk = 0, collAmt = 0;
    double cowFatSum = 0, cowSnfSum = 0;
    double buffFatSum = 0, buffSnfSum = 0;
    
    for (var row in collectionsRes as List) {
      final qty = (row['quantity'] ?? 0).toDouble();
      final fat = (row['fat'] ?? 0).toDouble();
      final snf = (row['snf'] ?? 0).toDouble();
      
      double rAmt = (row['total_amount'] ?? 0).toDouble();
      if (rAmt == 0) rAmt = qty * (row['rate'] ?? 0).toDouble();
      collAmt += rAmt;
      
      final mType = (row['milk_type'] ?? '').toString().toLowerCase();
      if (mType.contains('cow')) {
        cowMilk += qty;
        cowFatSum += (fat * qty);
        cowSnfSum += (snf * qty);
      }
      if (mType.contains('buffalo') || mType.contains('buff')) {
        buffMilk += qty;
        buffFatSum += (fat * qty);
        buffSnfSum += (snf * qty);
      }
    }
    
    double cowAvgFat = cowMilk > 0 ? cowFatSum / cowMilk : 0;
    double cowAvgSnf = cowMilk > 0 ? cowSnfSum / cowMilk : 0;
    double buffAvgFat = buffMilk > 0 ? buffFatSum / buffMilk : 0;
    double buffAvgSnf = buffMilk > 0 ? buffSnfSum / buffMilk : 0;

    // 2. Fetch sales for the selected date
    // We join the sales table to filter by sale_date
    final salesRes = await supabase
        .from('sale_items')
        .select('quantity, rate, products(purchase_rate, category), sales!inner(sale_date)')
        .eq('sales.sale_date', currentDate);
        
    double milkSold = 0, salesAmt = 0, profit = 0;
    for (var row in salesRes as List) {
      final qty = (row['quantity'] ?? 0).toDouble();
      final rate = (row['rate'] ?? 0).toDouble();
      final pRate = (row['products']?['purchase_rate'] ?? 0).toDouble();
      final cat = row['products']?['category'] ?? '';
      
      salesAmt += (qty * rate);
      profit += (qty * (rate - pRate)); // Profit calculation!
      
      if (cat.toString().toLowerCase().contains('milk') || cat == '') {
        milkSold += qty;
      }
    }

    // 3. Fetch LIVE stock details (Stock is not backdated, it's a current snapshot)
    final productsRes = await supabase.from('products').select('name, selling_rate, current_stock').order('name');
    double totalStockVal = 0;
    List<Map<String, dynamic>> stockList = [];
    
    for (var row in productsRes as List) {
      final stock = (row['current_stock'] ?? 0).toDouble();
      final rate = (row['selling_rate'] ?? 0).toDouble();
      final val = stock * rate;
      if (stock > 0) {
        totalStockVal += val;
        stockList.add({
          'name': row['name'],
          'rate': rate,
          'stock': stock,
          'value': val,
        });
      }
    }

    return DashboardStats(
      cowMilk: cowMilk,
      buffaloMilk: buffMilk,
      cowAvgFat: cowAvgFat,
      cowAvgSnf: cowAvgSnf,
      buffaloAvgFat: buffAvgFat,
      buffaloAvgSnf: buffAvgSnf,
      collectionAmount: collAmt,
      milkSoldLtr: milkSold,
      salesAmount: salesAmt,
      profit: profit,
      totalStockValue: totalStockVal,
      stockDetails: stockList,
    );
  }
}

final dashboardStatsProvider = AsyncNotifierProvider<DashboardNotifier, DashboardStats>(() {
  return DashboardNotifier();
});
