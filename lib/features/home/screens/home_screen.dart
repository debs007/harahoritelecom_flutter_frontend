import '../../gift/gift_claim_button.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../products/models/product_model.dart';
import '../../cart/providers/cart_provider.dart';
import '../../profile/screens/profile_screen.dart';

// ── Home data (banner, categories, featured, etc.) ───────────────────────────
final homeDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ApiService.get(ApiConstants.home);
  return res.data as Map<String, dynamic>;
});

// ── Explore grid state (paginated random products) ───────────────────────────
class ExploreState {
  final List<ProductModel> products;
  final bool loading;
  final bool hasMore;
  final int page;
  const ExploreState({
    this.products = const [],
    this.loading  = false,
    this.hasMore  = true,
    this.page     = 1,
  });
  ExploreState copyWith({
    List<ProductModel>? products,
    bool? loading,
    bool? hasMore,
    int?  page,
  }) => ExploreState(
    products: products ?? this.products,
    loading:  loading  ?? this.loading,
    hasMore:  hasMore  ?? this.hasMore,
    page:     page     ?? this.page,
  );
}

class ExploreNotifier extends StateNotifier<ExploreState> {
  ExploreNotifier() : super(const ExploreState()) { loadMore(); }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    state = state.copyWith(loading: true);
    try {
      final res  = await ApiService.get(ApiConstants.products, params: {
        'sort': 'random', 'per_page': 10, 'page': state.page,
      });
      final body     = res.data as Map<String, dynamic>;
      final items    = body['data'] as List? ?? [];
      final meta     = body['meta'] as Map?;
      final lastPage = (meta?['last_page'] as num?)?.toInt() ?? 1;
      final fresh    = items.map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList();
      state = state.copyWith(
        products: [...state.products, ...fresh],
        loading:  false,
        hasMore:  state.page < lastPage,
        page:     state.page + 1,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  void reset() { state = const ExploreState(); loadMore(); }
}

final exploreProvider =
    StateNotifierProvider<ExploreNotifier, ExploreState>((_) => ExploreNotifier());

// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Trigger load-more when within 400 px of the bottom
  void _onScroll() {
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      ref.read(exploreProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeAsync = ref.watch(homeDataProvider);
    final explore   = ref.watch(exploreProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(homeDataProvider);
          ref.read(exploreProvider.notifier).reset();
        },
        child: CustomScrollView(
          controller: _scroll,
          slivers: [

            // ── App Bar ──────────────────────────────────────────────────
            SliverAppBar(
              floating: true, snap: true,
              backgroundColor: AppColors.surface,
              elevation: 0, titleSpacing: 0,
              title: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Image.asset('assets/images/harahori.jpg',
                        width: 44, height: 44, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: RichText(text: const TextSpan(children: [
                        TextSpan(text: 'Harahori', style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                        TextSpan(text: ' Telecom', style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w900, color: AppColors.primary)),
                      ])),
                    ),
                  ),
                  const Spacer(),
                  const GiftClaimButton(),
                  IconButton(
                    icon: const Icon(Icons.favorite_border_rounded, color: AppColors.textPrimary),
                    onPressed: () => showModalBottomSheet(
                      context: context, isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ProviderScope(
                        parent: ProviderScope.containerOf(context),
                        child: const WishlistSheet(),
                      ),
                    ),
                  ),
                  Consumer(builder: (context, ref, _) {
                    final count = ref.watch(cartProvider).count;
                    return Stack(clipBehavior: Clip.none, children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_bag_outlined, color: AppColors.textPrimary),
                        onPressed: () => context.push('/cart'),
                      ),
                      if (count > 0) Positioned(
                        right: 6, top: 6,
                        child: Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(color: AppColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5)),
                          child: Center(child: Text(count > 99 ? '99+' : '$count',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 9, fontWeight: FontWeight.w900))),
                        ),
                      ),
                    ]);
                  }),
                ]),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: GestureDetector(
                    onTap: () => context.push('/search'),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(color: AppColors.borderLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border)),
                      child: const Row(children: [
                        SizedBox(width: 14),
                        Icon(Icons.search, color: AppColors.textLight, size: 20),
                        SizedBox(width: 8),
                        Text('Search phones, brands...', style: TextStyle(
                            color: AppColors.textLight, fontSize: 14)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),

            // ── Page body ────────────────────────────────────────────────
            homeAsync.when(
              loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
              error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $e'))),
              data: (data) {
                final categories  = data['categories']   as List? ?? [];
                final featured    = data['featured']     as List? ?? [];
                final newArrivals = data['new_arrivals'] as List? ?? [];
                final topRated    = data['top_rated']    as List? ?? [];
                final brands      = data['brands']       as List? ?? [];
                final coupons     = data['coupons']      as List? ?? [];
                final banners     = data['banners']      as List? ?? [];

                return SliverList(delegate: SliverChildListDelegate([

                  // Hero
                  if (banners.isNotEmpty)
                    _BannerSlider(banners: banners)
                  else
                    const _HeroBanner(),
                  const SizedBox(height: 20),

                  // Coupons
                  if (coupons.isNotEmpty) ...[
                    _CouponStrip(coupons: coupons),
                    const SizedBox(height: 20),
                  ],

                  // Categories
                  Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SectionHeader(title: 'Shop by Category',
                        actionLabel: 'See all',
                        onAction: () => context.push('/products'))),
                  _CategoryRow(categories: categories),
                  const SizedBox(height: 24),

                  // Featured
                  if (featured.isNotEmpty) ...[
                    Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SectionHeader(title: '⭐ Featured Picks',
                          actionLabel: 'See all',
                          onAction: () => context.push('/products?featured=1'))),
                    _HorizontalProductScroll(products: featured),
                    const SizedBox(height: 24),
                  ],

                  // New Arrivals
                  if (newArrivals.isNotEmpty) ...[
                    Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SectionHeader(title: '🆕 New Arrivals',
                          actionLabel: 'See all',
                          onAction: () => context.push('/products?sort=newest'))),
                    _HorizontalProductScroll(products: newArrivals),
                    const SizedBox(height: 24),
                  ],

                  // Top Rated
                  if (topRated.isNotEmpty) ...[
                    Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SectionHeader(title: '🏆 Top Rated',
                          actionLabel: 'See all',
                          onAction: () => context.push('/products?sort=rating'))),
                    _HorizontalProductScroll(products: topRated),
                    const SizedBox(height: 28),
                  ],

                  // ── "Explore All" divider banner ────────────────────────
                  const _ExploreDivider(),
                  const SizedBox(height: 16),

                  Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SectionHeader(title: '🛍️ Explore All Products',
                        actionLabel: 'Browse',
                        onAction: () => context.push('/products'))),

                  // 2-column grid — shrinkWrap inside non-scrolling parent
                  _ExploreGrid(explore: explore),

                  // Loading spinner
                  if (explore.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2.5)),
                    ),

                  // End of list message
                  if (!explore.hasMore && explore.products.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text("You've seen it all! 🎉",
                          style: TextStyle(fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600))),
                    ),

                  // ── Top Brands ──────────────────────────────────────────
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 20),
                  Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: const SectionHeader(title: '🏷️ Top Brands')),
                  _BrandRow(brands: brands),
                  const SizedBox(height: 100),
                ]));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Explore divider banner ─────────────────────────────────────────────────────
