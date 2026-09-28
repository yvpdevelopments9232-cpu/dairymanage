import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_management/models/flutter_models.dart';

void main() {
  group('Bonus Module Unit Tests', () {
    test('BonusSettings serialization and defaults', () {
      final settings = BonusSettings(id: 'default_settings', cowRate: 0.40, buffaloRate: 0.50);
      expect(settings.cowRate, 0.40);
      expect(settings.buffaloRate, 0.50);

      final json = settings.toJson();
      final fromJson = BonusSettings.fromJson(json);
      expect(fromJson.cowRate, 0.40);
      expect(fromJson.buffaloRate, 0.50);
    });

    test('Bonus calculation formula for Cow, Buffalo, and Mixed milk collections', () {
      const cowRate = 0.40;
      const buffaloRate = 0.50;

      // Farmer 1: Ramesh Patil - 850 L Buffalo Milk
      final buffaloQty = 850.0;
      final buffaloBonus = buffaloQty * buffaloRate;
      expect(buffaloBonus, 425.00);

      // Farmer 2: Suresh More - 620 L Cow Milk
      final cowQty = 620.0;
      final cowBonus = cowQty * cowRate;
      expect(cowBonus, 248.00);

      // Mixed collection
      final mixedCow = 300.0;
      final mixedBuffalo = 400.0;
      final totalMixedBonus = (mixedCow * cowRate) + (mixedBuffalo * buffaloRate);
      expect(totalMixedBonus, (300 * 0.40) + (400 * 0.50)); // 120 + 200 = 320
    });

    test('Bonus Transaction payment and remaining balance deduction', () {
      final summary = BonusFarmerSummary(
        farmerId: 'f1',
        farmerName: 'Ramesh Patil',
        farmerNo: 'F-00125',
        animalType: 'Buffalo',
        cowMilk: 0.0,
        buffaloMilk: 850.0,
        totalMilk: 850.0,
        cowRate: 0.40,
        buffaloRate: 0.50,
        cowBonus: 0.0,
        buffaloBonus: 425.0,
        totalBonus: 425.0,
        paidAmount: 200.0,
        remainingBonus: 225.0,
        status: 'Partial',
      );

      expect(summary.totalBonus, 425.0);
      expect(summary.paidAmount, 200.0);
      expect(summary.remainingBonus, 225.0);

      // Process payment of 225.0
      final payAmount = 225.0;
      final newPaid = summary.paidAmount + payAmount;
      final newRemaining = summary.totalBonus - newPaid;

      expect(newPaid, 425.0);
      expect(newRemaining, 0.0);

      final txn = BonusTransaction(
        id: 'txn_001',
        farmerId: summary.farmerId,
        farmerName: summary.farmerName,
        farmerNo: summary.farmerNo,
        animalType: summary.animalType,
        fromDate: '2026-09-01',
        toDate: '2026-09-30',
        milkQuantity: summary.totalMilk,
        bonusRate: summary.displayRate,
        totalBonus: summary.totalBonus,
        previousPaid: summary.paidAmount,
        paidAmount: payAmount,
        totalPaid: newPaid,
        remainingBonus: newRemaining,
        paymentDate: '2026-09-15',
        paymentMode: 'Bank Transfer',
        transactionNumber: 'TXN20260915001',
        remarks: 'Bonus Payment',
      );

      final json = txn.toJson();
      final fromJson = BonusTransaction.fromJson(json);
      expect(fromJson.paidAmount, 225.0);
      expect(fromJson.totalPaid, 425.0);
      expect(fromJson.remainingBonus, 0.0);
      expect(fromJson.paymentMode, 'Bank Transfer');
      expect(fromJson.transactionNumber, 'TXN20260915001');
    });
  });
}
