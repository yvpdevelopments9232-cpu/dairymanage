import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'auth_provider.dart';

class StockReportEntry {
  final String productName;
  final double totalIn;
  final double totalOut;
  final double currentStock;
  final double sellingRate;
  final double stockValue; // currentStock * sellingRate

  StockReportEntry({
    required this.productName,
    required this.totalIn,
    required this.totalOut,
    required this.currentStock,
    required this.sellingRate,
    required this.stockValue,
  });
}

class StockReportData {
  final List<StockReportEntry> entries;
  final double grandTotalValue;

  StockReportData(this.entries, this.grandTotalValue);
}

class StockReportNotifier extends AsyncNotifier<StockReportData> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;

  @override
  Future<StockReportData> build() async {
    return _fetchReport();
  }

  void setDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    state = const AsyncValue.loading();
    ref.notifyListeners();
    _fetchAndSetState();
  }
  
  Future<void> _fetchAndSetState() async {
    state = await AsyncValue.guard(() => _fetchReport());
  }

  Future<StockReportData> _fetchReport() async {
    final supabase = ref.read(supabaseClientProvider);
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    // 1. Fetch all products
    final productsRes = await supabase.from('products').select('id, name, current_stock, selling_rate').order('name');
    
    // 2. Fetch stock transactions in range
    final transactionsRes = await supabase.from('stock_transactions')
        .select('product_id, quantity')
        .gte('transaction_date', startStr)
        .lte('transaction_date', endStr);

    Map<String, double> totalInMap = {};
    Map<String, double> totalOutMap = {};

    for (var tx in transactionsRes as List) {
      final pid = tx['product_id'].toString();
      final qty = (tx['quantity'] ?? 0).toDouble();
      
      if (qty > 0) {
        totalInMap[pid] = (totalInMap[pid] ?? 0) + qty;
      } else {
        totalOutMap[pid] = (totalOutMap[pid] ?? 0) + qty.abs();
      }
    }

    List<StockReportEntry> entries = [];
    double grandTotalValue = 0;

    for (var p in productsRes as List) {
      final pid = p['id'].toString();
      final name = p['name'] ?? 'Unknown';
      final currentStock = (p['current_stock'] ?? 0).toDouble();
      final rate = (p['selling_rate'] ?? 0).toDouble();
      
      final totIn = totalInMap[pid] ?? 0;
      final totOut = totalOutMap[pid] ?? 0;
      
      // If there's no stock and no movement, skip to keep report clean
      if (currentStock == 0 && totIn == 0 && totOut == 0) continue;

      final val = currentStock > 0 ? (currentStock * rate) : 0.0;
      grandTotalValue += val;

      entries.add(StockReportEntry(
        productName: name,
        totalIn: totIn,
        totalOut: totOut,
        currentStock: currentStock,
        sellingRate: rate,
        stockValue: val,
      ));
    }

    return StockReportData(entries, grandTotalValue);
  }
}

final stockReportProvider = AsyncNotifierProvider<StockReportNotifier, StockReportData>(() {
  return StockReportNotifier();
});
