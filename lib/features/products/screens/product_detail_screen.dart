import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobileshop/core/constants/api_constants.dart';
import 'package:mobileshop/core/widgets/product_card.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/services/api_service.dart';
import '../../products/models/product_model.dart';
import '../../cart/providers/cart_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/wishlist_provider.dart';

final productDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, slug) async {
  final res = await ApiService.get('/products/$slug');
  return res.data as Map<String, dynamic>;
});

class ProductDetailScreen extends ConsumerStatefulWidget {
  final String slug;
  const ProductDetailScreen({super.key, required this.slug});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final _pageCtrl = PageController();
  int _activeImage = 0;
  ProductVariant? _selectedVariant;
  String? _selectedColor;
  bool _showExchange = false;
  bool _exchangeApplied = false;

  // Coupon state
  CouponModel? _appliedCoupon;
  double _couponDiscount = 0;

  // Exchange form
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _imeiCtrl = TextEditingController();
  String? _exchangeCondition;
  bool _imeiValid = false;
  String? _imeiError;
  TradeInPriceModel? _selectedTradeInPrice;
  bool _otherPhoneSelected = false;

  List<String> _currentImages(ProductModel product) {
    final imgs = product.getImagesForColor(_selectedColor);
    return imgs.isNotEmpty
        ? imgs
        : (product.displayThumbnail.isNotEmpty
            ? [product.displayThumbnail]
            : []);
  }

  List<String> _availableColors(ProductModel product) {
    if (_selectedVariant != null &&
        _selectedVariant!.availableColors.isNotEmpty) {
      return _selectedVariant!.availableColors;
    }
    return product.colors;
  }

  double _exchangeValue(ProductModel product) {
    if (_exchangeCondition == null || product.exchangeOffer == null) return 0;
    return product.exchangeOffer!.calculateValue(_exchangeCondition!,
        oldPhonePrice: _selectedTradeInPrice?.price);
  }

  Future<void> _pickTradeInModel() async {
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TradeInModelPicker(),
    );
    if (result == null || !mounted) return;

    if (result == _kOtherPhoneSentinel) {
      setState(() {
        _otherPhoneSelected = true;
        _selectedTradeInPrice = null;
        _brandCtrl.clear();
        _modelCtrl.clear();
      });
      return;
    }

