import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_management/models/flutter_models.dart';

void main() {
  group('StockTransaction & Party Name Tests', () {
    test('StockTransaction.fromJson correctly parses party_name', () {
      final json = {
        'id': 'stk_1',
        'transaction_date': '2026-09-11',
        'product_id': 'prod_1',
        'trans_type': 'OUT',
        'quantity': 2.0,
        'reference_id': 'sale_1',
        'reference_type': 'Sale',
        'product_name': 'Extra Milk 50kg',
        'party_name': 'Farmer: Ramesh Patil',
      };

      final tx = StockTransaction.fromJson(json);
      expect(tx.id, 'stk_1');
      expect(tx.productName, 'Extra Milk 50kg');
      expect(tx.partyName, 'Farmer: Ramesh Patil');
      expect(tx.transType, 'OUT');
      expect(tx.quantity, 2.0);
    });

    test('StockTransaction.fromJson handles null or adjustment party_name', () {
      final json = {
        'id': 'stk_2',
        'transaction_date': '2026-09-11',
        'product_id': 'prod_2',
        'trans_type': 'IN',
        'quantity': 10.0,
        'reference_id': null,
        'reference_type': 'Adjustment',
        'products': {'name': 'mankind 50kg'},
        'party_name': null,
      };

      final tx = StockTransaction.fromJson(json);
      expect(tx.productName, 'mankind 50kg');
      expect(tx.partyName, isNull);
    });
  });
}
