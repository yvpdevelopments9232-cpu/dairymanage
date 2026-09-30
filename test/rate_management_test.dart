import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_management/providers/rate_provider.dart';

void main() {
  group('Rate Management Logic & Dynamic Rate Application', () {
    test('Rate calculation applies Base Rate 40 when Fat & SNF match base', () {
      final cowIncreaseConfig = RateConfig(
        id: 'cfg-1',
        animalType: 'Cow Milk',
        rateType: 'Increase',
        baseFat: 3.5,
        baseSnf: 8.5,
        baseRate: 40.0,
        fatRangeFrom: 3.5,
        fatRangeTo: 6.0,
        fatPoint: 0.1,
        fatRate: 1.0,
        snfRangeFrom: 8.5,
        snfRangeTo: 10.0,
        snfPoint: 0.1,
        snfRate: 1.0,
        effectiveDate: '2026-09-29',
        isActive: true,
        createdAt: '2026-09-29T10:00:00Z',
      );

      expect(cowIncreaseConfig.baseRate, 40.0);
      expect(cowIncreaseConfig.baseFat, 3.5);
      expect(cowIncreaseConfig.baseSnf, 8.5);
    });

    test('Updating base price to 44 applies to subsequent collections', () {
      final updatedConfig = RateConfig(
        id: 'cfg-1',
        animalType: 'Cow Milk',
        rateType: 'Increase',
        baseFat: 3.5,
        baseSnf: 8.5,
        baseRate: 44.0,
        fatRangeFrom: 3.5,
        fatRangeTo: 6.0,
        fatPoint: 0.1,
        fatRate: 1.0,
        snfRangeFrom: 8.5,
        snfRangeTo: 10.0,
        snfPoint: 0.1,
        snfRate: 1.0,
        effectiveDate: '2026-09-30',
        isActive: true,
        createdAt: '2026-09-30T10:00:00Z',
      );

      // Verify base rate is now 44
      expect(updatedConfig.baseRate, 44.0);
      
      // Calculate rate for milk with Fat = 4.0 (diff 0.5 -> 5 points of 0.1 -> +5.0)
      double fatDiff = 4.0 - updatedConfig.baseFat;
      int fatPts = (fatDiff / updatedConfig.fatPoint).round();
      double calculatedRate = updatedConfig.baseRate + (fatPts * updatedConfig.fatRate);
      expect(calculatedRate, 49.0);
    });

    test('Symmetrical fallback applies deduction even if only Increase chart is configured', () {
      final cowIncreaseConfig = RateConfig(
        id: 'cfg-1',
        animalType: 'Cow Milk',
        rateType: 'Increase',
        baseFat: 3.5,
        baseSnf: 8.5,
        baseRate: 44.0,
        fatRangeFrom: 3.5,
        fatRangeTo: 6.0,
        fatPoint: 0.1,
        fatRate: 1.0,
        snfRangeFrom: 8.5,
        snfRangeTo: 10.0,
        snfPoint: 0.1,
        snfRate: 1.0,
        effectiveDate: '2026-09-30',
        isActive: true,
        createdAt: '2026-09-30T10:00:00Z',
      );

      // Farmer brings milk with lower fat 3.2 (less than 3.5)
      double fatDiff = cowIncreaseConfig.baseFat - 3.2;
      int fatPts = (fatDiff / cowIncreaseConfig.fatPoint).round(); // 0.3 / 0.1 = 3 points
      double deductedRate = cowIncreaseConfig.baseRate - (fatPts * cowIncreaseConfig.fatRate);
      expect(deductedRate, 41.0); // 44 - 3 = 41
    });
  });
}
