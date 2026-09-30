import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../services/offline_db_helper.dart';
import '../services/app_config.dart';

class RateConfig {
  final String id;
  final String animalType;
  final String rateType; // 'Increase' or 'Decrease'
  final double baseFat;
  final double baseSnf;
  final double baseRate;
  
  final double fatRangeFrom;
  final double fatRangeTo;
  final double fatPoint;
  final double fatRate;
  
  final double snfRangeFrom;
  final double snfRangeTo;
  final double snfPoint;
  final double snfRate;
  
  final String effectiveDate;
  final bool isActive;
  final String createdAt;

  RateConfig({
    required this.id, required this.animalType, required this.rateType,
    required this.baseFat, required this.baseSnf, required this.baseRate,
    required this.fatRangeFrom, required this.fatRangeTo, required this.fatPoint, required this.fatRate,
    required this.snfRangeFrom, required this.snfRangeTo, required this.snfPoint, required this.snfRate,
    required this.effectiveDate, required this.isActive, required this.createdAt
  });
  
  factory RateConfig.fromJson(Map<String, dynamic> json) => RateConfig(
    id: json['id']?.toString() ?? '',
    animalType: json['animal_type']?.toString() ?? 'Cow Milk',
    rateType: json['rate_type']?.toString() ?? 'Increase',
    baseFat: (json['base_fat'] ?? 0).toDouble(),
    baseSnf: (json['base_snf'] ?? 0).toDouble(),
    baseRate: (json['base_rate'] ?? 0).toDouble(),
    fatRangeFrom: (json['fat_range_from'] ?? 0).toDouble(),
    fatRangeTo: (json['fat_range_to'] ?? 0).toDouble(),
    fatPoint: (json['fat_point'] ?? 0.1).toDouble(),
    fatRate: (json['fat_rate'] ?? 0).toDouble(),
    snfRangeFrom: (json['snf_range_from'] ?? 0).toDouble(),
    snfRangeTo: (json['snf_range_to'] ?? 0).toDouble(),
    snfPoint: (json['snf_point'] ?? 0.1).toDouble(),
    snfRate: (json['snf_rate'] ?? 0).toDouble(),
    effectiveDate: json['effective_date']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    isActive: json['is_active'] is bool ? json['is_active'] : (json['is_active'] == 1 || json['is_active'] == null || json['is_active'] == 'true'),
    createdAt: json['created_at']?.toString() ?? '',
  );
}

class RateConfigNotifier extends AsyncNotifier<List<RateConfig>> {
  @override
  Future<List<RateConfig>> build() async {
    return _fetchConfigs();
  }