    final picked = result as TradeInPriceModel;
    setState(() {
      _otherPhoneSelected = false;
      _selectedTradeInPrice = picked;
      _brandCtrl.text = picked.brand;
      _modelCtrl.text = picked.model;
    });
  }

  void _applyCoupon(CouponModel coupon, double price) {
    final discount = _computeCouponDiscount2(coupon, price);
    setState(() {
      _appliedCoupon = coupon;
      _couponDiscount = discount;
    });
  }

  double _computeCouponDiscount2(CouponModel c, double price) {
    if (price < c.minOrder) return 0;
    if (c.type == 'percent') {
      final raw = price * c.value / 100;
      return c.maxDiscount != null ? raw.clamp(0, c.maxDiscount!) : raw;
    }
    return c.value.clamp(0, price);
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponDiscount = 0;
    });
  }

  Future<void> _toggleWishlist(int productId, String slug) async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) {
      context.push('/login');
      return;
    }

    final notifier = ref.read(wishlistIdsProvider.notifier);
    final isCurrentlyIn = notifier.contains(productId);

    // Optimistic update
    isCurrentlyIn ? notifier.remove(productId) : notifier.add(productId);

    try {
      await ApiService.post('${ApiConstants.wishlist}/$slug');
      // Invalidate the list so WishlistSheet reflects the change
      ref.invalidate(wishlistProvider);
    } catch (_) {
      // Revert on failure
      isCurrentlyIn ? notifier.add(productId) : notifier.remove(productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update wishlist. Please try again.'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _verifyImei() {
    final imei = _imeiCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (imei.length != 15) {
      setState(() {
        _imeiError = 'IMEI must be 15 digits';
        _imeiValid = false;
      });
      return;
    }
    int sum = 0;
    for (int i = 0; i < 15; i++) {
      int d = int.parse(imei[i]);
      if (i % 2 == 1) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
    }
    setState(() {
      _imeiValid = sum % 10 == 0;
      _imeiError = _imeiValid ? null : 'Invalid IMEI number';
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(productDetailProvider(widget.slug));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final product = ProductModel.fromJson(data['product']);
          final related = (data['related'] as List? ?? [])
              .map<ProductModel>(
                  (e) => ProductModel.fromJson(e as Map<String, dynamic>))
              .toList();

          final coupons = (data['coupons'] as List? ?? [])
              .map<CouponModel>(
                  (e) => CouponModel.fromJson(e as Map<String, dynamic>))
              .toList();
          final reviews = data['reviews'] as List? ?? [];

          // Seed wishlist state from API response if backend returns it
          final inWishlistFromApi = data['in_wishlist'] as bool?;
          final wishlistIds = ref.watch(wishlistIdsProvider);
          final inWishlist = inWishlistFromApi != null
              ? wishlistIds.contains(product.id) || inWishlistFromApi
              : wishlistIds.contains(product.id);

          // Sync the API-returned flag into the provider (once, via postFrameCallback)
          if (inWishlistFromApi == true &&
              !ref.read(wishlistIdsProvider).contains(product.id)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(wishlistIdsProvider.notifier).add(product.id);
            });
          }

          // Auto-select first available (in-stock) variant
          if (_selectedVariant == null && product.variants.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedVariant == null) {
                final firstInStock = product.variants.firstWhere(
                  (v) => v.inStock,
                  orElse: () => product.variants.first,
                );
                setState(() => _selectedVariant = firstInStock);
              }
            });
          }

          final images = _currentImages(product);
          final price = _selectedVariant != null
              ? _selectedVariant!.currentPrice
              : product.currentPrice;

          return CustomScrollView(slivers: [
            // Image carousel app bar
            SliverAppBar(
              expandedHeight: 400,
              pinned: true,
              backgroundColor: AppColors.surface,
              leading: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new,
                        size: 18, color: AppColors.textPrimary)),
              ),
              actions: [
                GestureDetector(
                  onTap: () => _toggleWishlist(product.id, product.slug),
                  child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle),
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                          inWishlist ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: inWishlist
                              ? AppColors.error
                              : AppColors.textSecondary)),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(children: [
                  PageView.builder(
                    controller: _pageCtrl,
                    itemCount: images.isNotEmpty ? images.length : 1,
                    onPageChanged: (i) => setState(() => _activeImage = i),
                    itemBuilder: (_, i) => SafeArea(
                      bottom: false,
                      child: Container(
                        color: AppColors.surface,
                        child: AppNetworkImage(
                          url: images.isNotEmpty ? images[i] : null,
                          fit: BoxFit.contain,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                            child: SmoothPageIndicator(
                          controller: _pageCtrl,
                          count: images.length,
                          effect: const ExpandingDotsEffect(
                              dotHeight: 6,
                              dotWidth: 6,
                              activeDotColor: AppColors.primary,
                              dotColor: Colors.grey),
                        ))),
                ]),
              ),
            ),

            // Product details
            SliverList(
                delegate: SliverChildListDelegate([
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand + name
                      Text(product.brandName,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(product.name,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              height: 1.2)),
                      const SizedBox(height: 8),

                      if (product.isPrebooking) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Text('🔔', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                product.expectedDate != null
                                    ? 'Pre-Booking · Expected ${product.expectedDate}'
                                    : 'Pre-Booking',
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary),
                              ),
                            ),
                          ]),
                        ),
                        if (product.prebookingNote != null) ...[
                          const SizedBox(height: 4),
                          Text(product.prebookingNote!,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ],
                        const SizedBox(height: 8),
                      ],

                      // Rating
                      if (product.reviewCount > 0)
                        StarRating(
                            rating: product.avgRating,
                            count: product.reviewCount),
                      const SizedBox(height: 10),

                      // Price
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_appliedCoupon != null) ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('₹${_fmtFull(price - _couponDiscount)}',
                                      style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary)),
                                  Row(children: [
                                    Text('₹${_fmtFull(price)}',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textLight,
                                            decoration: TextDecoration.lineThrough)),
                                    const SizedBox(width: 6),
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: AppColors.success,
                                            borderRadius: BorderRadius.circular(6)),
                                        child: Text('−₹${_couponDiscount.toInt()} OFF',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800))),
                                  ]),
                                ],
                              ),
                            ] else ...[
                              Text('₹${_fmtFull(price)}',
                                  style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary)),
                              // MRP: use variant's price field when a variant is
                              // selected, otherwise fall back to product.price
                              if (price < (_selectedVariant?.price ?? product.price)) ...[
                                const SizedBox(width: 8),
                                Text('₹${_fmtFull(_selectedVariant?.price ?? product.price)}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        color: AppColors.textLight,
                                        decoration: TextDecoration.lineThrough)),
                                const SizedBox(width: 6),
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: AppColors.error,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                        '${((1 - price / (_selectedVariant?.price ?? product.price)) * 100).round()}% OFF',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800))),
                              ],
                            ],
                          ]),
                      const SizedBox(height: 4),

                      if (product.shortDescription != null) ...[
                        const SizedBox(height: 8),
                        Text(product.shortDescription!,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                height: 1.5)),
                      ],

                      // ── COUPON SECTION ───────────────────────────────────
                      if (coupons.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _CouponSection(
                          coupons: coupons,
                          currentPrice: price,
                          appliedCoupon: _appliedCoupon,
                          onApply: (coupon) => _applyCoupon(coupon, price),
                          onRemove: _removeCoupon,
                        ),
                      ],

                      // ── EXCHANGE OFFER ────────────────────────────────────
                      if (product.exchangeOffer != null) ...[
                        const SizedBox(height: 16),
                        _ExchangeSection(
                          offer: product.exchangeOffer!,
                          showExchange: _showExchange,
                          exchangeApplied: _exchangeApplied,
                          brandCtrl: _brandCtrl,
                          modelCtrl: _modelCtrl,
                          imeiCtrl: _imeiCtrl,
                          condition: _exchangeCondition,
                          imeiValid: _imeiValid,
                          imeiError: _imeiError,
                          currentPrice: price,
                          selectedTradeInPrice: _selectedTradeInPrice,
                          otherPhoneSelected: _otherPhoneSelected,
                          onToggle: () =>
                              setState(() => _showExchange = !_showExchange),
                          onConditionChanged: (v) =>
                              setState(() => _exchangeCondition = v),
                          onVerifyImei: _verifyImei,
                          onPickTradeIn: _pickTradeInModel,
                          onApply: () {
                            if (_brandCtrl.text.isEmpty ||
                                _modelCtrl.text.isEmpty ||
                                _exchangeCondition == null ||
                                !_imeiValid) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Please complete all exchange details')));
                              return;
                            }
                            setState(() {
                              _exchangeApplied = true;
                              _showExchange = false;
                            });
                          },
                          onRemove: () => setState(() {
                            _exchangeApplied = false;
                            _exchangeCondition = null;
                            _imeiValid = false;
                            _selectedTradeInPrice = null;
                            _otherPhoneSelected = false;
                            _brandCtrl.clear();
                            _modelCtrl.clear();
                          }),
                        ),
                      ],

                      // ── VARIANT SELECTOR (RAM + Storage) ──────────────────
                      if (product.variants.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(children: [
                          const Text('Variants',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
                          const Spacer(),
                          if (_selectedVariant != null)
                            Text('₹${_fmtFull(_selectedVariant!.currentPrice)}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary)),
                        ]),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: product.variants.map((v) {
                            final selected = _selectedVariant?.id == v.id;
                            return GestureDetector(
                              onTap: v.inStock
                                  ? () {
                                      setState(() {
                                        _selectedVariant = v;
                                        // Reset color if not in variant's colors
                                        if (v.availableColors.isNotEmpty &&
                                            !v.availableColors
                                                .contains(_selectedColor)) {
                                          _selectedColor = null;
                                        }
                                        _pageCtrl.jumpToPage(0);
                                        _activeImage = 0;
                                      });
                                    }
                                  : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primaryLight
                                      : AppColors.surface,
                                  border: Border.all(
                                      color: selected
                                          ? AppColors.primary
                                          : (v.inStock
                                              ? AppColors.border
                                              : AppColors.borderLight),
                                      width: selected ? 2 : 1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '${v.ram ?? ''} + ${v.storage ?? ''}',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: selected
                                                  ? AppColors.primary
                                                  : (v.inStock
                                                      ? AppColors.textPrimary
                                                      : AppColors.textLight))),
                                      if (!v.inStock)
                                        const Text('Out of stock',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.error))
                                      else ...[
                                        Text('₹${_fmtFull(v.currentPrice)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary)),
                                        if (v.salePrice != null &&
                                            v.salePrice! < v.price)
                                          Text('₹${_fmtFull(v.price)}',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.textLight,
                                                  decoration: TextDecoration
                                                      .lineThrough)),
                                      ],
                                    ]),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      // ── COLOR SELECTOR ─────────────────────────────────────
                      if (_availableColors(product).isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(children: [
                          const Text('Color',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          Text(_selectedColor ?? 'Select a color',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ]),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableColors(product).map((color) {
                            final selected = _selectedColor == color;
                            final imgCount = product.images
                                .where((i) => i.color == color)
                                .length;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedColor = selected ? null : color;
                                  _activeImage = 0;
                                  _pageCtrl.jumpToPage(0);
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primaryLight
                                      : AppColors.surface,
                                  border: Border.all(
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.border,
                                      width: selected ? 2 : 1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                              color: _colorDot(color),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Colors.white,
                                                  width: 2),
                                              boxShadow: [
                                                BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.1),
                                                    blurRadius: 2)
                                              ])),
                                      const SizedBox(width: 6),
                                      Text(color,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: selected
                                                  ? AppColors.primary
                                                  : AppColors.textPrimary)),
                                      if (imgCount > 0) ...[
                                        const SizedBox(width: 4),
                                        Text('($imgCount)',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textLight)),
                                      ],
                                    ]),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      // Exchange applied badge
                      if (_exchangeApplied) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.orange.shade300, width: 1.5)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Text('🔄',
                                      style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 8),
                                  const Text('Exchange Applied!',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.deepOrange,
                                          fontSize: 14)),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _exchangeApplied = false;
                                      _exchangeCondition = null;
                                      _imeiValid = false;
                                    }),
                                    child: const Text('Remove',
                                        style: TextStyle(
                                            color: AppColors.error,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ]),
                                const SizedBox(height: 6),
                                Text(
                                    '${_brandCtrl.text} ${_modelCtrl.text} · ${_exchangeCondition ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.orange.shade200)),
                                  child: Row(children: [
                                    Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('Exchange value',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      AppColors.textSecondary)),
                                          Text(
                                              '−₹${_exchangeValue(product).toInt()}',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  color:
                                                      Colors.orange.shade700)),
                                        ]),
                                    const SizedBox(width: 20),
                                    Container(
                                        width: 1,
                                        height: 36,
                                        color: Colors.orange.shade100),
                                    const SizedBox(width: 20),
                                    Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('You pay',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      AppColors.textSecondary)),
                                          Text(
                                              '₹${(price - _exchangeValue(product)).clamp(0, double.infinity).toInt()}',
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.primary)),
                                        ]),
                                  ]),
                                ),
                              ]),
                        ),
                      ],

                      // ── SPECS GRID ─────────────────────────────────────────
                      const SizedBox(height: 36),
                      const Text('Quick Specs',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 1),
                      _SpecsGrid(
                        product: product,
                        selectedVariant: _selectedVariant,
                      ),

                      // ── DESCRIPTION ────────────────────────────────────────
                      if (product.description != null) ...[
                        const SizedBox(height: 20),
                        const Text('About this Product',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(product.description!,
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                height: 1.6)),
                      ],

                      // ── REVIEWS ────────────────────────────────────────────
                      if (reviews.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Row(children: [
                          const Text('Reviews',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          StarRating(
                              rating: product.avgRating,
                              count: product.reviewCount),
                        ]),
                        const SizedBox(height: 12),
                        ...reviews.take(3).map((r) => _ReviewTile(review: r)),
                      ],

                      // ── RELATED ────────────────────────────────────────────
                      if (related.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text('You may also like',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        SizedBox(
                            height: 250,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: related.length,
                              itemBuilder: (_, i) => SizedBox(
                                  width: 160,
                                  child: Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: ProductCard(product: related[i]))),
                            )),
                      ],
                      const SizedBox(height: 100),
                    ]),
              ),
            ])),
          ]);
        },
      ),

      // Bottom bar
      bottomNavigationBar: async.when(
        data: (data) {
          final product = ProductModel.fromJson(data['product']);
          return _BottomBar(
              product: product,
              selectedVariant: _selectedVariant,
              selectedColor: _selectedColor,
              exchangeApplied: _exchangeApplied,
              exchangeBrand: _brandCtrl.text,
              exchangeModel: _modelCtrl.text,
              exchangeCondition: _exchangeCondition,
              exchangeImei: _imeiCtrl.text,
              exchangeTradeInPriceId: _selectedTradeInPrice?.id,
              appliedCouponCode: _appliedCoupon?.code,
              couponDiscount: _couponDiscount);
        },
        loading: () => const SizedBox(),
        error: (_, __) => const SizedBox(),
      ),
    );
  }

  String _fmtFull(double v) {
    final n = v.toInt();
    return n
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  Color _colorDot(String name) {
    final map = {
      'black': const Color(0xFF1F2937),
      'white': const Color(0xFFD1D5DB),
      'silver': const Color(0xFF9CA3AF),
      'gray': const Color(0xFF6B7280),
      'blue': const Color(0xFF3B82F6),
      'midnight': const Color(0xFF1E3A5F),
      'navy': const Color(0xFF1E3A8A),
      'green': const Color(0xFF22C55E),
      'red': const Color(0xFFEF4444),
      'rose': const Color(0xFFF43F5E),
      'pink': const Color(0xFFEC4899),
      'purple': const Color(0xFFA855F7),
      'violet': const Color(0xFF7C3AED),
      'gold': const Color(0xFFEAB308),
      'yellow': const Color(0xFFFACC15),
      'orange': const Color(0xFFF97316),
      'titanium': const Color(0xFF9CA3AF),
      'graphite': const Color(0xFF374151),
    };
    final key = name.toLowerCase();
    for (final entry in map.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return AppColors.primary;
  }
}

// Bottom CTA bar
class _BottomBar extends ConsumerStatefulWidget {
  final ProductModel product;
  final ProductVariant? selectedVariant;
  final String? selectedColor;
  final bool exchangeApplied;
  final String exchangeBrand;
  final String exchangeModel;
  final String? exchangeCondition;
  final String exchangeImei;
  final int? exchangeTradeInPriceId;
  final String? appliedCouponCode;
  final double couponDiscount;

  const _BottomBar(
      {required this.product,
      this.selectedVariant,
      this.selectedColor,
      required this.exchangeApplied,
      required this.exchangeBrand,
      required this.exchangeModel,
      this.exchangeCondition,
      required this.exchangeImei,
      this.exchangeTradeInPriceId,
      this.appliedCouponCode,
      this.couponDiscount = 0});

  @override
  ConsumerState<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends ConsumerState<_BottomBar> {
  bool _addingToCart = false;
  bool _buyingNow = false;

  Future<void> _doAddToCart({bool goCheckout = false}) async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) {
      context.push('/login');
      return;
    }

    setState(() {
      if (goCheckout)
        _buyingNow = true;
      else
        _addingToCart = true;
    });
    try {
      // Build exchange data map if exchange is applied
      Map<String, dynamic>? exchangeData;
      if (widget.exchangeApplied &&
          widget.exchangeBrand.isNotEmpty &&
          widget.exchangeModel.isNotEmpty &&
          widget.exchangeCondition != null) {
        exchangeData = {
          'brand': widget.exchangeBrand,
          'model': widget.exchangeModel,
          'imei': widget.exchangeImei,
          'condition': widget.exchangeCondition!,
          'trade_in_price_id': widget.exchangeTradeInPriceId,
          'estimated_value': widget.product.exchangeOffer?.calculateValue(
                  widget.exchangeCondition!,
                  oldPhonePrice: null // resolved server-side from trade_in_price_id
                  ) ??
              0,
        };
      }
      await ref.read(cartProvider.notifier).addToCart(
            productId: widget.product.id,
            variantId: widget.selectedVariant?.id,
            selectedColor: widget.selectedColor,
            quantity: 1,
            exchangeData: exchangeData,
          );

      // If a coupon was applied on this screen, push it to the cart too
      if (widget.appliedCouponCode != null && widget.appliedCouponCode!.isNotEmpty) {
        try {
          await ref.read(cartProvider.notifier).applyCoupon(widget.appliedCouponCode!);
        } catch (_) {
          // Coupon apply failure is non-fatal — cart was still added
        }
      }
      if (!mounted) return;
      if (goCheckout) {
        context.push('/checkout');
      } else {
        final msg = widget.appliedCouponCode != null
            ? 'Added to cart with coupon ${widget.appliedCouponCode}! 🎉'
            : 'Added to cart! 🛒';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted)
        setState(() {
          _addingToCart = false;
          _buyingNow = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final basePrice = widget.selectedVariant?.currentPrice ?? widget.product.currentPrice;
    final finalPrice = (basePrice - widget.couponDiscount).clamp(0.0, double.infinity) as double;

    // Check if this product is already in the cart
    final cartItems = ref.watch(cartProvider).items;
    final alreadyInCart = cartItems.any((item) => item.productId == widget.product.id);

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: AppColors.surface, boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4))
      ]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Savings summary bar — only when coupon is active
        if (widget.couponDiscount > 0) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Text('🎉', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
                    children: [
                      TextSpan(
                        text: 'Coupon applied! You save ',
                        style: TextStyle(color: AppColors.success.withOpacity(0.85)),
                      ),
                      TextSpan(
                        text: '₹${widget.couponDiscount.toInt()}',
                        style: const TextStyle(
                            color: AppColors.success, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ),
              Text('Pay ₹${_fmtFull(finalPrice)}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary)),
            ]),
          ),
        ],
        Row(children: [
          // Left button: "View Cart" if already in cart, else "Add to Cart"
          Expanded(
            child: alreadyInCart
                ? GestureDetector(
                    onTap: () => context.push('/cart'),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.success, width: 2),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_cart_rounded,
                              color: AppColors.success, size: 18),
                          SizedBox(width: 6),
                          Text('View Cart',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                  )
                : AppOutlinedButton(
                    label: _addingToCart
                        ? 'Adding...'
                        : (widget.product.isPrebooking ? '🔔 Pre-Book Now' : '🛒 Add to Cart'),
                    height: 50,
                    onTap: _addingToCart ? null : () => _doAddToCart(),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: GradientButton(
            label: widget.product.isPrebooking ? '🔔 Book Now' : '⚡ Buy Now',
            height: 50,
            loading: _buyingNow,
            onTap: _buyingNow ? null : () => _doAddToCart(goCheckout: true),
          )),
        ]),
      ]),
    );
  }

  String _fmtFull(double v) => v
      .toInt()
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ── Coupon Section ────────────────────────────────────────────────────────────
class _CouponSection extends StatefulWidget {
  final List<CouponModel> coupons;
  final double currentPrice;
  final CouponModel? appliedCoupon;
  final ValueChanged<CouponModel> onApply;
  final VoidCallback onRemove;

