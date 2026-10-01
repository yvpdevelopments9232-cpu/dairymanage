import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flutter_models.dart';
import '../services/app_config.dart';
import '../services/offline_db_helper.dart';
import 'auth_provider.dart';
import 'product_provider.dart';

class StockNotifier extends AsyncNotifier<List<StockTransaction>> {
  @override
  Future<List<StockTransaction>> build() async {
    return _fetchTransactions();
  }

  Future<List<StockTransaction>> _fetchTransactions() async {
    if (AppConfig.isOfflineMode) {
      try {
        final db = await OfflineDbHelper.instance.database;
        final rows = await db.rawQuery('''
          SELECT 
            st.*,
            p.name AS product_name,
            CASE 
              WHEN (st.reference_type = 'Sale' OR st.trans_type = 'Sale' OR st.trans_type = 'OUT') AND f.name IS NOT NULL THEN 'Farmer: ' || f.name
              WHEN (st.reference_type = 'Sale' OR st.trans_type = 'Sale' OR st.trans_type = 'OUT') AND c.name IS NOT NULL THEN 'Customer: ' || c.name
              WHEN (st.reference_type = 'Purchase' OR st.trans_type = 'Purchase' OR st.trans_type = 'IN') AND sup.name IS NOT NULL THEN 'Dealer: ' || sup.name
              WHEN st.reference_type = 'Adjustment' THEN 'Manual Adjustment'
              ELSE COALESCE(st.reference_type, '-')
            END AS party_name
          FROM stock_transactions st
          LEFT JOIN products p ON st.product_id = p.id
          LEFT JOIN sales s ON st.reference_id = s.id
          LEFT JOIN farmers f ON s.farmer_id = f.id
          LEFT JOIN customers c ON s.customer_id = c.id
          LEFT JOIN purchases pur ON st.reference_id = pur.id
          LEFT JOIN suppliers sup ON pur.supplier_id = sup.id
          ORDER BY st.transaction_date DESC, st.created_at DESC
          LIMIT 500
        ''');
        return rows.map((r) => StockTransaction.fromJson(r)).toList();
      } catch (e) {
        debugPrint('Offline stock transactions fetch note: $e');
      }
    }

    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase
        .from('stock_transactions')
        .select('*, products(name)')
        .order('transaction_date', ascending: false)
        .limit(500);

    final rawList = (response as List).map((j) => Map<String, dynamic>.from(j as Map)).toList();

    final saleIds = rawList
        .where((e) => (e['reference_type'] == 'Sale' || e['trans_type'] == 'Sale' || e['trans_type'] == 'OUT') && e['reference_id'] != null)
        .map((e) => e['reference_id'].toString())
        .toSet()
        .toList();

    final purchaseIds = rawList
        .where((e) => (e['reference_type'] == 'Purchase' || e['trans_type'] == 'Purchase' || e['trans_type'] == 'IN') && e['reference_id'] != null)
        .map((e) => e['reference_id'].toString())
        .toSet()
        .toList();

    Map<String, String> partyMap = {};

    if (saleIds.isNotEmpty) {
      try {
        final salesRes = await supabase
            .from('sales')
            .select('id, farmer_id, customer_id, farmers(name), customers(name)')
            .inFilter('id', saleIds);
        for (var s in salesRes as List) {
          final sId = s['id']?.toString();
          if (sId != null) {
            if (s['farmers']?['name'] != null) {
              partyMap[sId] = 'Farmer: ${s['farmers']['name']}';
            } else if (s['customers']?['name'] != null) {
              partyMap[sId] = 'Customer: ${s['customers']['name']}';
            }
          }
        }
      } catch (e) {
        debugPrint('Sales party lookup note: $e');
      }
    }

    if (purchaseIds.isNotEmpty) {
      try {
        final purRes = await supabase
            .from('purchases')
            .select('id, supplier_id, suppliers(name)')
            .inFilter('id', purchaseIds);
        for (var p in purRes as List) {
          final pId = p['id']?.toString();
          if (pId != null && p['suppliers']?['name'] != null) {
            partyMap[pId] = 'Dealer: ${p['suppliers']['name']}';
          }
        }
      } catch (e) {
        debugPrint('Purchases party lookup note: $e');
      }
    }

    for (var row in rawList) {
      final refId = row['reference_id']?.toString();
      if (refId != null && partyMap.containsKey(refId)) {
        row['party_name'] = partyMap[refId];
      } else if (row['reference_type'] == 'Adjustment') {
        row['party_name'] = 'Manual Adjustment';
      } else {
        row['party_name'] = row['reference_type'] ?? '-';
      }
    }

    return rawList.map((json) => StockTransaction.fromJson(json)).toList();
  }