class _ExploreDivider extends StatelessWidget {
  const _ExploreDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF9333EA), Color(0xFFD946EF)],
          begin: Alignment.centerLeft, end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(children: [
        Icon(Icons.auto_awesome, color: Colors.white, size: 18),
        SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Explore All', style: TextStyle(color: Colors.white,
              fontWeight: FontWeight.w900, fontSize: 15)),
          Text('Handpicked from every category — scroll to discover',
              style: TextStyle(color: Colors.white70, fontSize: 11)),
        ])),
        Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 20),
      ]),
    );
  }
}

// ── 2-column explore grid ──────────────────────────────────────────────────────
class _ExploreGrid extends StatelessWidget {
  final ExploreState explore;
  const _ExploreGrid({required this.explore});

  @override
  Widget build(BuildContext context) {
    final products = explore.products;
    if (products.isEmpty && !explore.loading) return const SizedBox.shrink();

    // Pair products into rows of 2
    final rows = <List<ProductModel>>[];
    for (var i = 0; i < products.length; i += 2) {
      rows.add([
        products[i],
        if (i + 1 < products.length) products[i + 1],
      ]);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: rows.map((row) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: ProductCard(product: row[0])),
            const SizedBox(width: 10),
            row.length > 1
                ? Expanded(child: ProductCard(product: row[1]))
                : const Expanded(child: SizedBox()),
          ]),
        )).toList(),
      ),
    );
  }
}

// ── Hero Banner ────────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  const _HeroBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 180,
      decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.yellow.shade400,
                borderRadius: BorderRadius.circular(20)),
            child: const Text('🔥 New Arrivals', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
          ),
          const SizedBox(height: 10),
          const Text('Find Your\nPerfect Phone', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push('/products'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.yellow.shade400,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Shop Now →', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black)),
            ),
          ),
        ])),
        const Icon(Icons.phone_iphone, size: 80, color: Colors.white24),
      ]),
    );
  }
}

