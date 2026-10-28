import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../models/product_model.dart';

// ── FIX: Use a String key (not Map) so FutureProvider.family has correct
//         equality and doesn't re-fire on every rebuild. ──────────────────
final productsProvider =
    FutureProvider.family<List<ProductModel>, String>((ref, paramsKey) async {
  // Deserialise "category=smartphones&sort=newest&per_page=20" back to a map
  final params = <String, String>{};
  if (paramsKey.isNotEmpty) {
    for (final part in paramsKey.split('&')) {
      final idx = part.indexOf('=');
      if (idx > 0) params[part.substring(0, idx)] = part.substring(idx + 1);
    }
  }
  final res = await ApiService.get(ApiConstants.products, params: params);
  // Laravel paginated Resource returns { "data": [...], "meta": {...} }
  final raw = res.data;
  final list = (raw is Map ? raw['data'] : raw) as List? ?? [];
  return list
      .map<ProductModel>(
          (e) => ProductModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class ProductsScreen extends ConsumerStatefulWidget {
  final String? category;
  final String? brand;
  final String? sort;
  final bool? featured;

  const ProductsScreen(
      {super.key, this.category, this.brand, this.sort, this.featured});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String? _sort;
  String? _category;
  String? _brand;

  @override
  void initState() {
    super.initState();
    _sort = widget.sort;
    _category = widget.category;
    _brand = widget.brand;
  }

  // Build a stable string key from the current filter state
  String get _paramsKey {
    final parts = <String>[];
    if (_category != null && _category!.isNotEmpty)
      parts.add('category=$_category');
    if (_brand != null && _brand!.isNotEmpty) parts.add('brand=$_brand');
    if (_sort != null && _sort!.isNotEmpty) parts.add('sort=$_sort');
    if (widget.featured == true) parts.add('featured=1');
    parts.add('per_page=20');
    return parts.join('&');
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(_paramsKey));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 18)),
        title: Text(
          _category != null
              ? _category!
              : _brand != null
                  ? '$_brand Phones'
                  : 'All Phones',
          style: const TextStyle(
              fontWeight: FontWeight.w900, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined, color: AppColors.textPrimary),
            onPressed: _showFilterSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _SortChip(
                    label: 'Featured',
                    value: null,
                    current: _sort,
                    onTap: (v) => setState(() => _sort = v)),
                _SortChip(
                    label: 'Newest',
                    value: 'newest',
                    current: _sort,
                    onTap: (v) => setState(() => _sort = v)),
                _SortChip(
                    label: 'Low Price',
                    value: 'price_asc',
                    current: _sort,
                    onTap: (v) => setState(() => _sort = v)),
                _SortChip(
                    label: 'High Price',
                    value: 'price_desc',
                    current: _sort,
                    onTap: (v) => setState(() => _sort = v)),
                _SortChip(
                    label: 'Top Rated',
                    value: 'rating',
                    current: _sort,
                    onTap: (v) => setState(() => _sort = v)),
              ]),
            ),
          ),
        ),
      ),
      body: productsAsync.when(
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10),
          itemCount: 6,
          itemBuilder: (_, __) => const ProductCardShimmer(),
        ),
        error: (e, _) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('😕', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 10),
          Text('$e', style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          GradientButton(
              label: 'Retry',
              onTap: () => ref.invalidate(productsProvider(_paramsKey)),
              height: 44),
        ])),
        data: (products) => products.isEmpty
            ? const EmptyState(
                emoji: '📱',
                title: 'No phones found',
                subtitle: 'Try adjusting your filters')
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.63,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10),
                itemCount: products.length,
                itemBuilder: (_, i) => ProductCard(product: products[i]),
              ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        currentSort: _sort,
        currentCategory: _category,
        onApply: (sort, category) {
          setState(() {
            _sort = sort;
            _category = category;
          });
        },
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final String? value;
  final String? current;
  final ValueChanged<String?> onTap;

  const _SortChip(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : AppColors.surface,
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textPrimary)),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final String? currentSort;
  final String? currentCategory;
  final Function(String?, String?) onApply;
  const _FilterSheet(
      {this.currentSort, this.currentCategory, required this.onApply});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _sort;
  String? _category;

  @override
  void initState() {
    super.initState();
    _sort = widget.currentSort;
    _category = widget.currentCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Filters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              TextButton(
                  onPressed: () {
                    setState(() {
                      _sort = null;
                      _category = null;
                    });
                  },
                  child: const Text('Clear All',
                      style: TextStyle(color: AppColors.error))),
            ]),
            const SizedBox(height: 16),
            const Text('Sort By',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              _Chip(
                  label: 'Featured',
                  value: null,
                  current: _sort,
                  onTap: (v) => setState(() => _sort = v)),
              _Chip(
                  label: 'Newest',
                  value: 'newest',
                  current: _sort,
                  onTap: (v) => setState(() => _sort = v)),
              _Chip(
                  label: 'Price ↑',
                  value: 'price_asc',
                  current: _sort,
                  onTap: (v) => setState(() => _sort = v)),
              _Chip(
                  label: 'Price ↓',
                  value: 'price_desc',
                  current: _sort,
                  onTap: (v) => setState(() => _sort = v)),
              _Chip(
                  label: 'Top Rated',
                  value: 'rating',
                  current: _sort,
                  onTap: (v) => setState(() => _sort = v)),
            ]),
            const SizedBox(height: 24),
            GradientButton(
                label: 'Apply Filters',
                onTap: () {
                  widget.onApply(_sort, _category);
                  Navigator.pop(context);
                },
                height: 50),
          ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String? value, current;
  final ValueChanged<String?> onTap;
  const _Chip(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return GestureDetector(
        onTap: () => onTap(value),
        child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? AppColors.primaryLight : AppColors.borderLight,
              border:
                  Border.all(color: sel ? AppColors.primary : AppColors.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? AppColors.primary : AppColors.textPrimary))));
  }
}
