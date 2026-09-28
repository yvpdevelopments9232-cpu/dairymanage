import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import 'auth_provider.dart';

// The modern Riverpod 2.0+ way using AsyncNotifier
class FarmersNotifier extends AsyncNotifier<List<Farmer>> {
  
  @override
  Future<List<Farmer>> build() async {
    return _fetchFarmers();
  }

  Future<List<Farmer>> _fetchFarmers() async {
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase.from('farmers').select().order('name');
    return (response as List).map((json) => Farmer.fromJson(json)).toList();
  }

  Future<void> addFarmer(String name, String mobile, String address, String village, String animalType) async {
    final supabase = ref.read(supabaseClientProvider);
    
    final newFarmer = {
      'name': name,
      'mobile': mobile,
      'address': address,
      'village': village,
      'opening_balance': 0,
      'status': true,
    };
    
    state = const AsyncValue.loading();
    
    try {
      final insertedFarmer = await supabase.from('farmers').insert(newFarmer).select().single();
      
      await supabase.from('animals').insert({
        'farmer_id': insertedFarmer['id'],
        'animal_type': animalType,
        'name': 'Default $animalType',
      });
      
      state = await AsyncValue.guard(() => _fetchFarmers());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Update existing farmer
  Future<void> updateFarmer(String id, String name, String mobile, String address, String village, {String? animalType}) async {
    final supabase = ref.read(supabaseClientProvider);
    
    final updatedFarmer = {
      'name': name,
      'mobile': mobile,
      'address': address,
      'village': village,
    };
    
    state = const AsyncValue.loading();
    
    try {
      await supabase.from('farmers').update(updatedFarmer).eq('id', id);
        if (animalType != null) {
          final animals = await supabase.from('animals').select('id').eq('farmer_id', id).limit(1);
          if (animals.isNotEmpty) {
            await supabase.from('animals').update({'animal_type': animalType}).eq('id', animals[0]['id']);
          } else {
            await supabase.from('animals').insert({'farmer_id': id, 'animal_type': animalType, 'tag_no': 'Auto', 'breed': 'Unknown'});
          }
        }
      state = await AsyncValue.guard(() => _fetchFarmers());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Delete farmer
  Future<void> deleteFarmer(String id) async {
    final supabase = ref.read(supabaseClientProvider);
    
    state = const AsyncValue.loading();
    try {
      await supabase.from('farmers').delete().eq('id', id);
      state = await AsyncValue.guard(() => _fetchFarmers());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final farmersProvider = AsyncNotifierProvider<FarmersNotifier, List<Farmer>>(() {
  return FarmersNotifier();
});