// ── Banner Slider (admin-managed, from /home 'banners') ────────────────────
class _BannerSlider extends StatefulWidget {
  final List banners;
  const _BannerSlider({required this.banners});

  @override
  State<_BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<_BannerSlider> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        final next = (_page + 1) % widget.banners.length;
        _controller.animateToPage(next,
            duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _openBanner(Map<String, dynamic> banner) {
    final product = banner['product'] as Map<String, dynamic>?;
    if (product == null) return; // banner has no link — nothing to open
    context.push('/products/${product['slug']}');
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 180,
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.banners.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) {
            final banner = widget.banners[i] as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => _openBanner(banner),
                child: AppNetworkImage(
                  url: banner['image'] as String?,
                  width: double.infinity,
                  height: 180,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            );
          },
        ),
      ),
      if (widget.banners.length > 1) ...[
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.banners.length, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    ]);
  }
}

// ── Coupon Strip ───────────────────────────────────────────────────────────────
class _CouponStrip extends StatelessWidget {
  final List coupons;
  const _CouponStrip({required this.coupons});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        gradient: LinearGradient(colors: [AppColors.primaryLight, Colors.purple.shade50]),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
          child: Row(children: const [
            Icon(Icons.local_offer_outlined, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Available Offers', style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3)),
          ]),
        ),
        ...coupons.take(3).map((c) {
          final coupon = CouponModel.fromJson(c);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(
                color: AppColors.primary.withOpacity(0.1)))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🎉 ${coupon.displayLabel}', style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('Use code ${coupon.code}'
                    '${coupon.minOrder > 0 ? " · Min ₹${coupon.minOrder.toInt()}" : ""}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
              _CopyButton(code: coupon.code),
            ]),
          );
        }),
      ]),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String code;
  const _CopyButton({required this.code});
  @override State<_CopyButton> createState() => _CopyButtonState();
}
class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  @override Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _copied = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _copied = false);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _copied ? AppColors.success : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _copied ? AppColors.success : AppColors.primary),
        ),
        child: Text(_copied ? '✓ Copied' : 'COPY', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800,
            color: _copied ? Colors.white : AppColors.primary)),
      ),
    );
  }
}

// ── Category Row ───────────────────────────────────────────────────────────────
class _CategoryRow extends StatelessWidget {
  final List categories;
  const _CategoryRow({required this.categories});
  static const _colors = [
    Color(0xFF7C3AED), Color(0xFFDB2777), Color(0xFFF97316), Color(0xFF0891B2),
    Color(0xFF059669), Color(0xFFDC2626), Color(0xFF7C3AED), Color(0xFF0891B2),
  ];
  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat      = categories[i];
          final imageUrl = cat['image'] as String?;
          final color    = _colors[i % _colors.length];
          return GestureDetector(
            onTap: () => context.push('/products?category=${cat['slug']}'),
            child: Container(margin: const EdgeInsets.only(right: 14),
              child: Column(children: [
                Container(width: 62, height: 62,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withOpacity(0.25), width: 1.5)),
                  clipBehavior: Clip.antiAlias,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: 55, height: 55, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _CategoryFallback(name: cat['name'] ?? '', color: color),
                          loadingBuilder: (_, child, progress) => progress == null ? child
                              : Container(color: color.withOpacity(0.08),
                                  child: Center(child: SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2,
                                        color: color.withOpacity(0.5))))),
                        )
                      : _CategoryFallback(name: cat['name'] ?? '', color: color),
                ),
                const SizedBox(height: 6),
                SizedBox(width: 66, child: Text(cat['name'] ?? '',
                    textAlign: TextAlign.center, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary))),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryFallback extends StatelessWidget {
  final String name;
  final Color color;
  const _CategoryFallback({required this.name, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    color: color.withOpacity(0.15),
    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color))),
  );
}

// ── Horizontal product scroll ──────────────────────────────────────────────────
class _HorizontalProductScroll extends StatelessWidget {
  final List products;
  const _HorizontalProductScroll({required this.products});
  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        itemBuilder: (_, i) {
          final p = ProductModel.fromJson(products[i]);
          return SizedBox(width: 160, child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ProductCard(product: p),
          ));
        },
      ),
    );
  }
}

// ── Brand Row ──────────────────────────────────────────────────────────────────
class _BrandRow extends StatelessWidget {
  final List brands;
  const _BrandRow({required this.brands});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(spacing: 8, runSpacing: 8,
        children: brands.map((b) => GestureDetector(
          onTap: () => context.push('/products?brand=${b['slug']}'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
            child: Text(b['name'] ?? '', style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
        )).toList(),
      ),
    );
  }
}
