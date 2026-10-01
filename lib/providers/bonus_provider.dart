import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/flutter_models.dart';
import '../services/app_config.dart';
import '../services/offline_db_helper.dart';
import '../services/sync_service.dart';
import 'auth_provider.dart';

class BonusDateRange {
  final String fromDate; // yyyy-MM-dd
  final String toDate;   // yyyy-MM-dd

  BonusDateRange({required this.fromDate, required this.toDate});

  String get fromFormatted {
    try {
      return DateFormat('dd-MM-yyyy').format(DateTime.parse(fromDate));
    } catch (_) {
      return fromDate;
    }
  }

  String get toFormatted {
    try {
      return DateFormat('dd-MM-yyyy').format(DateTime.parse(toDate));
    } catch (_) {
      return toDate;
    }
  }
}

class BonusDateRangeNotifier extends Notifier<BonusDateRange> {
  @override
  BonusDateRange build() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    return BonusDateRange(
      fromDate: DateFormat('yyyy-MM-dd').format(firstDay),
      toDate: DateFormat('yyyy-MM-dd').format(lastDay),
    );
  }

  void setRange(String fromDate, String toDate) {
    state = BonusDateRange(fromDate: fromDate, toDate: toDate);
  }
}

final bonusDateRangeProvider = NotifierProvider<BonusDateRangeNotifier, BonusDateRange>(
  BonusDateRangeNotifier.new,
);

class BonusSettingsNotifier extends AsyncNotifier<BonusSettings> {
  @override
  Future<BonusSettings> build() async {
    return _loadSettings();
  }

  Future<BonusSettings> _loadSettings() async {
    try {
      if (!AppConfig.isOfflineMode && !AppConfig.isHybridMode) {
        final supabase = ref.read(supabaseClientProvider);
        final res = await supabase.from('bonus_settings').select().limit(1);
        if ((res as List).isNotEmpty) {
          return BonusSettings.fromJson(res.first);
        }
      } else {
        final db = await OfflineDbHelper.instance.database;
        final res = await db.query('bonus_settings', limit: 1);
        if (res.isNotEmpty) {
          return BonusSettings.fromJson(res.first);
        }
      }
    } catch (e) {
      debugPrint('Bonus settings load error: $e');
    }
    return BonusSettings(id: 'default_settings', cowRate: 0.40, buffaloRate: 0.50);
  }

  Future<void> updateRates({required double cowRate, required double buffaloRate}) async {
    final updated = BonusSettings(
      id: 'default_settings',
      cowRate: cowRate,
      buffaloRate: buffaloRate,
      updatedAt: DateTime.now().toIso8601String(),
    );

    try {
      final db = await OfflineDbHelper.instance.database;
      final existing = await db.query('bonus_settings', where: 'id = ?', whereArgs: [updated.id]);
      if (existing.isEmpty) {
        await db.insert('bonus_settings', updated.toJson());
      } else {
        await db.update('bonus_settings', updated.toJson(), where: 'id = ?', whereArgs: [updated.id]);
      }

      if (AppConfig.isHybridMode) {
        await OfflineDbHelper.instance.enqueueSync(
          tableName: 'bonus_settings',
          rowId: updated.id,
          action: 'UPSERT',
          payload: jsonEncode(updated.toJson()),
        );
        SyncService.instance.triggerSync();
      }
    } catch (e) {
      debugPrint('Error updating bonus settings in local db: $e');
    }

    state = AsyncValue.data(updated);
    ref.invalidate(bonusCalculationProvider);
  }
}

final bonusSettingsProvider = AsyncNotifierProvider<BonusSettingsNotifier, BonusSettings>(
  BonusSettingsNotifier.new,
);

class BonusCalculationSummary {
  final double totalCollection;
  final double totalBonus;
  final double paidBonus;
  final double remainingBonus;
  final List<BonusFarmerSummary> farmersSummary;

  BonusCalculationSummary({
    required this.totalCollection,
    required this.totalBonus,
    required this.paidBonus,
    required this.remainingBonus,
    required this.farmersSummary,
  });

  double get paidPercentage => totalBonus > 0 ? ((paidBonus / totalBonus) * 100).clamp(0.0, 100.0) : 0.0;
  double get remainingPercentage => totalBonus > 0 ? ((remainingBonus / totalBonus) * 100).clamp(0.0, 100.0) : 0.0;
}

