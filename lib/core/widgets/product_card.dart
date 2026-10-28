import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../widgets/common_widgets.dart';
import '../../features/products/models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/products/${product.slug}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: AppNetworkImage(
                  url: product.displayThumbnail,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              if (product.discountPercent != null &&
                  product.discountPercent! > 0)
                Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('${product.discountPercent}% OFF',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    )),
              if (product.isFeatured)
                Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppColors.star,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text('⭐', style: TextStyle(fontSize: 10)),
                    )),
            ]),

            /// INFO SECTION
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.brandName,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
                    const SizedBox(height: 5),
                    if (product.reviewCount > 0)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: StarRating(
                              rating: product.avgRating,
                              count: product.reviewCount,
                              size: 12)),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('₹${_fmt(product.currentPrice)}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary)),
                      if (product.salePrice != null) ...[
                        const SizedBox(width: 4),
                        Text('₹${_fmt(product.price)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textLight,
                                decoration: TextDecoration.lineThrough)),
                      ],
                    ]),
                    if (product.isPrebooking)
                      Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)),
                              child: const Text('🔔 Pre-Booking',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700))))
                    else if (!product.inStock)
                      Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6)),
                              child: const Text('Out of Stock',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700)))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toInt().toString();
  }
}
