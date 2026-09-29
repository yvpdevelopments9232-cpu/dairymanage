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
            .timeout(const Duration(seconds: 5));
        
        if (plansRes.isNotEmpty) {
          plans = (plansRes as List).map((p) => SubscriptionPlan.fromJson(p)).toList();
        }
      } catch (pe) {
        debugPrint('Plans query note (using defaults): $pe');
      }

      // 2. Fetch latest subscription for current user
      final subRes = await client
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .order('end_date', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 7));

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

      // Verify expiration
      if (sub.isActive) {
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
      } else if (cached == 'EXPIRED') {
        state = state.copyWith(
          status: SubscriptionStatus.expired,
          availablePlans: SubscriptionPlan.defaultPlans,
          lastChecked: DateTime.now(),
        );
        return SubscriptionStatus.expired;
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

    // 3. Update local cache
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
