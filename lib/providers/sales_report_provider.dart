import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'auth_provider.dart';

class SaleReportEntry {
  final String date;
  final String buyerName;
  final String productName;
  final double quantity;
  final double price;
  final double total;

  SaleReportEntry({
    required this.date,
    required this.buyerName,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.total,
  });
}

class ProductSalesSummary {
  final String productName;
  double totalQuantity;
  double totalAmount;

  ProductSalesSummary({
    required this.productName,
    this.totalQuantity = 0,
    this.totalAmount = 0,
  });
}

class SalesReportData {
  final List<SaleReportEntry> entries;
  final List<ProductSalesSummary> productSummaries;
  final double grandTotalAmount;

  SalesReportData({
    required this.entries,
    required this.productSummaries,
    required this.grandTotalAmount,
  });
}

class SalesReportNotifier extends AsyncNotifier<SalesReportData> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 10));
  DateTime _endDate = DateTime.now();

  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;

  @override
  Future<SalesReportData> build() async {
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

  Future<SalesReportData> _fetchReport() async {
    final supabase = ref.read(supabaseClientProvider);
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    // Fetch sales with nested items, products, and buyer info
    final salesRes = await supabase.from('sales').select('''
      sale_date,
      farmers ( name ),
      customers ( name ),
      sale_items (
        quantity, rate,
        products ( name )
      )
    ''').gte('sale_date', startStr).lte('sale_date', endStr).order('sale_date');

    List<SaleReportEntry> allEntries = [];
    Map<String, ProductSalesSummary> summaryMap = {};
    double grandTotal = 0;

    for (var sale in salesRes as List) {
      final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.parse(sale['sale_date']));
      
      String buyer = 'Unknown';
      if (sale['farmers'] != null) {
        buyer = sale['farmers']['name'];
      } else if (sale['customers'] != null) {
        buyer = sale['customers']['name'];
      }

      final items = sale['sale_items'] as List;
      for (var item in items) {
        final productName = item['products']?['name'] ?? 'Unknown Product';
        final qty = (item['quantity'] ?? 0).toDouble();
        final rate = (item['rate'] ?? 0).toDouble();
        final total = qty * rate;

        allEntries.add(SaleReportEntry(
          date: dateStr,
          buyerName: buyer,
          productName: productName,
          quantity: qty,
          price: rate,
          total: total,
        ));

        if (!summaryMap.containsKey(productName)) {
          summaryMap[productName] = ProductSalesSummary(productName: productName);
        }
        summaryMap[productName]!.totalQuantity += qty;
        summaryMap[productName]!.totalAmount += total;
        
        grandTotal += total;
      }
    }

    final productSummaries = summaryMap.values.toList()
      ..sort((a, b) => a.productName.compareTo(b.productName));

    return SalesReportData(
      entries: allEntries,
      productSummaries: productSummaries,
      grandTotalAmount: grandTotal,
    );
  }
}

final salesReportProvider = AsyncNotifierProvider<SalesReportNotifier, SalesReportData>(() {
  return SalesReportNotifier();
});
