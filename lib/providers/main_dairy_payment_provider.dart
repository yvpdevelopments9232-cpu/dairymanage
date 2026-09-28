import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flutter_models.dart';
import 'auth_provider.dart';
import 'main_dairy_provider.dart';

class MainDairyPaymentNotifier extends AsyncNotifier<List<MainDairyPayment>> {
  @override
  Future<List<MainDairyPayment>> build() async {
    return _fetchPayments();
  }

  Future<List<MainDairyPayment>> _fetchPayments() async {
    final supabase = ref.read(supabaseClientProvider);
    List<MainDairyPayment> payments = [];
    try {
      final response = await supabase
          .from('main_dairy_payments')
          .select('*, main_dairies(name, dairy_no)')
          .order('payment_date', ascending: false);
      payments = (response as List).map((json) => MainDairyPayment.fromJson(json)).toList();
    } catch (_) {
      try {
        final fallback = await supabase
            .from('main_dairy_payments')
            .select()
            .order('payment_date', ascending: false);
        payments = (fallback as List).map((json) => MainDairyPayment.fromJson(json)).toList();
      } catch (_) {
        payments = [];
      }
    }

    try {
      final dairies = await ref.read(mainDairyProvider.future);
      final dairyMap = {for (var d in dairies) d.id: d};
      return payments.map((p) {
        if (p.dairyName == null || p.dairyName!.isEmpty || p.dairyNo == null) {
          final d = dairyMap[p.mainDairyId];
          if (d != null) {
            return MainDairyPayment(
              id: p.id,
              mainDairyId: p.mainDairyId,
              paymentDate: p.paymentDate,
              amount: p.amount,
              paymentMode: p.paymentMode,
              referenceNo: p.referenceNo,
              remarks: p.remarks,
              dairyName: d.name,
              dairyNo: d.dairyNo,
            );
          }
        }
        return p;
      }).toList();
    } catch (_) {
      return payments;
    }
  }

  Future<void> addPayment({
    required String mainDairyId,
    required double amount,
    required String paymentMode,
    required String paymentDate,
    String? referenceNo,
    String? remarks,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('main_dairy_payments').insert({
        'main_dairy_id': mainDairyId,
        'amount': amount,
        'payment_mode': paymentMode,
        'payment_date': paymentDate,
        'reference_no': referenceNo,
        'remarks': remarks,
      });

      // Update current_balance on main_dairies table (subtract payment from receivable balance)
      try {
        final dList = await supabase.from('main_dairies').select('current_balance').eq('id', mainDairyId);
        if (dList.isNotEmpty) {
          final cur = (dList[0]['current_balance'] ?? 0).toDouble();
          await supabase.from('main_dairies').update({
            'current_balance': cur - amount,
          }).eq('id', mainDairyId);
        }
      } catch (_) {}

      ref.invalidate(mainDairyProvider);
      state = await AsyncValue.guard(() => _fetchPayments());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updatePayment({
    required String id,
    required String mainDairyId,
    required double oldAmount,
    required double newAmount,
    required String paymentMode,
    required String paymentDate,
    String? referenceNo,
    String? remarks,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('main_dairy_payments').update({
        'main_dairy_id': mainDairyId,
        'amount': newAmount,
        'payment_mode': paymentMode,
        'payment_date': paymentDate,
        'reference_no': referenceNo,
        'remarks': remarks,
      }).eq('id', id);

      // Adjust current_balance
      final diff = newAmount - oldAmount;
      if (diff != 0) {
        try {
          final dList = await supabase.from('main_dairies').select('current_balance').eq('id', mainDairyId);
          if (dList.isNotEmpty) {
            final cur = (dList[0]['current_balance'] ?? 0).toDouble();
            await supabase.from('main_dairies').update({
              'current_balance': cur - diff,
            }).eq('id', mainDairyId);
          }
        } catch (_) {}
      }

      ref.invalidate(mainDairyProvider);
      state = await AsyncValue.guard(() => _fetchPayments());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deletePayment(String id, String mainDairyId, double amount) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('main_dairy_payments').delete().eq('id', id);

      // Restore balance on main_dairies
      try {
        final dList = await supabase.from('main_dairies').select('current_balance').eq('id', mainDairyId);
        if (dList.isNotEmpty) {
          final cur = (dList[0]['current_balance'] ?? 0).toDouble();
          await supabase.from('main_dairies').update({
            'current_balance': cur + amount,
          }).eq('id', mainDairyId);
        }
      } catch (_) {}

      ref.invalidate(mainDairyProvider);
      state = await AsyncValue.guard(() => _fetchPayments());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final mainDairyPaymentProvider = AsyncNotifierProvider<MainDairyPaymentNotifier, List<MainDairyPayment>>(() {
  return MainDairyPaymentNotifier();
});
