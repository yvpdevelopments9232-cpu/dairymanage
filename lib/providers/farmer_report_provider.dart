import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/flutter_models.dart';
import 'auth_provider.dart';

class FarmerReportMilkEntry {
  final double liter;
  final double fat;
  final double snf;
  final double rate;
  final double totalAmount;

  FarmerReportMilkEntry({
    required this.liter, required this.fat,
    required this.snf, required this.rate, required this.totalAmount
  });
  
  static FarmerReportMilkEntry empty() {
    return FarmerReportMilkEntry(liter: 0, fat: 0, snf: 0, rate: 0, totalAmount: 0);
  }
}

class DailyMilkEntry {
  final String date;
  FarmerReportMilkEntry morning = FarmerReportMilkEntry.empty();
  FarmerReportMilkEntry evening = FarmerReportMilkEntry.empty();

  DailyMilkEntry(this.date);
}

class FarmerReportProductEntry {
  final String date;
  final String productName;
  final double price;
  final double quantity;
  final double total;

  FarmerReportProductEntry({
    required this.date, required this.productName, required this.price,
    required this.quantity, required this.total
  });
}

class FarmerReportData {
  final Farmer farmer;
  final String animalType;
  final List<DailyMilkEntry> dailyEntries;
  final List<FarmerReportProductEntry> products;
  final List<Payment> payments;

  double get morningLiter => dailyEntries.fold(0, (sum, e) => sum + e.morning.liter);
  double get morningAmount => dailyEntries.fold(0, (sum, e) => sum + e.morning.totalAmount);
  
  double get eveningLiter => dailyEntries.fold(0, (sum, e) => sum + e.evening.liter);
  double get eveningAmount => dailyEntries.fold(0, (sum, e) => sum + e.evening.totalAmount);
  
  double get totalProductAmount => products.fold(0, (sum, e) => sum + e.total);
  double get totalPaymentsAmount => payments.fold(0, (sum, e) => sum + e.amount);

  FarmerReportData({
    required this.farmer,
    required this.animalType,
    required this.dailyEntries,
    required this.products,
    required this.payments,
  });
}

