import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../models/product_model.dart';

// ── Wishlist list provider ────────────────────────────────────────────────────
// autoDispose so it refreshes every time the sheet/screen is opened
final wishlistProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final res = await ApiService.get(ApiConstants.wishlist);
  final items = res.data['items'] as List? ?? [];
  return items.map((e) => ProductModel.fromJson(e)).toList();
});

// ── Wishlist IDs set — for O(1) "is this product wishlisted?" check ───────────
// Holds the set of product IDs currently in the user's wishlist.
// StateNotifier so we can optimistically update without re-fetching the list.
class WishlistNotifier extends StateNotifier<Set<int>> {
  WishlistNotifier() : super({});

  void setFromProducts(List<ProductModel> products) {
    state = products.map((p) => p.id).toSet();
  }

  void add(int productId) => state = {...state, productId};

  void remove(int productId) => state = state.where((id) => id != productId).toSet();

  bool contains(int productId) => state.contains(productId);
}

final wishlistIdsProvider =
    StateNotifierProvider<WishlistNotifier, Set<int>>((_) => WishlistNotifier());
// TODO Implement this library.