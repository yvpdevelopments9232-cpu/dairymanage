import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flutter_models.dart';
import 'auth_provider.dart';

class MainDairyDashboardState {
  final String selectedDate;
  final double totalAmount;
  final double totalQuantity;
  final double cowQuantity;
  final double cowAmount;
  final double cowAvgFat;
  final double cowAvgSnf;
  final double cowAvgRate;
  final double buffaloQuantity;
  final double buffaloAmount;
  final double buffaloAvgFat;
  final double buffaloAvgSnf;
  final double buffaloAvgRate;
  final double morningQuantity;
  final double morningAmount;
  final double eveningQuantity;
  final double eveningAmount;
  final double avgFat;
  final double avgSnf;
  final double avgRate;
  final int dairiesCount;
  final List<MainDairyCollection> collections;

  MainDairyDashboardState({
    required this.selectedDate,
    required this.totalAmount,
    required this.totalQuantity,
    required this.cowQuantity,
    required this.cowAmount,
    required this.cowAvgFat,
    required this.cowAvgSnf,
    required this.cowAvgRate,
    required this.buffaloQuantity,
    required this.buffaloAmount,
    required this.buffaloAvgFat,
    required this.buffaloAvgSnf,
    required this.buffaloAvgRate,
    required this.morningQuantity,
    required this.morningAmount,
    required this.eveningQuantity,
    required this.eveningAmount,
    required this.avgFat,
    required this.avgSnf,
    required this.avgRate,
    required this.dairiesCount,
    required this.collections,
  });
}

class MainDairyDashboardNotifier extends AsyncNotifier<MainDairyDashboardState> {
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];

  String get selectedDate => _selectedDate;

  @override
  Future<MainDairyDashboardState> build() async {
    return _fetchStats();
  }

  void setDate(String date) {
    _selectedDate = date;
    ref.invalidateSelf();
  }

  Future<MainDairyDashboardState> _fetchStats() async {
    final supabase = ref.read(supabaseClientProvider);

    List<dynamic> responseList = [];
    try {
      final response = await supabase
          .from('main_dairy_collections')
          .select('*, main_dairies(name, dairy_no)')
          .eq('collection_date', _selectedDate)
          .order('created_at', ascending: false);
      responseList = response as List;
    } catch (e) {
      debugPrint('Join query failed, trying simple query: $e');
      try {
        final fallback = await supabase
            .from('main_dairy_collections')
            .select()
            .eq('collection_date', _selectedDate)
            .order('created_at', ascending: false);
        responseList = fallback as List;
      } catch (e2) {
        debugPrint('Fallback query failed: $e2');
        responseList = [];
      }
    }

    try {
      final collections = responseList
          .map((json) => MainDairyCollection.fromJson(json as Map<String, dynamic>))
          .toList();

      double totalAmount = 0;
      double totalQuantity = 0;
      double cowQuantity = 0;
      double cowAmount = 0;
      double cowFatWeight = 0;
      double cowSnfWeight = 0;
      double buffaloQuantity = 0;
      double buffaloAmount = 0;
      double buffaloFatWeight = 0;
      double buffaloSnfWeight = 0;
      double morningQuantity = 0;
      double morningAmount = 0;
      double eveningQuantity = 0;
      double eveningAmount = 0;
      double totalFatWeight = 0;
      double totalSnfWeight = 0;
      final uniqueDairies = <String>{};

      for (final c in collections) {
        totalAmount += c.totalAmount;
        totalQuantity += c.quantity;
        totalFatWeight += (c.fat * c.quantity);
        totalSnfWeight += (c.snf * c.quantity);
        uniqueDairies.add(c.mainDairyId);

        final isCow = c.milkType.toLowerCase().contains('cow');
        if (isCow) {
          cowQuantity += c.quantity;
          cowAmount += c.totalAmount;
          cowFatWeight += (c.fat * c.quantity);
          cowSnfWeight += (c.snf * c.quantity);
        } else {
          buffaloQuantity += c.quantity;
          buffaloAmount += c.totalAmount;
          buffaloFatWeight += (c.fat * c.quantity);
          buffaloSnfWeight += (c.snf * c.quantity);
        }

        if (c.shift.toLowerCase() == 'morning') {
          morningQuantity += c.quantity;
          morningAmount += c.totalAmount;
        } else {
          eveningQuantity += c.quantity;
          eveningAmount += c.totalAmount;
        }
      }

      final cowAvgFat = cowQuantity > 0 ? (cowFatWeight / cowQuantity) : 0.0;
      final cowAvgSnf = cowQuantity > 0 ? (cowSnfWeight / cowQuantity) : 0.0;
      final cowAvgRate = cowQuantity > 0 ? (cowAmount / cowQuantity) : 0.0;

      final buffaloAvgFat = buffaloQuantity > 0 ? (buffaloFatWeight / buffaloQuantity) : 0.0;
      final buffaloAvgSnf = buffaloQuantity > 0 ? (buffaloSnfWeight / buffaloQuantity) : 0.0;
      final buffaloAvgRate = buffaloQuantity > 0 ? (buffaloAmount / buffaloQuantity) : 0.0;

      final avgFat = totalQuantity > 0 ? (totalFatWeight / totalQuantity) : 0.0;
      final avgSnf = totalQuantity > 0 ? (totalSnfWeight / totalQuantity) : 0.0;
      final avgRate = totalQuantity > 0 ? (totalAmount / totalQuantity) : 0.0;

      return MainDairyDashboardState(
        selectedDate: _selectedDate,
        totalAmount: totalAmount,
        totalQuantity: totalQuantity,
        cowQuantity: cowQuantity,
        cowAmount: cowAmount,
        cowAvgFat: cowAvgFat,
        cowAvgSnf: cowAvgSnf,
        cowAvgRate: cowAvgRate,
        buffaloQuantity: buffaloQuantity,
        buffaloAmount: buffaloAmount,
        buffaloAvgFat: buffaloAvgFat,
        buffaloAvgSnf: buffaloAvgSnf,
        buffaloAvgRate: buffaloAvgRate,
        morningQuantity: morningQuantity,
        morningAmount: morningAmount,
        eveningQuantity: eveningQuantity,
        eveningAmount: eveningAmount,
        avgFat: avgFat,
        avgSnf: avgSnf,
        avgRate: avgRate,
        dairiesCount: uniqueDairies.length,
        collections: collections,
      );
    } catch (e, st) {
      debugPrint('Error calculating stats: $e\n$st');
      return MainDairyDashboardState(
        selectedDate: _selectedDate,
        totalAmount: 0,
        totalQuantity: 0,
        cowQuantity: 0,
        cowAmount: 0,
        cowAvgFat: 0,
        cowAvgSnf: 0,
        cowAvgRate: 0,
        buffaloQuantity: 0,
        buffaloAmount: 0,
        buffaloAvgFat: 0,
        buffaloAvgSnf: 0,
        buffaloAvgRate: 0,
        morningQuantity: 0,
        morningAmount: 0,
        eveningQuantity: 0,
        eveningAmount: 0,
        avgFat: 0,
        avgSnf: 0,
        avgRate: 0,
        dairiesCount: 0,
        collections: [],
      );
    }
  }
}

final mainDairyDashboardProvider =
    AsyncNotifierProvider<MainDairyDashboardNotifier, MainDairyDashboardState>(() {
  return MainDairyDashboardNotifier();
});
