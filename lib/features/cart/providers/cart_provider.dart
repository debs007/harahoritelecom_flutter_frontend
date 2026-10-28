import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/constants/api_constants.dart';

class CartItem {
  final int id;
  final int productId;
  final String productName;
  final String productSlug;
  final String? thumbnail;
  final int? variantId;
  final String? variantLabel;
  final String? selectedColor;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final Map<String, dynamic>? exchangeData;

  const CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productSlug,
    this.thumbnail,
    this.variantId,
    this.variantLabel,
    this.selectedColor,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.exchangeData,
  });

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        id: j['id'],
        productId: j['product_id'],
        productName: j['product_name'],
        productSlug: j['product_slug'] ?? '',
        thumbnail: j['thumbnail'],
        variantId: j['variant_id'],
        variantLabel: j['variant']?['label'],
        selectedColor: j['selected_color'],
        quantity: j['quantity'],
        unitPrice: (j['unit_price'] as num).toDouble(),
        subtotal: (j['subtotal'] as num).toDouble(),
        exchangeData: j['exchange_data'] as Map<String, dynamic>?,
      );
}

class CartState {
  final List<CartItem> items;
  final Map<String, dynamic>? coupon;
  final double subtotal;
  final double discount;
  final double exchangeDiscount;
  final double total;
  final int count;
  final bool loading;
  final String? error;

  const CartState({
    this.items = const [],
    this.coupon,
    this.subtotal = 0,
    this.discount = 0,
    this.exchangeDiscount = 0,
    this.total = 0,
    this.count = 0,
    this.loading = false,
    this.error,
  });
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState()) {
    _tryLoadCart();
  }

  // Only load cart if user is logged in
  Future<void> _tryLoadCart() async {
    final hasToken = await StorageService.hasToken();
    if (hasToken) await loadCart();
  }

  Future<void> loadCart() async {
    final hasToken = await StorageService.hasToken();
    if (!hasToken) {
      state = const CartState();
      return;
    }

    state = CartState(
        loading: true,
        items: state.items,
        coupon: state.coupon,
        count: state.count);
    try {
      final res = await ApiService.get(ApiConstants.cart);
      final data = res.data as Map<String, dynamic>;
      state = CartState(
        items: (data['items'] as List? ?? [])
            .map<CartItem>((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        coupon:           data['coupon'] as Map<String, dynamic>?,
        subtotal:         (data['subtotal'] as num? ?? 0).toDouble(),
        discount:         (data['discount'] as num? ?? 0).toDouble(),
        exchangeDiscount: (data['exchange_discount'] as num? ?? 0).toDouble(),
        total:            (data['total'] as num? ?? 0).toDouble(),
        count:            data['count'] ?? 0,
      );
    } catch (e) {
      state = CartState(
          error: e.toString(), items: state.items, count: state.count);
    }
  }

  Future<void> addToCart({
    required int productId,
    int? variantId,
    String? selectedColor,
    int quantity = 1,
    Map<String, dynamic>? exchangeData,
  }) async {
    final hasToken = await StorageService.hasToken();
    if (!hasToken) {
      throw Exception('Please log in to add items to cart.');
    }

    // Build the request body — no null values for cleanliness
    final body = <String, dynamic>{
      'product_id': productId,
      'quantity': quantity,
    };
    if (variantId != null) body['variant_id'] = variantId;
    if (selectedColor != null) body['selected_color'] = selectedColor;
    // ── FIX: use jsonEncode, NOT toString() ──────────────────────────
    if (exchangeData != null) body['exchange_data'] = jsonEncode(exchangeData);

    await ApiService.post(ApiConstants.cartAdd, data: body);
    await loadCart();
  }

  Future<void> updateQuantity(int cartId, int quantity) async {
    await ApiService.patch('${ApiConstants.cart}/$cartId',
        data: {'quantity': quantity});
    await loadCart();
  }

  Future<void> removeItem(int cartId) async {
    await ApiService.delete('${ApiConstants.cart}/$cartId');
    await loadCart();
  }

  Future<String?> applyCoupon(String code) async {
    try {
      final res =
          await ApiService.post(ApiConstants.cartCoupon, data: {'code': code});
      await loadCart();
      return res.data['message'] as String?;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeCoupon() async {
    await ApiService.delete(ApiConstants.cartCoupon);
    await loadCart();
  }

  void clearLocalCart() {
    state = const CartState();
  }
}

final cartProvider =
    StateNotifierProvider<CartNotifier, CartState>((_) => CartNotifier());
