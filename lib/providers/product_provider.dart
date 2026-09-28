import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/flutter_models.dart';
import 'auth_provider.dart';

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    return _fetchProducts();
  }

  Future<List<Product>> _fetchProducts() async {
    final supabase = ref.read(supabaseClientProvider);
    final response = await supabase.from('products').select().order('name');
    return (response as List).map((json) => Product.fromJson(json)).toList();
  }

  Future<void> addProduct(String name, String category, String unit, double purchaseRate, double sellingRate, double initialStock) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('products').insert({
        'name': name,
        'category': category,
        'unit': unit,
        'purchase_rate': purchaseRate,
        'selling_rate': sellingRate,
        'opening_stock': initialStock,
        'current_stock': initialStock,
        'status': true,
      });
      state = await AsyncValue.guard(() => _fetchProducts());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateProduct(String id, String name, String category, String unit, double purchaseRate, double sellingRate) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('products').update({
        'name': name,
        'category': category,
        'unit': unit,
        'purchase_rate': purchaseRate,
        'selling_rate': sellingRate,
      }).eq('id', id);
      state = await AsyncValue.guard(() => _fetchProducts());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    final supabase = ref.read(supabaseClientProvider);
    state = const AsyncValue.loading();
    try {
      await supabase.from('products').delete().eq('id', id);
      state = await AsyncValue.guard(() => _fetchProducts());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final productsProvider = AsyncNotifierProvider<ProductsNotifier, List<Product>>(() {
  return ProductsNotifier();
});

final outOfStockProductsProvider = Provider<List<Product>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  return productsAsync.maybeWhen(
    data: (products) => products.where((p) => p.status && p.currentStock <= 0).toList(),
    orElse: () => [],
  );
});

