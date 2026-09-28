import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'auth_provider.dart';

class MilkReportRow {
  final int srNo;
  final String farmerName;
  final String animalType;
  final double totalLiter;
  final double totalAmount;
  final double advanceAndPurchases;
  final double remainingAmount;

  MilkReportRow({
    required this.srNo,
    required this.farmerName,
    required this.animalType,
    required this.totalLiter,
    required this.totalAmount,
    required this.advanceAndPurchases,
    required this.remainingAmount,
  });
}

class MilkReportSummary {
  final double cowMilkLiters;
  final double buffaloMilkLiters;
  final double totalMilkLiters;
  final double totalAmount;
  final double totalAdvanceAndPurchases;
  final double totalRemainingAmount;

  MilkReportSummary({
    required this.cowMilkLiters,
    required this.buffaloMilkLiters,
    required this.totalMilkLiters,
    required this.totalAmount,
    required this.totalAdvanceAndPurchases,
    required this.totalRemainingAmount,
  });
}

class MilkReportData {
  final List<MilkReportRow> rows;
  final MilkReportSummary summary;

  MilkReportData(this.rows, this.summary);
}

class MilkReportNotifier extends AsyncNotifier<MilkReportData> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 10));
  DateTime _endDate = DateTime.now();

  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;

  @override
  Future<MilkReportData> build() async {
    return _fetchReport();
  }

  Future<void> setDateRange(DateTime start, DateTime end) async {
    _startDate = start;
    _endDate = end;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchReport());
  }

  Future<MilkReportData> _fetchReport() async {
    final supabase = ref.read(supabaseClientProvider);
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    // 1. Fetch Farmers
    final farmersRes = await supabase.from('farmers').select('id, farmer_no, name').order('farmer_no');
    
    // 2. Fetch Milk Collections in range
    final collections = await supabase.from('milk_collections')
      .select('farmer_id, milk_type, quantity, total_amount')
      .gte('collection_date', startStr)
      .lte('collection_date', endStr);
      
    // 3. Fetch Sales to farmers in range (Product Purchases by Farmer)
    final sales = await supabase.from('sales')
      .select('farmer_id, grand_total')
      .not('farmer_id', 'is', null)
      .gte('sale_date', startStr)
      .lte('sale_date', endStr);
      
    // 4. Fetch Payments to farmers in range (Cash Advances given TO Farmer)
    final payments = await supabase.from('payments')
      .select('farmer_id, amount')
      .eq('party_type', 'Farmer')
      .eq('payment_type', 'Out')
      .gte('payment_date', startStr)
      .lte('payment_date', endStr);

    // Aggregate Maps
    Map<String, double> cLiters = {};
    Map<String, double> bLiters = {};
    Map<String, double> cAmount = {};
    
    Map<String, double> fAdvances = {};

    for (var c in collections as List) {
      final fid = c['farmer_id'].toString();
      final qty = (c['quantity'] ?? 0).toDouble();
      final amt = (c['total_amount'] ?? 0).toDouble();
      final type = c['milk_type'];
      
      cAmount[fid] = (cAmount[fid] ?? 0) + amt;
      
      if (type == 'Cow Milk') {
        cLiters[fid] = (cLiters[fid] ?? 0) + qty;
      } else if (type == 'Buffalo Milk') {
        bLiters[fid] = (bLiters[fid] ?? 0) + qty;
      }
    }

    for (var s in sales as List) {
      final fid = s['farmer_id'].toString();
      final amt = (s['grand_total'] ?? 0).toDouble();
      fAdvances[fid] = (fAdvances[fid] ?? 0) + amt;
    }
    
    for (var p in payments as List) {
      final fid = p['farmer_id'].toString();
      final amt = (p['amount'] ?? 0).toDouble();
      fAdvances[fid] = (fAdvances[fid] ?? 0) + amt;
    }

    // Build Rows
    List<MilkReportRow> rows = [];
    int srNo = 1;
    
    double sumCow = 0, sumBuff = 0, sumAmt = 0, sumAdv = 0, sumRem = 0;

    for (var f in farmersRes as List) {
      final fid = f['id'].toString();
      final cowQty = cLiters[fid] ?? 0;
      final buffQty = bLiters[fid] ?? 0;
      final amt = cAmount[fid] ?? 0;
      final adv = fAdvances[fid] ?? 0;
      
      final totQty = cowQty + buffQty;
      
      if (totQty == 0 && adv == 0) continue; // Skip inactive farmers for this period

      String aType = 'Cow';
      if (buffQty > 0 && cowQty == 0) aType = 'Buffalo';
      if (buffQty > 0 && cowQty > 0) aType = 'Mixed';

      final rem = amt - adv;

      sumCow += cowQty;
      sumBuff += buffQty;
      sumAmt += amt;
      sumAdv += adv;
      sumRem += rem;

      rows.add(MilkReportRow(
        srNo: srNo++,
        farmerName: f['name'],
        animalType: aType,
        totalLiter: totQty,
        totalAmount: amt,
        advanceAndPurchases: adv,
        remainingAmount: rem,
      ));
    }

    final summary = MilkReportSummary(
      cowMilkLiters: sumCow,
      buffaloMilkLiters: sumBuff,
      totalMilkLiters: sumCow + sumBuff,
      totalAmount: sumAmt,
      totalAdvanceAndPurchases: sumAdv,
      totalRemainingAmount: sumRem,
    );

    return MilkReportData(rows, summary);
  }
}

final milkReportProvider = AsyncNotifierProvider<MilkReportNotifier, MilkReportData>(() {
  return MilkReportNotifier();
});
