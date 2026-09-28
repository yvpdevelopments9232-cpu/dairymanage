import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';
import '../main.dart' as app_main;

enum AccountStatus {
  active,
  pending,
  networkError,
  checking,
}

class AccountStatusState {
  final AccountStatus status;
  final String? message;
  final DateTime? lastChecked;

  const AccountStatusState({
    required this.status,
    this.message,
    this.lastChecked,
  });

  AccountStatusState copyWith({
    AccountStatus? status,
    String? message,
    DateTime? lastChecked,
  }) {
    return AccountStatusState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

class AccountStatusNotifier extends Notifier<AccountStatusState> {
  static const String contactPhone = '6361782144';
  static const String developerName = 'Yu_Vi Development';

  @override
  AccountStatusState build() {
    return const AccountStatusState(status: AccountStatus.active);
  }

  Future<AccountStatus> checkStatus({bool forceRefresh = false}) async {
    // 1. Offline edition never requires online account check
    if (AppConfig.isOfflineMode && !AppConfig.isHybridMode) {
      state = state.copyWith(status: AccountStatus.active);
      return AccountStatus.active;
    }

    state = state.copyWith(status: AccountStatus.checking);

    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;

    if (currentUser == null) {
      state = state.copyWith(status: AccountStatus.active);
      return AccountStatus.active;
    }

    final userId = currentUser.id;

    try {
      // Query public.users status with timeout
      final res = await client
          .from('users')
          .select('status')
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      String statusStr = 'active';

      if (res != null && res['status'] != null) {
        statusStr = res['status'].toString().trim().toLowerCase();
      } else {
        // Record does not exist yet; auto-insert initial active row
        try {
          await client.from('users').upsert({
            'id': userId,
            'email': currentUser.email ?? '',
            'status': 'active',
          }).timeout(const Duration(seconds: 5));
        } catch (_) {}
      }

      final prefKey = AppConfig.prefKey('account_status_$userId');
      await app_main.prefs.setString(prefKey, statusStr);

      if (statusStr == 'pending') {
        state = state.copyWith(
          status: AccountStatus.pending,
          lastChecked: DateTime.now(),
          message: 'Your application account is currently pending.',
        );
        return AccountStatus.pending;
      } else {
        state = state.copyWith(
          status: AccountStatus.active,
          lastChecked: DateTime.now(),
          message: null,
        );
        return AccountStatus.active;
      }
    } catch (e) {
      debugPrint('Account status check note: $e');

      // Check cached status on network failure
      final prefKey = AppConfig.prefKey('account_status_$userId');
      final cached = app_main.prefs.getString(prefKey);

      if (cached == 'pending') {
        state = state.copyWith(
          status: AccountStatus.pending,
          lastChecked: DateTime.now(),
          message: 'Your application account is currently pending.',
        );
        return AccountStatus.pending;
      }

      // In hybrid mode, allow existing active operations while offline
      if (AppConfig.isHybridMode) {
        state = state.copyWith(status: AccountStatus.active);
        return AccountStatus.active;
      }

      state = state.copyWith(
        status: AccountStatus.networkError,
        message: 'Unable to verify your account right now. Please check your internet connection.',
      );
      return AccountStatus.networkError;
    }
  }

  void setPendingManually() {
    state = state.copyWith(
      status: AccountStatus.pending,
      message: 'Your application account is currently pending.',
    );
  }

  void setActiveManually() {
    state = state.copyWith(
      status: AccountStatus.active,
      message: null,
    );
  }
}

final accountStatusProvider =
    NotifierProvider<AccountStatusNotifier, AccountStatusState>(() {
  return AccountStatusNotifier();
});
