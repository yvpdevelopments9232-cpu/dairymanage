import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import 'auth_provider.dart';

import '../services/app_db.dart';
import '../services/offline_db_helper.dart';

class MainDairyNotifier extends AsyncNotifier<List<MainDairy>> {
  @override
  Future<List<MainDairy>> build() async {
    return _fetchDairies();
  }

  Future<List<MainDairy>> _fetchDairies() async {
    try {
      final response = await AppDb.from('main_dairies').select().order('dairy_no', ascending: true);
      final list = (response as List).map((json) => MainDairy.fromJson(json)).toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}

    try {
      final response = await AppDb.from('main_dairies').select().order('name');
      final list = (response as List).map((json) => MainDairy.fromJson(json)).toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}

    // Fallback to local SQLite if cloud query was empty or offline
    try {
      final db = await OfflineDbHelper.instance.database;
      final localRows = await db.query('main_dairies', orderBy: 'dairy_no ASC');
      return localRows.map((json) => MainDairy.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addDairy(MainDairy dairy) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    final note = 'village:${dairy.village ?? ""};animal:${dairy.animalType ?? "Cow"}';
    try {
      int nextDairyNo = 1;
      try {
        final maxRes = await supabase
            .from('main_dairies')
            .select('dairy_no')
            .order('dairy_no', ascending: false)
            .limit(1);
        if (maxRes.isNotEmpty && maxRes[0]['dairy_no'] != null) {
          nextDairyNo = (maxRes[0]['dairy_no'] as num).toInt() + 1;
        }
      } catch (_) {
        // Fallback to 1 if query fails
      }

      try {
        await supabase.from('main_dairies').insert({
          'dairy_no': nextDairyNo,
          'name': dairy.name,
          'contact_person': dairy.contactPerson,
          'mobile': dairy.mobile,
          'email': dairy.email,
          'address': dairy.address,
          'village': dairy.village,
          'animal_type': dairy.animalType,
          'opening_balance': dairy.openingBalance,
          'current_balance': dairy.openingBalance,
          'status': dairy.status,
          'notes': note,
        });
      } on PostgrestException catch (pe) {
        if (pe.code == 'PGRST204') {
          await supabase.from('main_dairies').insert({
            'dairy_no': nextDairyNo,
            'name': dairy.name,
            'contact_person': dairy.contactPerson,
            'mobile': dairy.mobile,
            'email': dairy.email,
            'address': dairy.address,
            'opening_balance': dairy.openingBalance,
            'current_balance': dairy.openingBalance,
            'status': dairy.status,
            'notes': note,
          });
        } else {
          rethrow;
        }
      }
      state = await AsyncValue.guard(() => _fetchDairies());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateDairy(MainDairy dairy) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    final note = 'village:${dairy.village ?? ""};animal:${dairy.animalType ?? "Cow"}';
    try {
      try {
        await supabase.from('main_dairies').update({
          'name': dairy.name,
          'contact_person': dairy.contactPerson,
          'mobile': dairy.mobile,
          'email': dairy.email,
          'address': dairy.address,
          'village': dairy.village,
          'animal_type': dairy.animalType,
          'status': dairy.status,
          'notes': note,
        }).eq('id', dairy.id);
      } on PostgrestException catch (pe) {
        if (pe.code == 'PGRST204') {
          await supabase.from('main_dairies').update({
            'name': dairy.name,
            'contact_person': dairy.contactPerson,
            'mobile': dairy.mobile,
            'email': dairy.email,
            'address': dairy.address,
            'status': dairy.status,
            'notes': note,
          }).eq('id', dairy.id);
        } else {
          rethrow;
        }
      }
      state = await AsyncValue.guard(() => _fetchDairies());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteDairy(String id) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('main_dairies').delete().eq('id', id);
      state = await AsyncValue.guard(() => _fetchDairies());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> recordPayment({
    required String mainDairyId,
    required double amount,
    required String paymentMode,
    String? referenceNo,
    String? remarks,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('main_dairy_payments').insert({
        'payment_date': DateTime.now().toIso8601String().split('T')[0],
        'main_dairy_id': mainDairyId,
        'amount': amount,
        'payment_mode': paymentMode,
        'reference_no': referenceNo,
        'remarks': remarks,
      });
      state = await AsyncValue.guard(() => _fetchDairies());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final mainDairyProvider = AsyncNotifierProvider<MainDairyNotifier, List<MainDairy>>(() {
  return MainDairyNotifier();
});