  const _CouponSection({
    required this.coupons,
    required this.currentPrice,
    required this.appliedCoupon,
    required this.onApply,
    required this.onRemove,
  });

  @override
  State<_CouponSection> createState() => _CouponSectionState();
}

class _CouponSectionState extends State<_CouponSection> {
  String? _copiedCode;

  double _discountFor(CouponModel c) {
    final price = widget.currentPrice;
    if (price < c.minOrder) return 0;
    if (c.type == 'percent') {
      final raw = price * c.value / 100;
      return c.maxDiscount != null ? raw.clamp(0, c.maxDiscount!) : raw;
    }
    return c.value.clamp(0, price);
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _copiedCode = code);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedCode = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        color: AppColors.primaryLight,
      ),
      child: Column(children: [
        // Header
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
            child: Row(children: const [
              Icon(Icons.local_offer_outlined, color: Colors.white, size: 15),
              SizedBox(width: 6),
              Text('Available Offers',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ])),

        // Applied coupon banner
        if (widget.appliedCoupon != null) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withOpacity(0.4)),
            ),
            child: Row(children: [
              const Text('✅', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${widget.appliedCoupon!.code} applied!',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.success)),
                  Text('You save ₹${_discountFor(widget.appliedCoupon!).toInt()}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ]),
              ),
              GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('Remove',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error)),
                ),
              ),
            ]),
          ),
        ],

        // Coupon rows
        ...widget.coupons.map((c) {
          final isApplied = widget.appliedCoupon?.code == c.code;
          final discount = _discountFor(c);
          final eligible = discount > 0;

          return Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isApplied
                      ? AppColors.success
                      : AppColors.primary.withOpacity(0.15),
                  width: isApplied ? 1.5 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                // Code badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          style: BorderStyle.solid)),
                  child: Text(c.code,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 1)),
                ),
                if (c.productSpecific) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(5)),
                    child: const Text('THIS PRODUCT',
                        style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.3)),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Text(c.displayLabel,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                // Copy button
                GestureDetector(
                  onTap: () => _copy(c.code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _copiedCode == c.code
                          ? AppColors.success
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _copiedCode == c.code
                              ? AppColors.success
                              : AppColors.border),
                    ),
                    child: Text(
                        _copiedCode == c.code ? '✓' : 'COPY',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _copiedCode == c.code
                                ? Colors.white
                                : AppColors.textSecondary)),
                  ),
                ),
              ]),

              if (c.minOrder > 0) ...[
                const SizedBox(height: 4),
                Text('Min order ₹${c.minOrder.toInt()}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ],

              // Savings preview
              if (eligible) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                      'Save ₹${discount.toInt()} → Pay ₹${(widget.currentPrice - discount).clamp(0, double.infinity).toInt()}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success)),
                ),
              ] else if (!eligible && c.minOrder > 0) ...[
                const SizedBox(height: 4),
                Text(
                    'Add ₹${(c.minOrder - widget.currentPrice).clamp(0, double.infinity).toInt()} more to unlock',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.warning)),
              ],

              const SizedBox(height: 8),
              // Apply / Remove button
              SizedBox(
                width: double.infinity,
                child: isApplied
                    ? OutlinedButton(
                        onPressed: widget.onRemove,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Remove Coupon',
                            style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      )
                    : ElevatedButton(
                        onPressed: eligible
                            ? () => widget.onApply(c)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.borderLight,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: Text(eligible ? 'Apply Coupon' : 'Not Eligible',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: eligible
                                    ? Colors.white
                                    : AppColors.textLight)),
                      ),
              ),
            ]),
          );
        }),

        const SizedBox(height: 12),
      ]),
    );
  }
}

