import 'dart:convert';

enum SubscriptionStatus {
  active,
  expired,
  none,
  checking,
  cancelled,
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationDays;
  final String billingCycle;
  final String? badge;
  final List<String> features;
  final bool isActive;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.durationDays = 365,
    this.billingCycle = 'Year',
    this.badge,
    required this.features,
    this.isActive = true,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    List<String> parsedFeatures = [];
    if (json['features'] != null) {
      if (json['features'] is List) {
        parsedFeatures = List<String>.from(json['features'].map((e) => e.toString()));
      } else if (json['features'] is String) {
        try {
          final decoded = jsonDecode(json['features']);
          if (decoded is List) {
            parsedFeatures = List<String>.from(decoded.map((e) => e.toString()));
          }
        } catch (_) {}
      }
    }

    return SubscriptionPlan(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 365,
      billingCycle: json['billing_cycle']?.toString() ?? 'Year',
      badge: json['badge']?.toString(),
      features: parsedFeatures,
      isActive: json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'duration_days': durationDays,
      'billing_cycle': billingCycle,
      'badge': badge,
      'features': features,
      'is_active': isActive,
    };
  }

  // Fallback default plans matching your exact specifications
  static List<SubscriptionPlan> get defaultPlans => [
    const SubscriptionPlan(
      id: 'basic',
      name: 'Basic Plan',
      description: 'Essential tools for small local dairies starting milk collection and farmer records.',
      price: 999.0,
      durationDays: 365,
      billingCycle: 'Year',
      features: [
        '1 Dairy',
        'Up to 5 Farmers',
        'Milk Collection',
        'Payment Management',
        'Basic Reports',
      ],
    ),
    const SubscriptionPlan(
      id: 'premium',
      name: 'Premium Plan',
      description: 'Most popular choice for growing dairies needing complete analytics, bonuses, and reports.',
      price: 2499.0,
      durationDays: 365,
      billingCycle: 'Year',
      badge: 'MOST POPULAR',
      features: [
        'Unlimited Farmers',
        'Milk Collection',
        'Payment Management',
        'Bonus Module',
        'Bank Management',
        'Advanced Reports',
        'PDF Reports & More',
        'Dashboard Analytics',
        'Animal Management',
      ],
    ),
    const SubscriptionPlan(
      id: 'enterprise',
      name: 'Enterprise Plan',
      description: 'Comprehensive multi-dairy, multi-branch solution with advanced analytics and priority support.',
      price: 4999.0,
      durationDays: 365,
      billingCycle: 'Year',
      features: [
        'Multiple Dairies / Branches',
        'Unlimited Farmers',
        'Advanced Analytics',
        'Advanced Reports & Export',
        'Priority 24/7 Support',
      ],
    ),
  ];
}

class UserSubscription {
  final String id;
  final String subscriptionId;
  final String userId;
  final String planId;
  final String planName;
  final double amount;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'ACTIVE', 'EXPIRED', 'CANCELLED'
  final bool autoRenewal;

  const UserSubscription({
    required this.id,
    required this.subscriptionId,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.autoRenewal = true,
  });

  bool get isActive {
    if (status.toUpperCase() != 'ACTIVE') return false;
    return endDate.isAfter(DateTime.now());
  }

  int get daysRemaining {
    final diff = endDate.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  int get daysOverdue {
    if (isActive) return 0;
    return DateTime.now().difference(endDate).inDays;
  }

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id']?.toString() ?? '',
      subscriptionId: json['subscription_id']?.toString() ?? 'DM-${DateTime.now().year}0101-001',
      userId: json['user_id']?.toString() ?? '',
      planId: json['plan_id']?.toString() ?? 'premium',
      planName: json['plan_name']?.toString() ?? 'Premium Plan',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'].toString()) ?? DateTime.now().add(const Duration(days: 365))
          : DateTime.now().add(const Duration(days: 365)),
      status: (json['status']?.toString() ?? 'ACTIVE').toUpperCase(),
      autoRenewal: json['auto_renewal'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subscription_id': subscriptionId,
      'user_id': userId,
      'plan_id': planId,
      'plan_name': planName,
      'amount': amount,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': status,
      'auto_renewal': autoRenewal,
    };
  }
}

class PaymentRecord {
  final String id;
  final String transactionId;
  final String userId;
  final String subscriptionId;
  final String planId;
  final String planName;
  final double amount;
  final String paymentMethod;
  final String paymentStatus; // 'SUCCESS', 'PENDING', 'FAILED'
  final String? invoiceNo;
  final DateTime paymentDate;

  const PaymentRecord({
    required this.id,
    required this.transactionId,
    required this.userId,
    required this.subscriptionId,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.paymentMethod,
    this.paymentStatus = 'SUCCESS',
    this.invoiceNo,
    required this.paymentDate,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id']?.toString() ?? '',
      transactionId: json['transaction_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      subscriptionId: json['subscription_id']?.toString() ?? '',
      planId: json['plan_id']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? 'UPI',
      paymentStatus: (json['payment_status']?.toString() ?? 'SUCCESS').toUpperCase(),
      invoiceNo: json['invoice_no']?.toString(),
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'user_id': userId,
      'subscription_id': subscriptionId,
      'plan_id': planId,
      'plan_name': planName,
      'amount': amount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'invoice_no': invoiceNo,
      'payment_date': paymentDate.toIso8601String(),
    };
  }
}
