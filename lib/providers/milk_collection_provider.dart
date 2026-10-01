import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flutter_models.dart';
import 'auth_provider.dart';
import 'package:intl/intl.dart';

// Provides animals for a farmer
final farmerAnimalsProvider = FutureProvider.family<List<Animal>, String>((ref, farmerId) async {
  final supabase = ref.read(supabaseClientProvider);
  final response = await supabase.from('animals').select().eq('farmer_id', farmerId);
  return (response as List).map((json) => Animal.fromJson(json)).toList();
});

class MilkCollectionNotifier extends AsyncNotifier<List<MilkCollection>> {
  String currentDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String currentShift = DateTime.now().hour < 14 ? 'Morning' : 'Evening';

  @override
  Future<List<MilkCollection>> build() async {
    return _fetchCollections(currentDate, currentShift);
  }

  void setFilters(String date, String shift) async {
    currentDate = date;
    currentShift = shift;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchCollections(currentDate, currentShift));
  }

  Future<List<MilkCollection>> _fetchCollections(String date, String shift) async {
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase
        .from('milk_collections')
        .select('*, farmers(name, farmer_no)')
        .eq('collection_date', date)
        .eq('shift', shift)
        .order('created_at', ascending: false);
        
    return (response as List).map((json) => MilkCollection.fromJson(json)).toList();
  }

  Future<void> addCollection({
    required String date,
    required String time,
    required String shift,
    required String farmerId,
    String? animalId,
    required String milkType,
    required double qty,
    required double fat,
    required double snf,
    required double rate,
    double? totalAmount,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    
    try {
      // 1. Check if entry already exists for this farmer in this shift
      final existing = await supabase.from('milk_collections')
          .select()
          .eq('collection_date', date)
          .eq('shift', shift)
          .eq('farmer_id', farmerId)
          .maybeSingle();

      if (existing != null) {
        // MERGE DOUBLE ENTRY
        double oldQty = (existing['quantity'] as num).toDouble();
        double oldFat = (existing['fat'] as num).toDouble();
        double oldSnf = (existing['snf'] as num).toDouble();
        double oldRate = (existing['rate'] as num).toDouble();

        double combinedQty = oldQty + qty;
        
        // Calculate weighted averages for mathematically perfect merging (guarded against division by zero)
        double combinedFat = combinedQty > 0 ? ((oldQty * oldFat) + (qty * fat)) / combinedQty : 0.0;
        double combinedSnf = combinedQty > 0 ? ((oldQty * oldSnf) + (qty * snf)) / combinedQty : 0.0;
        double combinedRate = combinedQty > 0 ? ((oldQty * oldRate) + (qty * rate)) / combinedQty : 0.0;
        double combinedTotal = double.parse((combinedQty * combinedRate).toStringAsFixed(2));

        await supabase.from('milk_collections').update({
          'quantity': double.parse(combinedQty.toStringAsFixed(2)),
          'fat': double.parse(combinedFat.toStringAsFixed(2)),
          'snf': double.parse(combinedSnf.toStringAsFixed(2)),
          'rate': double.parse(combinedRate.toStringAsFixed(2)),
          'total_amount': combinedTotal,
        }).eq('id', existing['id']);
        
      } else {
        // INSERT NEW ENTRY
        final calcTotal = totalAmount ?? double.parse((qty * rate).toStringAsFixed(2));
        await supabase.from('milk_collections').insert({
          'collection_date': date,
          'collection_time': time,
          'shift': shift,
          'farmer_id': farmerId,
          'animal_id': animalId,
          'milk_type': milkType,
          'quantity': qty,
          'fat': fat,
          'snf': snf,
          'rate': rate,
          'total_amount': calcTotal,
          'payment_status': 'Pending'
        });
      }
      
      state = await AsyncValue.guard(() => _fetchCollections(currentDate, currentShift));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateCollection(String id, {
    required double qty,
    required double fat,
    required double snf,
    required double rate,
    double? totalAmount,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    
    try {
      final calculatedTotal = totalAmount ?? double.parse((qty * rate).toStringAsFixed(2));
      await supabase.from('milk_collections').update({
        'quantity': qty,
        'fat': fat,
        'snf': snf,
        'rate': rate,
        'total_amount': calculatedTotal,
      }).eq('id', id);
      
      state = await AsyncValue.guard(() => _fetchCollections(currentDate, currentShift));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteCollection(String id) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('milk_collections').delete().eq('id', id);
      state = await AsyncValue.guard(() => _fetchCollections(currentDate, currentShift));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final milkCollectionProvider = AsyncNotifierProvider<MilkCollectionNotifier, List<MilkCollection>>(() {
  return MilkCollectionNotifier();
});