// Exchange section widget
const _kOtherPhoneSentinel = '__other_phone_not_listed__';

class _TradeInModelPicker extends StatefulWidget {
  const _TradeInModelPicker();

  @override
  State<_TradeInModelPicker> createState() => _TradeInModelPickerState();
}

class _TradeInModelPickerState extends State<_TradeInModelPicker> {
  final _searchCtrl = TextEditingController();
  List<TradeInPriceModel> _results = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get(ApiConstants.tradeInModelSearch, params: {'q': q});
      final list = (res.data['models'] as List)
          .map((e) => TradeInPriceModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() { _results = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              const Expanded(
                  child: Text('Select your old phone',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search brand or model…',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.borderLight,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No matching models found.',
                              style: TextStyle(color: AppColors.textLight)),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final m = _results[i];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(m.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text('Reference price: ₹${m.price.toInt()}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => Navigator.pop(context, m),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, _kOtherPhoneSentinel),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                    side: const BorderSide(color: AppColors.border)),
                child: const Text("My phone isn't listed",
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ExchangeSection extends StatelessWidget {
  final ExchangeOffer offer;
  final bool showExchange;
  final bool exchangeApplied;
  final TextEditingController brandCtrl, modelCtrl, imeiCtrl;
  final String? condition;
  final bool imeiValid;
  final String? imeiError;
  final double currentPrice;
  final TradeInPriceModel? selectedTradeInPrice;
  final bool otherPhoneSelected;
  final VoidCallback onToggle, onApply, onRemove, onPickTradeIn;
  final ValueChanged<String?> onConditionChanged;
  final VoidCallback onVerifyImei;

  const _ExchangeSection({
    required this.offer,
    required this.showExchange,
    required this.exchangeApplied,
    required this.brandCtrl,
    required this.modelCtrl,
    required this.imeiCtrl,
    this.condition,
    required this.imeiValid,
    this.imeiError,
    required this.currentPrice,
    this.selectedTradeInPrice,
    required this.otherPhoneSelected,
    required this.onToggle,
    required this.onApply,
    required this.onRemove,
    required this.onPickTradeIn,
    required this.onConditionChanged,
    required this.onVerifyImei,
  });

  double get _exchangeValue {
    if (condition == null) return 0;
    return offer.calculateValue(condition!, oldPhonePrice: selectedTradeInPrice?.price);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade300),
        color: Colors.orange.shade50,
      ),
      child: Column(children: [
        // Header
        GestureDetector(
          onTap: onToggle,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.orange.shade500, Colors.amber.shade500]),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(14))),
              child: Row(children: [
                const Text('🔄', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Exchange Offer',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                      Text('Save up to ₹${offer.maxValue.toInt()}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ])),
                Text(showExchange ? 'Hide' : 'Apply',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ])),
        ),

        if (showExchange)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              // Old phone model — picked from the reference list, so the
              // exchange value can be capped against a real price
              GestureDetector(
                onTap: onPickTradeIn,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    const Icon(Icons.phone_android, size: 18, color: AppColors.textLight),
                    const SizedBox(width: 10),
                    Expanded(
                      child: selectedTradeInPrice != null
                          ? Text(selectedTradeInPrice!.label,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))
                          : otherPhoneSelected
                              ? const Text('Other phone (not listed)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700))
                              : const Text('Select your old phone',
                                  style: TextStyle(fontSize: 13, color: AppColors.textLight)),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textLight),
                  ]),
                ),
              ),
              if (otherPhoneSelected) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _ExField(ctrl: brandCtrl, hint: 'Brand')),
                  const SizedBox(width: 8),
                  Expanded(child: _ExField(ctrl: modelCtrl, hint: 'Model')),
                ]),
                const SizedBox(height: 6),
                Text(
                  "We'll review your submission and get back to you with a fair offer — an instant discount only applies to models in our reference list.",
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800, height: 1.3),
                ),
              ],
              const SizedBox(height: 10),

              // IMEI
              Row(children: [
                Expanded(
                    child: _ExField(
                        ctrl: imeiCtrl,
                        hint: '15-digit IMEI',
                        keyboardType: TextInputType.number,
                        maxLength: 15,
                        error: imeiError,
                        success: imeiValid ? 'IMEI Verified ✓' : null)),
                const SizedBox(width: 8),
                GestureDetector(
                    onTap: onVerifyImei,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                            color: AppColors.textPrimary,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Text('Verify',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)))),
              ]),
              const SizedBox(height: 10),

              // Condition
              DropdownButtonFormField<String>(
                value: condition,
                decoration: InputDecoration(
                  hintText: 'Phone Condition',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border)),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'excellent',
                      child: Text('✨ Excellent — like new')),
                  DropdownMenuItem(
                      value: 'good', child: Text('👍 Good — minor scratches')),
                  DropdownMenuItem(
                      value: 'fair', child: Text('🙂 Fair — visible wear')),
                  DropdownMenuItem(
                      value: 'poor', child: Text('⚠️ Poor — heavy wear')),
                ],
                onChanged: onConditionChanged,
              ),

              // Value estimator
              if (condition != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.orange.shade300, width: 2)),
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          if (otherPhoneSelected) ...[
                            const Text('Exchange value',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                            const Text('Pending review',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.orange)),
                          ] else ...[
                            const Text('Estimated exchange value',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                            Text('₹${_exchangeValue.toInt()}',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.orange)),
                            Text(
                                'You pay: ₹${(currentPrice - _exchangeValue).clamp(0, double.infinity).toInt()}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ],
                        ])),
                    const Text('📱', style: TextStyle(fontSize: 36)),
                  ]),
                ),
              ],

              const SizedBox(height: 12),
              GradientButton(
                  label: '✓ Apply Exchange', onTap: onApply, icon: null),
            ]),
          ),
      ]),
    );
  }
}