  Future<List<RateConfig>> _fetchConfigs() async {
    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('rate_configs')
          .select()
          .order('effective_date', ascending: false)
          .order('created_at', ascending: false);
      final configs = (response as List).map((e) => RateConfig.fromJson(e)).toList();

      // Cache into local SQLite for offline resilience
      try {
        final db = await OfflineDbHelper.instance.database;
        for (var c in configs) {
          await db.insert('rate_configs', {
            'id': c.id,
            'animal_type': c.animalType,
            'rate_type': c.rateType,
            'base_fat': c.baseFat,
            'base_snf': c.baseSnf,
            'base_rate': c.baseRate,
            'fat_range_from': c.fatRangeFrom,
            'fat_range_to': c.fatRangeTo,
            'fat_point': c.fatPoint,
            'fat_rate': c.fatRate,
            'snf_range_from': c.snfRangeFrom,
            'snf_range_to': c.snfRangeTo,
            'snf_point': c.snfPoint,
            'snf_rate': c.snfRate,
            'effective_date': c.effectiveDate,
            'is_active': c.isActive ? 1 : 0,
            'created_at': c.createdAt,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } catch (e) {
        debugPrint('Rate cache offline note: $e');
      }

      return configs;
    } catch (e) {
      debugPrint('Cloud rate fetch note: $e. Falling back to offline DB.');
      try {
        final db = await OfflineDbHelper.instance.database;
        final res = await db.query('rate_configs', orderBy: 'effective_date DESC, created_at DESC');
        return res.map((e) => RateConfig.fromJson(e)).toList();
      } catch (err) {
        debugPrint('Offline rate fetch error: $err');
        return [];
      }
    }
  }

  // Calculates rate on the fly based on saved configurations
  Future<double?> getApplicableRate(String milkType, double fat, double snf, DateTime collectionDate) async {
    List<RateConfig> configs = [];
    final dateStr = DateFormat('yyyy-MM-dd').format(collectionDate);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase
          .from('rate_configs')
          .select()
          .eq('animal_type', milkType)
          .eq('is_active', true)
          .lte('effective_date', dateStr)
          .order('effective_date', ascending: false);
      configs = (response as List).map((e) => RateConfig.fromJson(e)).toList();
    } catch (_) {
      try {
        final db = await OfflineDbHelper.instance.database;
        final res = await db.query(
          'rate_configs',
          where: 'animal_type = ? AND is_active = 1 AND effective_date <= ?',
          whereArgs: [milkType, dateStr],
          orderBy: 'effective_date DESC',
        );
        configs = res.map((e) => RateConfig.fromJson(e)).toList();
      } catch (_) {}
    }

    if (configs.isEmpty) {
      // Fallback: If no config exists on or before collectionDate, check in-memory state
      final currentList = state.value ?? [];
      configs = currentList.where((c) => c.animalType == milkType && c.isActive).toList();
      if (configs.isEmpty) return null;
    }

    // configs is sorted by effective_date DESC.
    final incConfig = configs.where((c) => c.rateType == 'Increase').firstOrNull;
    final decConfig = configs.where((c) => c.rateType == 'Decrease').firstOrNull;

    if (incConfig == null && decConfig == null) return null;

    // Use base values from the latest configuration
    final latestConfig = configs.first;
    double baseRate = latestConfig.baseRate;
    double baseFat = latestConfig.baseFat;
    double baseSnf = latestConfig.baseSnf;

    double finalRate = baseRate;

    // Fat Calculation
    if (fat >= baseFat) {
      if (incConfig != null && incConfig.fatPoint > 0) {
        double diff = fat - baseFat;
        int points = (diff / incConfig.fatPoint).round();
        finalRate += points * incConfig.fatRate;
      }
    } else {
      // Deduction for lower fat
      if (decConfig != null && decConfig.fatPoint > 0) {
        double diff = baseFat - fat;
        int points = (diff / decConfig.fatPoint).round();
        finalRate -= points * decConfig.fatRate;
      } else if (incConfig != null && incConfig.fatPoint > 0) {
        // Symmetrical deduction fallback if user maintains only the Increase chart
        double diff = baseFat - fat;
        int points = (diff / incConfig.fatPoint).round();
        finalRate -= points * incConfig.fatRate;
      }
    }

    // SNF Calculation
    if (snf >= baseSnf) {
      if (incConfig != null && incConfig.snfPoint > 0) {
        double diff = snf - baseSnf;
        int points = (diff / incConfig.snfPoint).round();
        finalRate += points * incConfig.snfRate;
      }
    } else {
      // Deduction for lower SNF
      if (decConfig != null && decConfig.snfPoint > 0) {
        double diff = baseSnf - snf;
        int points = (diff / decConfig.snfPoint).round();
        finalRate -= points * decConfig.snfRate;
      } else if (incConfig != null && incConfig.snfPoint > 0) {
        // Symmetrical deduction fallback if user maintains only the Increase chart
        double diff = baseSnf - snf;
        int points = (diff / incConfig.snfPoint).round();
        finalRate -= points * incConfig.snfRate;
      }
    }

    return double.parse(finalRate.toStringAsFixed(2));
  }

  Future<void> saveRateConfig(RateConfig config) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();

    try {
      final uid = supabase.auth.currentUser?.id;
      final newId = config.id.trim().isNotEmpty ? config.id.trim() : OfflineDbHelper.generateId();
      final nowStr = DateTime.now().toIso8601String();
      final insertData = {
        'id': newId,
        'animal_type': config.animalType,
        'rate_type': config.rateType,
        'base_fat': config.baseFat,
        'base_snf': config.baseSnf,
        'base_rate': config.baseRate,
        'fat_range_from': config.fatRangeFrom,
        'fat_range_to': config.fatRangeTo,
        'fat_point': config.fatPoint,
        'fat_rate': config.fatRate,
        'snf_range_from': config.snfRangeFrom,
        'snf_range_to': config.snfRangeTo,
        'snf_point': config.snfPoint,
        'snf_rate': config.snfRate,
        'effective_date': config.effectiveDate,
        'is_active': true,
        'created_at': nowStr,
        if (uid != null) 'user_id': uid,
      };

      try {
        await supabase.from('rate_configs').insert(insertData);
      } catch (e) {
        debugPrint('Supabase rate_configs insert note: $e');
      }

      try {
        final db = await OfflineDbHelper.instance.database;
        await db.insert('rate_configs', {
          ...insertData,
          'is_active': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        if (AppConfig.isHybridMode) {
          await OfflineDbHelper.instance.enqueueSync(
            tableName: 'rate_configs',
            rowId: newId,
            action: 'UPSERT',
            payload: jsonEncode(insertData),
          );
        }
      } catch (e) {
        debugPrint('Offline rate_configs insert error: $e');
      }

      state = await AsyncValue.guard(() => _fetchConfigs());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateRateConfig(String id, RateConfig config) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();

    try {
      final uid = supabase.auth.currentUser?.id;
      final cleanId = id.trim();
      final updateData = {
        'animal_type': config.animalType,
        'rate_type': config.rateType,
        'base_fat': config.baseFat,
        'base_snf': config.baseSnf,
        'base_rate': config.baseRate,
        'fat_range_from': config.fatRangeFrom,
        'fat_range_to': config.fatRangeTo,
        'fat_point': config.fatPoint,
        'fat_rate': config.fatRate,
        'snf_range_from': config.snfRangeFrom,
        'snf_range_to': config.snfRangeTo,
        'snf_point': config.snfPoint,
        'snf_rate': config.snfRate,
        'effective_date': config.effectiveDate,
        'is_active': config.isActive,
        if (uid != null) 'user_id': uid,
      };

      try {
        if (cleanId.isNotEmpty) {
          await supabase.from('rate_configs').update(updateData).eq('id', cleanId);
        }
      } catch (e) {
        debugPrint('Supabase rate_configs update note: $e');
      }

      try {
        final db = await OfflineDbHelper.instance.database;
        if (cleanId.isNotEmpty) {
          await db.update('rate_configs', {
            ...updateData,
            'is_active': config.isActive ? 1 : 0,
          }, where: 'id = ?', whereArgs: [cleanId]);
        }
        if (AppConfig.isHybridMode && cleanId.isNotEmpty) {
          await OfflineDbHelper.instance.enqueueSync(
            tableName: 'rate_configs',
            rowId: cleanId,
            action: 'UPSERT',
            payload: jsonEncode(updateData),
          );
        }
      } catch (e) {
        debugPrint('Offline rate_configs update note: $e');
      }

      state = await AsyncValue.guard(() => _fetchConfigs());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteRateConfig(String id, {RateConfig? config}) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      final cleanId = id.trim();
      if (cleanId.isNotEmpty) {
        try {
          await supabase.from('rate_configs').delete().eq('id', cleanId);
        } catch (e) {
          debugPrint('Supabase delete error: $e');
        }
      }
      if (config != null) {
        try {
          await supabase
              .from('rate_configs')
              .delete()
              .eq('animal_type', config.animalType)
              .eq('rate_type', config.rateType)
              .eq('effective_date', config.effectiveDate)
              .eq('base_rate', config.baseRate);
        } catch (_) {}
      }

      try {
        final db = await OfflineDbHelper.instance.database;
        if (cleanId.isNotEmpty) {
          await db.delete('rate_configs', where: 'id = ?', whereArgs: [cleanId]);
        }
        if (config != null) {
          await db.delete(
            'rate_configs',
            where: 'animal_type = ? AND rate_type = ? AND effective_date = ? AND base_rate = ?',
            whereArgs: [config.animalType, config.rateType, config.effectiveDate, config.baseRate],
          );
        }
        if (AppConfig.isHybridMode && cleanId.isNotEmpty) {
          await OfflineDbHelper.instance.enqueueSync(
            tableName: 'rate_configs',
            rowId: cleanId,
            action: 'DELETE',
            payload: '{}',
          );
        }
      } catch (_) {}

      state = await AsyncValue.guard(() => _fetchConfigs());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final rateConfigProvider = AsyncNotifierProvider<RateConfigNotifier, List<RateConfig>>(() {
  return RateConfigNotifier();
});
