import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription_model.dart';
export '../models/subscription_model.dart';
import 'app_config.dart';
import '../main.dart' as app_main;

class SubscriptionState {
  final SubscriptionStatus status;
  final UserSubscription? currentSubscription;
  final List<SubscriptionPlan> availablePlans;
  final List<PaymentRecord> paymentHistory;
  final String? message;
  final DateTime? lastChecked;

  const SubscriptionState({
    required this.status,
    this.currentSubscription,
    this.availablePlans = const [],
    this.paymentHistory = const [],
    this.message,
    this.lastChecked,
  });

  bool get isActive => status == SubscriptionStatus.active && (currentSubscription?.isActive ?? false);
  bool get isExpired => status == SubscriptionStatus.expired;
  bool get hasNoSubscription => status == SubscriptionStatus.none;

  int get daysRemaining => currentSubscription?.daysRemaining ?? 0;
  int get daysOverdue => currentSubscription?.daysOverdue ?? 0;

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    UserSubscription? currentSubscription,
    List<SubscriptionPlan>? availablePlans,
    List<PaymentRecord>? paymentHistory,
    String? message,
    DateTime? lastChecked,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      currentSubscription: currentSubscription ?? this.currentSubscription,
      availablePlans: availablePlans ?? this.availablePlans,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      message: message ?? this.message,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() {
    return const SubscriptionState(
      status: SubscriptionStatus.checking,
      availablePlans: [],
    );
  }

