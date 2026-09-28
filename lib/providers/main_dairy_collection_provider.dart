import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import 'auth_provider.dart';

class MainDairyCollectionNotifier extends AsyncNotifier<List<MainDairyCollection>> {
  String _selectedDate = DateTime.now().toIso8601String().split('T')[0];
  String _selectedShift = 'Morning';

  String get selectedDate => _selectedDate;
  String get selectedShift => _selectedShift;
  String get currentDate => _selectedDate;
  String get currentShift => _selectedShift;

  @override
  Future<List<MainDairyCollection>> build() async {
    _selectedShift = DateTime.now().hour < 15 ? 'Morning' : 'Evening';
    return _fetchCollections();
  }

  void setFilter(String date, String shift) {
    _selectedDate = date;
    _selectedShift = shift;
    ref.invalidateSelf();
  }

  void setFilters(String date, String shift) {
    _selectedDate = date;
    _selectedShift = shift;
    ref.invalidateSelf();
  }

  Future<List<MainDairyCollection>> _fetchCollections() async {
    final supabase = ref.read(supabaseClientProvider);
    try {
      final response = await supabase
          .from('main_dairy_collections')
          .select('*, main_dairies(name, dairy_no)')
          .eq('collection_date', _selectedDate)
          .eq('shift', _selectedShift)
          .order('created_at', ascending: false);
      return (response as List).map((json) => MainDairyCollection.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addCollection({
    required String mainDairyId,
    required String date,
    required String shift,
    required String milkType,
    required double quantity,
    required double fat,
    required double snf,
    required double rate,
    required double totalAmount,
    String? remarks,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('main_dairy_collections').insert({
        'main_dairy_id': mainDairyId,
        'collection_date': date,
        'shift': shift,
        'milk_type': milkType,
        'quantity': quantity,
        'fat': fat,
        'snf': snf,
        'rate': rate,
        'total_amount': totalAmount,
        'remarks': remarks,
        'payment_status': 'Pending',
      });
      state = await AsyncValue.guard(() => _fetchCollections());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateCollection(String id, {
    required double quantity,
    required double fat,
    required double snf,
    required double rate,
    required double totalAmount,
    String? milkType,
    String? mainDairyId,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      final updateData = <String, dynamic>{
        'quantity': quantity,
        'fat': fat,
        'snf': snf,
        'rate': rate,
        'total_amount': totalAmount,
      };
      if (milkType != null) updateData['milk_type'] = milkType;
      if (mainDairyId != null) updateData['main_dairy_id'] = mainDairyId;

      await supabase.from('main_dairy_collections').update(updateData).eq('id', id);
      state = await AsyncValue.guard(() => _fetchCollections());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteCollection(String id) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('main_dairy_collections').delete().eq('id', id);
      state = await AsyncValue.guard(() => _fetchCollections());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final mainDairyCollectionProvider = AsyncNotifierProvider<MainDairyCollectionNotifier, List<MainDairyCollection>>(() {
  return MainDairyCollectionNotifier();
});