class _ExField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType? keyboardType;
  final int? maxLength;
  final String? error;
  final String? success;
  const _ExField(
      {required this.ctrl,
      required this.hint,
      this.keyboardType,
      this.maxLength,
      this.error,
      this.success});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLength: maxLength,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textLight),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: error != null
                      ? AppColors.error
                      : success != null
                          ? AppColors.success
                          : AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: error != null
                      ? AppColors.error
                      : success != null
                          ? AppColors.success
                          : AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        ),
      ),
      if (error != null)
        Text(error!,
            style: const TextStyle(fontSize: 10, color: AppColors.error)),
      if (success != null)
        Text(success!,
            style: const TextStyle(fontSize: 10, color: AppColors.success)),
    ]);
  }
}

// Specs grid
class _SpecsGrid extends StatelessWidget {
  final ProductModel product;
  final ProductVariant? selectedVariant;
  const _SpecsGrid({
    required this.product,
    this.selectedVariant,
  });

  @override
  Widget build(BuildContext context) {
    final specs = [
      if (product.displaySize != null || product.displayType != null)
        (
          '📱',
          'Display',
          '${product.displaySize ?? ''} ${product.displayType ?? ''}'.trim()
        ),
      if (product.processor != null) ('⚡', 'Processor', product.processor!),
      if ((selectedVariant?.ram ?? product.ram) != null)
        ('🧠', 'RAM', selectedVariant?.ram ?? product.ram!),
      if ((selectedVariant?.storage ?? product.storage) != null)
        ('💾', 'Storage', selectedVariant?.storage ?? product.storage!),
      if (product.battery != null) ('🔋', 'Battery', product.battery!),
      if (product.cameraMain != null) ('📸', 'Camera', product.cameraMain!),
      if (product.network != null) ('📡', 'Network', product.network!),
      if (product.os != null) ('🤖', 'OS', product.os!),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8),
      itemCount: specs.length,
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: AppColors.borderLight,
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Text(specs[i].$1, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text(specs[i].$2,
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary)),
                Text(specs[i].$3,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ])),
        ]),
      ),
    );
  }
}

// Review tile
class _ReviewTile extends StatelessWidget {
  final dynamic review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryLight,
              child: Text((review['user_name'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.primary))),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(review['user_name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                Text(review['created_at'] ?? '',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textLight)),
              ])),
          StarRating(rating: (review['rating'] as num).toDouble(), size: 13),
        ]),
        if (review['title'] != null) ...[
          const SizedBox(height: 6),
          Text(review['title'],
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
        if (review['body'] != null) ...[
          const SizedBox(height: 4),
          Text(review['body'],
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ]),
    );
  }
}
