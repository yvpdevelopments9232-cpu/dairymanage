import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import 'package:intl/intl.dart';
import '../services/offline_db_helper.dart';

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
    animalType: json['animal_type'],
    rateType: json['rate_type'],
    baseFat: (json['base_fat'] ?? 0).toDouble(),
    baseSnf: (json['base_snf'] ?? 0).toDouble(),
    baseRate: (json['base_rate'] ?? 0).toDouble(),
    fatRangeFrom: (json['fat_range_from'] ?? 0).toDouble(),
    fatRangeTo: (json['fat_range_to'] ?? 0).toDouble(),
    fatPoint: (json['fat_point'] ?? 0).toDouble(),
    fatRate: (json['fat_rate'] ?? 0).toDouble(),
    snfRangeFrom: (json['snf_range_from'] ?? 0).toDouble(),
    snfRangeTo: (json['snf_range_to'] ?? 0).toDouble(),
    snfPoint: (json['snf_point'] ?? 0).toDouble(),
    snfRate: (json['snf_rate'] ?? 0).toDouble(),
    effectiveDate: json['effective_date'],
    isActive: json['is_active'] is bool ? json['is_active'] : (json['is_active'] == 1 || json['is_active'] == null || json['is_active'] == 'true'),
    createdAt: json['created_at'] ?? '',
  );
}

class RateConfigNotifier extends AsyncNotifier<List<RateConfig>> {
  @override
  Future<List<RateConfig>> build() async {
    return _fetchConfigs();
  }

  Future<List<RateConfig>> _fetchConfigs() async {
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase
        .from('rate_configs')
        .select()
        .order('created_at', ascending: false);
    return (response as List).map((e) => RateConfig.fromJson(e)).toList();
  }

  // Calculates rate on the fly based on saved configurations
  Future<double?> getApplicableRate(String milkType, double fat, double snf, DateTime collectionDate) async {
    final supabase = ref.read(supabaseClientProvider);
    
    // Fetch configs for this animal type that are active and effective on or before collectionDate
    final dateStr = DateFormat('yyyy-MM-dd').format(collectionDate);
    final response = await supabase
        .from('rate_configs')
        .select()
        .eq('animal_type', milkType)
        .eq('is_active', true)
        .lte('effective_date', dateStr)
        .order('effective_date', ascending: false);
        
    final configs = (response as List).map((e) => RateConfig.fromJson(e)).toList();
    
    if (configs.isEmpty) return null; // No configs found
    
    // We expect the most recent effective_date to be our active period.
    // It's possible there are both Increase and Decrease configs for the same effective date.
    final latestEffectiveDate = configs.first.effectiveDate;
    final activeConfigs = configs.where((c) => c.effectiveDate == latestEffectiveDate).toList();
    
    final incConfig = activeConfigs.where((c) => c.rateType == 'Increase').firstOrNull;
    final decConfig = activeConfigs.where((c) => c.rateType == 'Decrease').firstOrNull;
    
    if (incConfig == null && decConfig == null) return null;
    
    // We use the base rate from either config (they should match, but we fallback)
    double baseRate = incConfig?.baseRate ?? decConfig?.baseRate ?? 0;
    double baseFat = incConfig?.baseFat ?? decConfig?.baseFat ?? 0;
    double baseSnf = incConfig?.baseSnf ?? decConfig?.baseSnf ?? 0;
    
    double finalRate = baseRate;
    
    // Fat Calculation
    if (fat >= baseFat && incConfig != null && incConfig.fatPoint > 0) {
      double diff = fat - baseFat;
      int points = (diff / incConfig.fatPoint).round(); // Handle precision issues e.g. 0.3 / 0.1 = 3
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
  }

  Future<void> saveRateConfig(RateConfig config) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    
    try {
      await supabase.from('rate_configs').insert({
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
      });
      
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
        await supabase.from('rate_configs').delete().eq('id', cleanId);
      }
      if (config != null) {
        try {
          final db = await OfflineDbHelper.instance.database;
          await db.delete(
            'rate_configs',
            where: 'animal_type = ? AND rate_type = ? AND effective_date = ? AND base_rate = ? AND fat_point = ? AND fat_rate = ?',
            whereArgs: [config.animalType, config.rateType, config.effectiveDate, config.baseRate, config.fatPoint, config.fatRate],
          );
        } catch (_) {}
      }
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
