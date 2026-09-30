import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/flutter_models.dart';
import 'auth_provider.dart';
import '../services/offline_db_helper.dart';

class MainDairyRateNotifier extends AsyncNotifier<List<MainDairyRateConfig>> {
  @override
  Future<List<MainDairyRateConfig>> build() async {
    return _fetchConfigs();
  }

  Future<List<MainDairyRateConfig>> _fetchConfigs() async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final response = await supabase
          .from('main_dairy_rate_configs')
          .select()
          .order('effective_date', ascending: false);
      return (response as List).map((json) => MainDairyRateConfig.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  // Calculates rate on the fly based on saved configurations
  Future<double?> getApplicableRate(String milkType, double fat, double snf, DateTime collectionDate) async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(collectionDate);
      final response = await supabase
          .from('main_dairy_rate_configs')
          .select()
          .eq('animal_type', milkType)
          .eq('is_active', true)
          .lte('effective_date', dateStr)
          .order('effective_date', ascending: false);

      final configs = (response as List).map((e) => MainDairyRateConfig.fromJson(e)).toList();
      if (configs.isEmpty) return null;

      final latestEffectiveDate = configs.first.effectiveDate;
      final activeConfigs = configs.where((c) => c.effectiveDate == latestEffectiveDate).toList();

      final incConfig = activeConfigs.where((c) => c.rateType == 'Increase').firstOrNull;
      final decConfig = activeConfigs.where((c) => c.rateType == 'Decrease').firstOrNull;

      if (incConfig == null && decConfig == null) {
        // Fallback to legacy single standard config
        final standard = activeConfigs.first;
        double rate = standard.baseRate;
        final fatDiff = fat - standard.baseFat;
        rate += (fatDiff * 10) * standard.fatRate;
        final snfDiff = snf - standard.baseSnf;
        rate += (snfDiff * 10) * standard.snfRate;
        return rate > 0 ? double.parse(rate.toStringAsFixed(2)) : 0.0;
      }

      double baseRate = incConfig?.baseRate ?? decConfig?.baseRate ?? 0;
      double baseFat = incConfig?.baseFat ?? decConfig?.baseFat ?? 0;
      double baseSnf = incConfig?.baseSnf ?? decConfig?.baseSnf ?? 0;

      double finalRate = baseRate;

      // Fat Calculation
      if (fat >= baseFat && incConfig != null && incConfig.fatPoint > 0) {
        double diff = fat - baseFat;
        int points = (diff / incConfig.fatPoint).round();
        finalRate += points * incConfig.fatRate;
      } else if (fat < baseFat && decConfig != null && decConfig.fatPoint > 0) {
        double diff = baseFat - fat;
        int points = (diff / decConfig.fatPoint).round();
        finalRate -= points * decConfig.fatRate;
      }

      // SNF Calculation
      if (snf >= baseSnf && incConfig != null && incConfig.snfPoint > 0) {
        double diff = snf - baseSnf;
        int points = (diff / incConfig.snfPoint).round();
        finalRate += points * incConfig.snfRate;
      } else if (snf < baseSnf && decConfig != null && decConfig.snfPoint > 0) {
        double diff = baseSnf - snf;
        int points = (diff / decConfig.snfPoint).round();
        finalRate -= points * decConfig.snfRate;
      }

      return double.parse(finalRate.toStringAsFixed(2));
    } catch (_) {
      return null;
    }
  }

  double calculateRate({
    required String animalType,
    required double fat,
    required double snf,
  }) {
    final configs = state.value ?? [];
    final matching = configs.where((c) => c.animalType == animalType && c.isActive).toList();
    if (matching.isEmpty) return 0.0;

    final incConfig = matching.where((c) => c.rateType == 'Increase').firstOrNull;
    final decConfig = matching.where((c) => c.rateType == 'Decrease').firstOrNull;

    if (incConfig != null || decConfig != null) {
      double baseRate = incConfig?.baseRate ?? decConfig?.baseRate ?? 0;
      double baseFat = incConfig?.baseFat ?? decConfig?.baseFat ?? 0;
      double baseSnf = incConfig?.baseSnf ?? decConfig?.baseSnf ?? 0;

      double finalRate = baseRate;
      if (fat >= baseFat && incConfig != null && incConfig.fatPoint > 0) {
        double diff = fat - baseFat;
        int points = (diff / incConfig.fatPoint).round();
        finalRate += points * incConfig.fatRate;
      } else if (fat < baseFat && decConfig != null && decConfig.fatPoint > 0) {
        double diff = baseFat - fat;
        int points = (diff / decConfig.fatPoint).round();
        finalRate -= points * decConfig.fatRate;
      }

      if (snf >= baseSnf && incConfig != null && incConfig.snfPoint > 0) {
        double diff = snf - baseSnf;
        int points = (diff / incConfig.snfPoint).round();
        finalRate += points * incConfig.snfRate;
      } else if (snf < baseSnf && decConfig != null && decConfig.snfPoint > 0) {
        double diff = baseSnf - snf;
        int points = (diff / decConfig.snfPoint).round();
        finalRate -= points * decConfig.snfRate;
      }
      return finalRate > 0 ? double.parse(finalRate.toStringAsFixed(2)) : 0.0;
    }

    final config = matching.first;
    double rate = config.baseRate;
    final fatDiff = fat - config.baseFat;
    rate += (fatDiff * 10) * config.fatRate;
    final snfDiff = snf - config.baseSnf;
    rate += (snfDiff * 10) * config.snfRate;

    return rate > 0 ? double.parse(rate.toStringAsFixed(2)) : 0.0;
  }

  Future<void> saveRateConfig(MainDairyRateConfig config) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      final uid = supabase.auth.currentUser?.id;
      try {
        await supabase.from('main_dairy_rate_configs').insert({
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
          if (uid != null) 'user_id': uid,
        });
      } on PostgrestException catch (pe) {
        if (pe.code == 'PGRST204') {
          // If fat_point / snf_point columns are not in table yet, insert without them
          await supabase.from('main_dairy_rate_configs').insert({
            'animal_type': config.animalType,
            'rate_type': config.rateType,
            'base_fat': config.baseFat,
            'base_snf': config.baseSnf,
            'base_rate': config.baseRate,
            'fat_range_from': config.fatRangeFrom,
            'fat_range_to': config.fatRangeTo,
            'fat_rate': config.fatRate,
            'snf_range_from': config.snfRangeFrom,
            'snf_range_to': config.snfRangeTo,
            'snf_rate': config.snfRate,
            'effective_date': config.effectiveDate,
            'is_active': true,
            if (uid != null) 'user_id': uid,
          });
        } else {
          rethrow;
        }
      }
      state = await AsyncValue.guard(() => _fetchConfigs());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateRateConfig(String id, MainDairyRateConfig config) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
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
      };

      if (cleanId.isNotEmpty) {
        try {
          await supabase.from('main_dairy_rate_configs').update(updateData).eq('id', cleanId);
        } catch (_) {}
      }

      try {
        final db = await OfflineDbHelper.instance.database;
        if (cleanId.isNotEmpty) {
          await db.update('main_dairy_rate_configs', {
            ...updateData,
            'is_active': config.isActive ? 1 : 0,
          }, where: 'id = ?', whereArgs: [cleanId]);
        }
      } catch (_) {}

      state = await AsyncValue.guard(() => _fetchConfigs());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteRateConfig(String id, {MainDairyRateConfig? config}) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      final cleanId = id.trim();
      if (cleanId.isNotEmpty) {
        await supabase.from('main_dairy_rate_configs').delete().eq('id', cleanId);
      }
      try {
        final db = await OfflineDbHelper.instance.database;
        if (cleanId.isNotEmpty) {
          await db.delete('main_dairy_rate_configs', where: 'id = ?', whereArgs: [cleanId]);
        }
        if (config != null) {
          await db.delete(
            'main_dairy_rate_configs',
            where: 'animal_type = ? AND rate_type = ? AND effective_date = ? AND base_rate = ? AND fat_point = ? AND fat_rate = ?',
            whereArgs: [config.animalType, config.rateType, config.effectiveDate, config.baseRate, config.fatPoint, config.fatRate],
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

final mainDairyRateProvider = AsyncNotifierProvider<MainDairyRateNotifier, List<MainDairyRateConfig>>(() {
  return MainDairyRateNotifier();
});