class FarmerReportNotifier extends AsyncNotifier<FarmerReportData?> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 10));
  DateTime _endDate = DateTime.now();
  Farmer? _selectedFarmer;

  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;
  Farmer? get selectedFarmer => _selectedFarmer;

  @override
  Future<FarmerReportData?> build() async {
    return null;
  }

  void setFarmer(Farmer f) {
    _selectedFarmer = f;
    _fetchReport();
  }

  void setDateRange(DateTime start, DateTime end) {
    _startDate = start;
    _endDate = end;
    if (_selectedFarmer != null) _fetchReport();
  }

  Future<void> _fetchReport() async {
    if (_selectedFarmer == null) return;
    
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final supabase = ref.read(supabaseClientProvider);
      final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
      final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
      final fid = _selectedFarmer!.id;

      final collections = await supabase.from('milk_collections')
          .select()
          .eq('farmer_id', fid)
          .gte('collection_date', startStr)
          .lte('collection_date', endStr)
          .order('collection_date');
          
      Map<String, DailyMilkEntry> dailyMap = {};
      String detectedAnimal = 'Cow';

      for (var c in collections as List) {
        final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.parse(c['collection_date']));
        
        if (!dailyMap.containsKey(dateStr)) {
          dailyMap[dateStr] = DailyMilkEntry(dateStr);
        }

        final entry = FarmerReportMilkEntry(
          liter: (c['quantity'] ?? 0).toDouble(),
          fat: (c['fat'] ?? 0).toDouble(),
          snf: (c['snf'] ?? 0).toDouble(),
          rate: (c['rate'] ?? 0).toDouble(),
          totalAmount: (c['total_amount'] ?? 0).toDouble(),
        );
        
        if (c['milk_type'] == 'Buffalo Milk') detectedAnimal = 'Buffalo';
        
        if (c['shift'] == 'Morning') {
          dailyMap[dateStr]!.morning = entry;
        } else {
          dailyMap[dateStr]!.evening = entry;
        }
      }

      final sortedEntries = dailyMap.values.toList()
        ..sort((a, b) => DateFormat('dd/MM/yyyy').parse(a.date).compareTo(DateFormat('dd/MM/yyyy').parse(b.date)));

      final salesData = await supabase.from('sale_items')
          .select('quantity, rate, sales!inner(sale_date, farmer_id), products(name)')
          .eq('sales.farmer_id', fid)
          .gte('sales.sale_date', startStr)
          .lte('sales.sale_date', endStr)
          .order('sales(sale_date)', ascending: true);
          
      List<FarmerReportProductEntry> prods = [];
      for (var s in salesData as List) {
        final qty = (s['quantity'] ?? 0).toDouble();
        final rate = (s['rate'] ?? 0).toDouble();
        prods.add(FarmerReportProductEntry(
          date: DateFormat('dd/MM/yyyy').format(DateTime.parse(s['sales']['sale_date'])),
          productName: s['products']?['name'] ?? 'Product',
          price: rate,
          quantity: qty,
          total: qty * rate,
        ));
      }

      final paymentsData = await supabase.from('payments')
          .select()
          .eq('farmer_id', fid)
          .gte('payment_date', startStr)
          .lte('payment_date', endStr)
          .order('payment_date', ascending: true);
          
      List<Payment> paymentList = (paymentsData as List).map((p) => Payment.fromJson(p)).toList();

      return FarmerReportData(
        farmer: _selectedFarmer!,
        animalType: detectedAnimal,
        dailyEntries: sortedEntries,
        products: prods,
        payments: paymentList,
      );
    });
  }

  Future<List<FarmerReportData>> fetchAllReports(List<Farmer> allFarmers) async {
    final supabase = ref.read(supabaseClientProvider);
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    final collections = await supabase.from('milk_collections')
        .select()
        .gte('collection_date', startStr)
        .lte('collection_date', endStr)
        .order('collection_date');

    final salesData = await supabase.from('sale_items')
        .select('quantity, rate, sales!inner(sale_date, farmer_id), products(name)')
        .not('sales.farmer_id', 'is', null)
        .gte('sales.sale_date', startStr)
        .lte('sales.sale_date', endStr)
        .order('sales(sale_date)', ascending: true);

    final paymentsData = await supabase.from('payments')
        .select()
        .not('farmer_id', 'is', null)
        .gte('payment_date', startStr)
        .lte('payment_date', endStr)
        .order('payment_date', ascending: true);

    Map<String, List<dynamic>> colMap = {};
    for (var c in collections as List) {
      final fid = c['farmer_id'] as String?;
      if (fid != null) {
        colMap.putIfAbsent(fid, () => []).add(c);
      }
    }

    Map<String, List<dynamic>> saleMap = {};
    for (var s in salesData as List) {
      final fid = s['sales']['farmer_id'] as String?;
      if (fid != null) {
        saleMap.putIfAbsent(fid, () => []).add(s);
      }
    }

    Map<String, List<dynamic>> payMap = {};
    for (var p in paymentsData as List) {
      final fid = p['farmer_id'] as String?;
      if (fid != null) {
        payMap.putIfAbsent(fid, () => []).add(p);
      }
    }

    List<FarmerReportData> allReports = [];

    for (var farmer in allFarmers) {
      final fCol = colMap[farmer.id] ?? [];
      final fSal = saleMap[farmer.id] ?? [];
      final fPay = payMap[farmer.id] ?? [];

      if (fCol.isEmpty && fSal.isEmpty && fPay.isEmpty) continue; 

      Map<String, DailyMilkEntry> dailyMap = {};
      String detectedAnimal = 'Cow';

      for (var c in fCol) {
        final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.parse(c['collection_date']));
        if (!dailyMap.containsKey(dateStr)) dailyMap[dateStr] = DailyMilkEntry(dateStr);

        final entry = FarmerReportMilkEntry(
          liter: (c['quantity'] ?? 0).toDouble(),
          fat: (c['fat'] ?? 0).toDouble(),
          snf: (c['snf'] ?? 0).toDouble(),
          rate: (c['rate'] ?? 0).toDouble(),
          totalAmount: (c['total_amount'] ?? 0).toDouble(),
        );
        if (c['milk_type'] == 'Buffalo Milk') detectedAnimal = 'Buffalo';
        
        if (c['shift'] == 'Morning') {
          dailyMap[dateStr]!.morning = entry;
        } else {
          dailyMap[dateStr]!.evening = entry;
        }
      }

      final sortedEntries = dailyMap.values.toList()
        ..sort((a, b) => DateFormat('dd/MM/yyyy').parse(a.date).compareTo(DateFormat('dd/MM/yyyy').parse(b.date)));

      List<FarmerReportProductEntry> prods = [];
      for (var s in fSal) {
        final qty = (s['quantity'] ?? 0).toDouble();
        final rate = (s['rate'] ?? 0).toDouble();
        prods.add(FarmerReportProductEntry(
          date: DateFormat('dd/MM/yyyy').format(DateTime.parse(s['sales']['sale_date'])),
          productName: s['products']?['name'] ?? 'Product',
          price: rate,
          quantity: qty,
          total: qty * rate,
        ));
      }

      List<Payment> paymentList = fPay.map((p) => Payment.fromJson(p)).toList();

      allReports.add(FarmerReportData(
        farmer: farmer,
        animalType: detectedAnimal,
        dailyEntries: sortedEntries,
        products: prods,
        payments: paymentList,
      ));
    }

    allReports.sort((a, b) => (a.farmer.farmerNo ?? 0).compareTo(b.farmer.farmerNo ?? 0));
    return allReports;
  }
}

final farmerReportProvider = AsyncNotifierProvider<FarmerReportNotifier, FarmerReportData?>(() {
  return FarmerReportNotifier();
});