final bonusCalculationProvider = FutureProvider<BonusCalculationSummary>((ref) async {
  final dateRange = ref.watch(bonusDateRangeProvider);
  final settingsAsync = ref.watch(bonusSettingsProvider);
  final settings = settingsAsync.value ?? BonusSettings(id: 'default_settings', cowRate: 0.40, buffaloRate: 0.50);

  List<Map<String, dynamic>> farmersRows;
  List<Map<String, dynamic>> collections;
  List<Map<String, dynamic>> transactions;

  if (!AppConfig.isOfflineMode && !AppConfig.isHybridMode) {
    final supabase = ref.read(supabaseClientProvider);
    final fRes = await supabase.from('farmers').select().order('name');
    farmersRows = (fRes as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final cRes = await supabase.from('milk_collections').select()
        .gte('collection_date', dateRange.fromDate)
        .lte('collection_date', dateRange.toDate);
    collections = (cRes as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final tRes = await supabase.from('bonus_transactions').select()
        .gte('from_date', dateRange.fromDate)
        .lte('to_date', dateRange.toDate);
    transactions = (tRes as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } else {
    final db = await OfflineDbHelper.instance.database;
    final fRes = await db.query('farmers', orderBy: 'name ASC');
    farmersRows = fRes.map((e) => Map<String, dynamic>.from(e)).toList();

    final cRes = await db.query(
      'milk_collections',
      where: 'collection_date >= ? AND collection_date <= ?',
      whereArgs: [dateRange.fromDate, dateRange.toDate],
    );
    collections = cRes.map((e) => Map<String, dynamic>.from(e)).toList();

    final tRes = await db.query(
      'bonus_transactions',
      where: 'from_date >= ? AND to_date <= ?',
      whereArgs: [dateRange.fromDate, dateRange.toDate],
    );
    transactions = tRes.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  final farmersMap = <String, Map<String, dynamic>>{};
  for (var f in farmersRows) {
    farmersMap[f['id'].toString()] = f;
  }

  // Sum payments per farmer
  final farmerPaidMap = <String, double>{};
  for (var t in transactions) {
    final fid = t['farmer_id'].toString();
    final amt = (t['paid_amount'] as num?)?.toDouble() ?? 0.0;
    farmerPaidMap[fid] = (farmerPaidMap[fid] ?? 0.0) + amt;
  }

  // Group milk collection per farmer
  final farmerMilkData = <String, Map<String, double>>{};
  for (var c in collections) {
    final fid = c['farmer_id']?.toString();
    if (fid == null || fid.isEmpty) continue;

    farmerMilkData.putIfAbsent(fid, () => {'cow': 0.0, 'buff': 0.0});
    final qty = (c['quantity'] as num?)?.toDouble() ?? 0.0;
    final type = (c['milk_type'] ?? c['milkType'] ?? '').toString().toLowerCase();

    if (type.contains('buff')) {
      farmerMilkData[fid]!['buff'] = farmerMilkData[fid]!['buff']! + qty;
    } else {
      farmerMilkData[fid]!['cow'] = farmerMilkData[fid]!['cow']! + qty;
    }
  }

  final summaries = <BonusFarmerSummary>[];
  double grandTotalCollection = 0.0;
  double grandTotalBonus = 0.0;
  double grandPaidBonus = 0.0;

  for (var entry in farmerMilkData.entries) {
    final fid = entry.key;
    final cowQty = entry.value['cow']!;
    final buffQty = entry.value['buff']!;
    final totalMilk = cowQty + buffQty;

    final cowBonus = cowQty * settings.cowRate;
    final buffBonus = buffQty * settings.buffaloRate;
    final totalBonus = cowBonus + buffBonus;
    final paidAmount = farmerPaidMap[fid] ?? 0.0;
    final remainingBonus = (totalBonus - paidAmount).clamp(0.0, double.infinity);

    grandTotalCollection += totalMilk;
    grandTotalBonus += totalBonus;
    grandPaidBonus += paidAmount;

    final farmer = farmersMap[fid];
    final farmerName = farmer?['name']?.toString() ?? 'Unknown Farmer';
    final farmerNo = farmer?['farmer_no'] != null ? 'F-${farmer!['farmer_no'].toString().padLeft(4, '0')}' : null;
    final mobile = farmer?['mobile']?.toString();
    final address = farmer?['address']?.toString() ?? farmer?['village']?.toString();

    String animalType = 'Buffalo';
    if (cowQty > 0 && buffQty == 0) {
      animalType = 'Cow';
    } else if (buffQty > 0 && cowQty == 0) {
      animalType = 'Buffalo';
    } else if (cowQty > 0 && buffQty > 0) {
      animalType = 'Both';
    }

    String status = 'Unpaid';
    if (remainingBonus <= 0.01 && paidAmount > 0) {
      status = 'Paid';
    } else if (paidAmount > 0) {
      status = 'Partial';
    }

    summaries.add(BonusFarmerSummary(
      farmerId: fid,
      farmerName: farmerName,
      farmerNo: farmerNo,
      mobile: mobile,
      address: address,
      animalType: animalType,
      cowMilk: cowQty,
      buffaloMilk: buffQty,
      totalMilk: totalMilk,
      cowRate: settings.cowRate,
      buffaloRate: settings.buffaloRate,
      cowBonus: cowBonus,
      buffaloBonus: buffBonus,
      totalBonus: totalBonus,
      paidAmount: paidAmount,
      remainingBonus: remainingBonus,
      status: status,
    ));
  }

  // Sort summary by farmer name
  summaries.sort((a, b) => a.farmerName.compareTo(b.farmerName));

  final grandRemaining = (grandTotalBonus - grandPaidBonus).clamp(0.0, double.infinity);

  return BonusCalculationSummary(
    totalCollection: grandTotalCollection,
    totalBonus: grandTotalBonus,
    paidBonus: grandPaidBonus,
    remainingBonus: grandRemaining,
    farmersSummary: summaries,
  );
});

class BonusTransactionsNotifier extends AsyncNotifier<List<BonusTransaction>> {
  @override
  Future<List<BonusTransaction>> build() async {
    return _fetchTransactions();
  }

  Future<List<BonusTransaction>> _fetchTransactions() async {
    final dateRange = ref.watch(bonusDateRangeProvider);

    if (!AppConfig.isOfflineMode && !AppConfig.isHybridMode) {
      final supabase = ref.read(supabaseClientProvider);
      final res = await supabase.from('bonus_transactions')
          .select()
          .gte('payment_date', dateRange.fromDate)
          .lte('payment_date', dateRange.toDate)
          .order('payment_date', ascending: false)
          .order('created_at', ascending: false);
      return (res as List).map((r) => BonusTransaction.fromJson(Map<String, dynamic>.from(r as Map))).toList();
    }

    final db = await OfflineDbHelper.instance.database;
    final rows = await db.query(
      'bonus_transactions',
      where: 'payment_date >= ? AND payment_date <= ?',
      whereArgs: [dateRange.fromDate, dateRange.toDate],
      orderBy: 'payment_date DESC, created_at DESC',
    );

    return rows.map((r) => BonusTransaction.fromJson(r)).toList();
  }

  Future<void> recordPayment(BonusTransaction txn) async {
    if (!AppConfig.isOfflineMode && !AppConfig.isHybridMode) {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('bonus_transactions').insert(txn.toJson());
    } else {
      final db = await OfflineDbHelper.instance.database;
      await db.insert('bonus_transactions', txn.toJson());

      if (AppConfig.isHybridMode) {
        await OfflineDbHelper.instance.enqueueSync(
          tableName: 'bonus_transactions',
          rowId: txn.id,
          action: 'UPSERT',
          payload: jsonEncode(txn.toJson()),
        );
        SyncService.instance.triggerSync();
      }
    }

    ref.invalidateSelf();
    ref.invalidate(bonusCalculationProvider);
  }

  Future<void> updatePayment(BonusTransaction txn) async {
    if (!AppConfig.isOfflineMode && !AppConfig.isHybridMode) {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('bonus_transactions').update(txn.toJson()).eq('id', txn.id);
    } else {
      final db = await OfflineDbHelper.instance.database;
      await db.update('bonus_transactions', txn.toJson(), where: 'id = ?', whereArgs: [txn.id]);

      if (AppConfig.isHybridMode) {
        await OfflineDbHelper.instance.enqueueSync(
          tableName: 'bonus_transactions',
          rowId: txn.id,
          action: 'UPSERT',
          payload: jsonEncode(txn.toJson()),
        );
        SyncService.instance.triggerSync();
      }
    }

    ref.invalidateSelf();
    ref.invalidate(bonusCalculationProvider);
  }

  Future<void> deletePayment(String id) async {
    if (!AppConfig.isOfflineMode && !AppConfig.isHybridMode) {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.from('bonus_transactions').delete().eq('id', id);
    } else {
      final db = await OfflineDbHelper.instance.database;
      await db.delete('bonus_transactions', where: 'id = ?', whereArgs: [id]);

      if (AppConfig.isHybridMode) {
        await OfflineDbHelper.instance.enqueueSync(
          tableName: 'bonus_transactions',
          rowId: id,
          action: 'DELETE',
          payload: jsonEncode({'id': id}),
        );
        SyncService.instance.triggerSync();
      }
    }

    ref.invalidateSelf();
    ref.invalidate(bonusCalculationProvider);
  }
}

final bonusTransactionsProvider = AsyncNotifierProvider<BonusTransactionsNotifier, List<BonusTransaction>>(
  BonusTransactionsNotifier.new,
);
