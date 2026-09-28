import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import '../services/app_db.dart';
import 'farmer_provider.dart';

class AnimalNotifier extends AsyncNotifier<List<Animal>> {
  dynamic get _supabase => AppDb.client;

  @override
  Future<List<Animal>> build() async {
    return _fetchAnimals();
  }

  Future<List<Animal>> _fetchAnimals() async {
    final response = await _supabase
        .from('animals')
        .select('*, farmers(name, farmer_no)')
        .order('created_at', ascending: false);
        
    // Supabase nested joins return the joined table as a map.
    // We can map this directly into our Animal model if needed, but for the UI we might need the farmer name.
    // Let's create a list and attach farmer name via a wrapper or just rely on the FarmerProvider in the UI.
    return (response as List).map((e) => Animal.fromJson(e)).toList();
  }

  Future<void> addAnimal({
    required String farmerId,
    required String animalType,
    String? breed,
    String? name,
    int? age,
    double? milkCapacity,
  }) async {
    await _supabase.from('animals').insert({
      'farmer_id': farmerId,
      'animal_type': animalType,
      'breed': breed,
      'name': name,
      'age': age,
      'milk_capacity': milkCapacity,
    });
    ref.invalidateSelf();
  }

  Future<void> toggleStatus(String id, bool currentStatus) async {
    await _supabase.from('animals').update({'status': !currentStatus}).eq('id', id);
    ref.invalidateSelf();
  }
  
  Future<void> deleteAnimal(String id) async {
    await _supabase.from('animals').delete().eq('id', id);
    ref.invalidateSelf();
  }
}

final animalProvider = AsyncNotifierProvider<AnimalNotifier, List<Animal>>(() => AnimalNotifier());