  /// Central method to verify subscription status from Supabase
  Future<SubscriptionStatus> checkSubscription({bool forceRefresh = false}) async {
    // 1. Offline Standalone Edition bypass
    if (AppConfig.isOfflineMode && !AppConfig.isHybridMode) {
      final offlineSub = UserSubscription(
        id: 'offline-license',
        subscriptionId: 'DM-OFFLINE-LIFETIME',
        userId: 'offline-admin',
        planId: 'enterprise',
        planName: 'Enterprise Standalone',
        amount: 0.0,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now().add(const Duration(days: 3650)),
        status: 'ACTIVE',
      );
      state = state.copyWith(
        status: SubscriptionStatus.active,
        currentSubscription: offlineSub,
        availablePlans: SubscriptionPlan.defaultPlans,
        lastChecked: DateTime.now(),
      );
      return SubscriptionStatus.active;
    }

    state = state.copyWith(status: SubscriptionStatus.checking);

    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;

    if (currentUser == null) {
      state = state.copyWith(
        status: SubscriptionStatus.none,
        currentSubscription: null,
        availablePlans: SubscriptionPlan.defaultPlans,
      );
      return SubscriptionStatus.none;
    }

    final userId = currentUser.id;

    try {
      // 1. Fetch available plans in parallel or fallback to defaults
      List<SubscriptionPlan> plans = SubscriptionPlan.defaultPlans;
      try {
        final plansRes = await client
            .from('subscription_plans')
            .select()
            .eq('is_active', true)
            .order('price', ascending: true)
            .timeout(const Duration(seconds: 6));
        
        if (plansRes.isNotEmpty) {
          plans = (plansRes as List).map((p) => SubscriptionPlan.fromJson(p)).toList();
        }
      } catch (pe) {
        debugPrint('Plans query note (using defaults): $pe');
      }

      // 2. Check if admin approved the account in public.users table
      bool isUserActive = false;
      try {
        final userRes = await client
            .from('users')
            .select('status')
            .eq('id', userId)
            .maybeSingle()
            .timeout(const Duration(seconds: 8));
        isUserActive = userRes != null && userRes['status']?.toString().trim().toLowerCase() == 'active';
      } catch (ue) {
        debugPrint('Users table status check note: $ue');
      }

      // 3. Fetch latest subscription for current user
      Map<String, dynamic>? subRes;
      try {
        subRes = await client
            .from('subscriptions')
            .select()
            .eq('user_id', userId)
            .order('end_date', ascending: false)
            .limit(1)
            .maybeSingle()
            .timeout(const Duration(seconds: 8));
      } catch (se) {
        debugPrint('Subscriptions table query note: $se');
      }

      // CASE A: Account is marked 'active' in public.users (Admin approved or subscription paid)
      // The subscription belongs to the ACCOUNT and unlocks all devices (Android, Windows, etc.)
      if (isUserActive) {
        UserSubscription? activeSub;
        if (subRes != null) {
          final sub = UserSubscription.fromJson(subRes);
          if (sub.isPending || !sub.isActive) {
            // Auto-update pending or expired row to ACTIVE for 1 year
            try {
              await client.from('subscriptions').update({
                'status': 'ACTIVE',
                'start_date': DateTime.now().toIso8601String(),
                'end_date': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', sub.id).timeout(const Duration(seconds: 5));
            } catch (_) {}
          }
          activeSub = UserSubscription(
            id: sub.id,
            subscriptionId: sub.subscriptionId,
            userId: sub.userId,
            planId: sub.planId,
            planName: sub.planName,
            amount: sub.amount,
            startDate: DateTime.now(),
            endDate: DateTime.now().add(const Duration(days: 365)),
            status: 'ACTIVE',
            autoRenewal: true,
          );
        } else {
          // No row in subscriptions table yet; auto-create 1-year active license for this active account
          final now = DateTime.now();
          final endDate = now.add(const Duration(days: 365));
          final randomSuffix = (Random().nextInt(900) + 100).toString();
          final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
          final subId = 'DM-$dateStr-$randomSuffix';

          final newSubData = {
            'subscription_id': subId,
            'user_id': userId,
            'plan_id': 'premium',
            'plan_name': 'Premium Plan',
            'amount': 2499.0,
            'start_date': now.toIso8601String(),
            'end_date': endDate.toIso8601String(),
            'status': 'ACTIVE',
            'auto_renewal': true,
            'updated_at': now.toIso8601String(),
          };

          try {
            final inserted = await client
                .from('subscriptions')
                .insert(newSubData)
                .select()
                .maybeSingle()
                .timeout(const Duration(seconds: 5));
            if (inserted != null) {
              activeSub = UserSubscription.fromJson(inserted);
            }
          } catch (e) {
            debugPrint('Auto-insert subscription record note: $e');
          }

          activeSub ??= UserSubscription(
            id: subId,
            subscriptionId: subId,
            userId: userId,
            planId: 'premium',
            planName: 'Premium Plan',
            amount: 2499.0,
            startDate: now,
            endDate: endDate,
            status: 'ACTIVE',
            autoRenewal: true,
          );
        }

        final cacheKey = AppConfig.prefKey('cached_sub_status_$userId');
        await app_main.prefs.setString(cacheKey, 'ACTIVE');

        state = state.copyWith(
          status: SubscriptionStatus.active,
          currentSubscription: activeSub,
          availablePlans: plans,
          lastChecked: DateTime.now(),
          message: null,
        );
        return SubscriptionStatus.active;
      }

      // CASE B: User is not marked active in public.users yet
      if (subRes == null) {
        // No subscription found for this user
        final cacheKey = AppConfig.prefKey('cached_sub_status_$userId');
        await app_main.prefs.setString(cacheKey, 'NONE');

        state = state.copyWith(
          status: SubscriptionStatus.none,
          currentSubscription: null,
          availablePlans: plans,
          lastChecked: DateTime.now(),
          message: 'No active subscription found. Please subscribe to continue.',
        );
        return SubscriptionStatus.none;
      }

      final sub = UserSubscription.fromJson(subRes);

      if (sub.isPending) {
        final cacheKey = AppConfig.prefKey('cached_sub_status_$userId');
        await app_main.prefs.setString(cacheKey, 'PENDING');

        state = state.copyWith(
          status: SubscriptionStatus.pending,
          currentSubscription: sub,
          availablePlans: plans,
          lastChecked: DateTime.now(),
          message: 'Payment verification pending admin approval.',
        );
        return SubscriptionStatus.pending;
      }

      // Verify expiration
      if (sub.isActive) {
        // Sync public.users status to active as well
        try {
          await client.from('users').upsert({
            'id': userId,
            'email': currentUser.email ?? '',
            'status': 'active',
          }).timeout(const Duration(seconds: 4));
        } catch (_) {}

        final cacheKey = AppConfig.prefKey('cached_sub_status_$userId');
        await app_main.prefs.setString(cacheKey, 'ACTIVE');

        state = state.copyWith(
          status: SubscriptionStatus.active,
          currentSubscription: sub,
          availablePlans: plans,
          lastChecked: DateTime.now(),
          message: null,
        );
        return SubscriptionStatus.active;
      } else {
        // Expired
        final cacheKey = AppConfig.prefKey('cached_sub_status_$userId');
        await app_main.prefs.setString(cacheKey, 'EXPIRED');

        state = state.copyWith(
          status: SubscriptionStatus.expired,
          currentSubscription: sub,
          availablePlans: plans,
          lastChecked: DateTime.now(),
          message: 'Your subscription has expired. Please renew your plan.',
        );
        return SubscriptionStatus.expired;
      }
    } catch (e) {
      debugPrint('Subscription verification note: $e');

      // Check cached status on network failure
      final cacheKey = AppConfig.prefKey('cached_sub_status_$userId');
      final cached = app_main.prefs.getString(cacheKey);

      if (cached == 'ACTIVE') {
        state = state.copyWith(
          status: SubscriptionStatus.active,
          availablePlans: SubscriptionPlan.defaultPlans,
          lastChecked: DateTime.now(),
        );
        return SubscriptionStatus.active;
      } else if (cached == 'PENDING') {
        state = state.copyWith(
          status: SubscriptionStatus.pending,
          availablePlans: SubscriptionPlan.defaultPlans,
          lastChecked: DateTime.now(),
        );
        return SubscriptionStatus.pending;
      } else if (cached == 'EXPIRED') {
        state = state.copyWith(
          status: SubscriptionStatus.expired,
          availablePlans: SubscriptionPlan.defaultPlans,
          lastChecked: DateTime.now(),
        );
        return SubscriptionStatus.expired;
      }

      // Fallback check of account status cache
      final acctStatusPref = app_main.prefs.getString(AppConfig.prefKey('account_status_$userId'));
      if (acctStatusPref == 'active') {
        state = state.copyWith(
          status: SubscriptionStatus.active,
          availablePlans: SubscriptionPlan.defaultPlans,
          lastChecked: DateTime.now(),
        );
        return SubscriptionStatus.active;
      }

      state = state.copyWith(
        status: SubscriptionStatus.none,
        availablePlans: SubscriptionPlan.defaultPlans,
        message: 'Could not connect to subscription service. Please verify your internet connection.',
      );
      return SubscriptionStatus.none;
    }
  }

  /// Activate a new subscription after successful payment
  Future<UserSubscription> activateSubscription({
    required SubscriptionPlan plan,
    required String paymentMethod,
    required String transactionId,
  }) async {
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User is not authenticated');
    }

    final userId = currentUser.id;
    final now = DateTime.now();
    final endDate = now.add(Duration(days: plan.durationDays));

    // Generate readable subscription ID: e.g. DM-20260929-784
    final randomSuffix = (Random().nextInt(900) + 100).toString();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final subscriptionId = 'DM-$dateStr-$randomSuffix';
    final invoiceNo = 'INV-$dateStr-$randomSuffix';

    // 1. Record payment in public.subscription_payments table
    try {
      await client.from('subscription_payments').insert({
        'transaction_id': transactionId,
        'user_id': userId,
        'subscription_id': subscriptionId,
        'plan_id': plan.id,
        'plan_name': plan.name,
        'amount': plan.price,
        'payment_method': paymentMethod,
        'payment_status': 'SUCCESS',
        'invoice_no': invoiceNo,
        'payment_date': now.toIso8601String(),
      });
    } catch (payErr) {
      debugPrint('Subscription payments table insert note: $payErr');
    }

    // 2. Insert or update in public.subscriptions table
    final subData = {
      'subscription_id': subscriptionId,
      'user_id': userId,
      'plan_id': plan.id,
      'plan_name': plan.name,
      'amount': plan.price,
      'start_date': now.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': 'ACTIVE',
      'auto_renewal': true,
      'updated_at': now.toIso8601String(),
    };

    final inserted = await client
        .from('subscriptions')
        .insert(subData)
        .select()
        .single();

    final userSub = UserSubscription.fromJson(inserted);

    // 3. Mark public.users status as 'active'
    try {
      await client.from('users').upsert({
        'id': userId,
        'email': currentUser.email ?? '',
        'status': 'active',
      });
    } catch (_) {}

    // 4. Update local cache
    final cacheKey = AppConfig.prefKey('cached_sub_status_$userId');
    await app_main.prefs.setString(cacheKey, 'ACTIVE');

    state = state.copyWith(
      status: SubscriptionStatus.active,
      currentSubscription: userSub,
      lastChecked: DateTime.now(),
      message: null,
    );

    return userSub;
  }

  /// Submit UPI / QR payment for admin approval
  Future<UserSubscription> submitPaymentForApproval({
    required SubscriptionPlan plan,
    required String paymentMethod,
    required String transactionId,
  }) async {
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User is not authenticated');
    }

    final userId = currentUser.id;
    final now = DateTime.now();
    final endDate = now.add(Duration(days: plan.durationDays));

    final randomSuffix = (Random().nextInt(900) + 100).toString();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final subscriptionId = 'DM-$dateStr-$randomSuffix';
    final invoiceNo = 'INV-$dateStr-$randomSuffix';

    // 1. Record payment in public.subscription_payments table as PENDING
    try {
      await client.from('subscription_payments').insert({
        'transaction_id': transactionId,
        'user_id': userId,
        'subscription_id': subscriptionId,
        'plan_id': plan.id,
        'plan_name': plan.name,
        'amount': plan.price,
        'payment_method': paymentMethod,
        'payment_status': 'PENDING',
        'invoice_no': invoiceNo,
        'payment_date': now.toIso8601String(),
      });
    } catch (payErr) {
      debugPrint('Subscription payments table insert note: $payErr');
    }

    // 2. Insert into public.subscriptions table as PENDING
    final subData = {
      'subscription_id': subscriptionId,
      'user_id': userId,
      'plan_id': plan.id,
      'plan_name': plan.name,
      'amount': plan.price,
      'start_date': now.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': 'PENDING',
      'auto_renewal': true,
      'updated_at': now.toIso8601String(),
    };

    final inserted = await client
        .from('subscriptions')
        .insert(subData)
        .select()
        .single();

    final userSub = UserSubscription.fromJson(inserted);

    // 3. Mark public.users status as 'pending'
    try {
      await client.from('users').upsert({
        'id': userId,
        'email': currentUser.email ?? '',
        'status': 'pending',
      });
    } catch (_) {}

    // 4. Update local cache
    final cacheKey = AppConfig.prefKey('cached_sub_status_$userId');
    await app_main.prefs.setString(cacheKey, 'PENDING');

    state = state.copyWith(
      status: SubscriptionStatus.pending,
      currentSubscription: userSub,
      lastChecked: DateTime.now(),
      message: 'Payment submitted for admin approval',
    );

    return userSub;
  }

  /// Fetch payment history for current user
  Future<List<PaymentRecord>> fetchPaymentHistory() async {
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;
    if (currentUser == null) return [];

    try {
      final res = await client
          .from('subscription_payments')
          .select()
          .eq('user_id', currentUser.id)
          .order('payment_date', ascending: false)
          .limit(20);

      final list = (res as List).map((p) => PaymentRecord.fromJson(p)).toList();
      state = state.copyWith(paymentHistory: list);
      return list;
    } catch (e) {
      debugPrint('Payment history fetch note: $e');
      return state.paymentHistory;
    }
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(() {
  return SubscriptionNotifier();
});
