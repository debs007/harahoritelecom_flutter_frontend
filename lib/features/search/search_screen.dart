import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/product_card.dart';
import '../../features/products/models/product_model.dart';

final searchProvider =
    FutureProvider.family<List<ProductModel>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final res = await ApiService.get(ApiConstants.productsSearch,
      params: {'q': query.trim()});
  final raw = res.data;
  final list = (raw is Map ? raw['data'] : raw) as List? ?? [];
  return list
      .map<ProductModel>(
          (e) => ProductModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field on open
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync =
        _query.isNotEmpty ? ref.watch(searchProvider(_query)) : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _ctrl,
            focusNode: _focus,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search phones, brands...',
              hintStyle: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: AppColors.borderLight,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textLight, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        setState(() => _query = '');
                      },
                      child: const Icon(Icons.close,
                          color: AppColors.textLight, size: 18),
                    )
                  : null,
            ),
            onChanged: (v) {
              // Debounce — only search after user pauses typing
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted && v == _ctrl.text) {
                  setState(() => _query = v.trim());
                }
              });
            },
            onSubmitted: (v) => setState(() => _query = v.trim()),
          ),
        ),
      ),
      body: _query.isEmpty
          ? _EmptySearch()
          : resultsAsync!.when(
              loading: () => GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.63,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10),
                itemCount: 6,
                itemBuilder: (_, __) => const ProductCardShimmer(),
              ),
              error: (e, _) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('😕', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text('Search failed',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => ref.invalidate(searchProvider(_query)),
                    child: const Text('Retry'),
                  ),
                ]),
              ),
              data: (products) => products.isEmpty
                  ? EmptyState(
                      emoji: '🔍',
                      title: 'No results for "$_query"',
                      subtitle: 'Try searching by brand, model or specs')
                  : Column(children: [
                      // Result count header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(children: [
                          Text('${products.length} results for',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                          const SizedBox(width: 4),
                          Text('"$_query"',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary)),
                        ]),
                      ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.63,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10),
                          itemCount: products.length,
                          itemBuilder: (_, i) =>
                              ProductCard(product: products[i]),
                        ),
                      ),
                    ]),
            ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'Samsung Galaxy',
      'iPhone 15',
      'OnePlus',
      'Redmi Note',
      'Pixel 8',
      'Vivo V30',
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Popular Searches',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions
              .map((s) => GestureDetector(
                    onTap: () {
                      // This will be handled by parent setState
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.search,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(s,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ))
              .toList(),
        ),
      ]),
    );
  }
}