  void refresh() {
    state = const AsyncValue.loading();
    ref.invalidateSelf();
  }

  /// Delete a stock transaction and reverse its impact on product current_stock
  Future<void> deleteTransaction(StockTransaction tx) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();

    try {
      // 1. Delete from stock_transactions
      await supabase.from('stock_transactions').delete().eq('id', tx.id);

      // 2. Adjust product's current_stock
      // If transaction was IN (added stock), deleting it means stock decreases (-quantity)
      // If transaction was OUT (subtracted stock), deleting it means stock increases (+quantity)
      final bool isIncoming = tx.transType.toUpperCase() == 'IN' || 
                              tx.transType.toLowerCase() == 'purchase' || 
                              tx.transType.toLowerCase() == 'opening';
      final double stockDelta = isIncoming ? -tx.quantity : tx.quantity;

      try {
        if (AppConfig.isOfflineMode) {
          final db = await OfflineDbHelper.instance.database;
          await db.rawUpdate(
            'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
            [stockDelta, tx.productId],
          );
        } else {
          final prodRes = await supabase.from('products').select('current_stock').eq('id', tx.productId).single();
          final currentStock = (prodRes['current_stock'] ?? 0).toDouble();
          await supabase.from('products').update({
            'current_stock': currentStock + stockDelta,
          }).eq('id', tx.productId);
        }
      } catch (_) {}

      // 3. Refresh providers
      ref.invalidate(productsProvider);
      state = await AsyncValue.guard(() => _fetchTransactions());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update an existing stock transaction and adjust product stock by difference
  Future<void> updateTransaction(
    StockTransaction tx, {
    required double newQuantity,
    required String newTransType,
    required String newDate,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();

    try {
      // 1. Calculate stock difference
      final bool wasIncoming = tx.transType.toUpperCase() == 'IN' || 
                               tx.transType.toLowerCase() == 'purchase' || 
                               tx.transType.toLowerCase() == 'opening';
      final double oldNet = wasIncoming ? tx.quantity : -tx.quantity;

      final bool isIncoming = newTransType.toUpperCase() == 'IN' || 
                              newTransType.toLowerCase() == 'purchase' || 
                              newTransType.toLowerCase() == 'opening';
      final double newNet = isIncoming ? newQuantity : -newQuantity;

      final double diff = newNet - oldNet;

      // 2. Update stock_transactions
      await supabase.from('stock_transactions').update({
        'quantity': newQuantity,
        'trans_type': newTransType,
        'transaction_date': newDate,
      }).eq('id', tx.id);

      // 3. Adjust product current_stock if diff != 0 atomically
      if (diff != 0) {
        try {
          if (AppConfig.isOfflineMode) {
            final db = await OfflineDbHelper.instance.database;
            await db.rawUpdate(
              'UPDATE products SET current_stock = current_stock + ? WHERE id = ?',
              [diff, tx.productId],
            );
          } else {
            final prodRes = await supabase.from('products').select('current_stock').eq('id', tx.productId).single();
            final currentStock = (prodRes['current_stock'] ?? 0).toDouble();
            await supabase.from('products').update({
              'current_stock': currentStock + diff,
            }).eq('id', tx.productId);
          }
        } catch (_) {}
      }

      // 4. Refresh providers
      ref.invalidate(productsProvider);
      state = await AsyncValue.guard(() => _fetchTransactions());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Manually add a stock adjustment (Opening, Adjustment, Wastage, etc.)
  Future<void> addTransaction({
    required String productId,
    required String transType,
    required double quantity,
    required String transactionDate,
    String? remarks,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();

    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      await supabase.from('stock_transactions').insert({
        'id': id,
        'product_id': productId,
        'trans_type': transType,
        'quantity': quantity,
        'transaction_date': transactionDate,
        'reference_type': 'Adjustment',
        'created_at': DateTime.now().toIso8601String(),
      });

      final bool isIncoming = transType.toUpperCase() == 'IN' || 
                              transType.toLowerCase() == 'purchase' || 
                              transType.toLowerCase() == 'opening';
      final double stockDelta = isIncoming ? quantity : -quantity;

      try {
        final prodRes = await supabase.from('products').select('current_stock').eq('id', productId).single();
        final currentStock = (prodRes['current_stock'] ?? 0).toDouble();
        await supabase.from('products').update({
          'current_stock': currentStock + stockDelta,
        }).eq('id', productId);
      } catch (_) {}

      ref.invalidate(productsProvider);
      state = await AsyncValue.guard(() => _fetchTransactions());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final stockProvider = AsyncNotifierProvider<StockNotifier, List<StockTransaction>>(() {
  return StockNotifier();
});
