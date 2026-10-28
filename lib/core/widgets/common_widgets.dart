import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';

// ── Gradient Button ────────────────────────────────────────────────────────
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final double height;
  final Widget? icon;

  const GradientButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.height = 52,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: onTap == null || loading
              ? const LinearGradient(colors: [Colors.grey, Colors.grey])
              : AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap != null && !loading
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Text(label, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 16, letterSpacing: 0.2)),
                ]),
        ),
      ),
    );
  }
}

// ── Outlined Button ────────────────────────────────────────────────────────
class AppOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;

  const AppOutlinedButton({super.key, required this.label, this.onTap, this.height = 50});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height,
        decoration: BoxDecoration(
          border: Border.all(
            color: disabled ? AppColors.border : AppColors.primary,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(14),
          color: disabled ? AppColors.borderLight : Colors.transparent,
        ),
        child: Center(child: Text(label, style: TextStyle(
            color: disabled ? AppColors.textLight : AppColors.primary,
            fontWeight: FontWeight.w700, fontSize: 15))),
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title, style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
      const Spacer(),
      if (actionLabel != null)
        GestureDetector(
          onTap: onAction,
          child: Text(actionLabel!, style: const TextStyle(
              fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
    ]);
  }
}

// ── Network Image ──────────────────────────────────────────────────────────
class AppNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const AppNetworkImage({super.key, this.url, this.width, this.height,
      this.fit = BoxFit.cover, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _placeholder();
    }
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: url!,
        width: width, height: height, fit: fit,
        placeholder: (_, __) => _shimmer(),
        errorWidget: (_, __, ___) => _placeholder(),
      ),
    );
  }

  Widget _shimmer() => Shimmer.fromColors(
    baseColor: Colors.grey.shade200,
    highlightColor: Colors.grey.shade100,
    child: Container(width: width, height: height, color: Colors.white),
  );

  Widget _placeholder() => Container(
    width: width, height: height,
    color: AppColors.borderLight,
    child: const Icon(Icons.phone_android, color: AppColors.border, size: 32),
  );
}

// ── Loading Shimmer for product card ──────────────────────────────────────
class ProductCardShimmer extends StatelessWidget {
  const ProductCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 150, decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)))),
          Padding(padding: const EdgeInsets.all(10), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 12, width: double.infinity, color: Colors.white),
            const SizedBox(height: 6),
            Container(height: 10, width: 80, color: Colors.white),
            const SizedBox(height: 8),
            Container(height: 14, width: 60, color: Colors.white),
          ])),
        ]),
      ),
    );
  }
}

// ── Variant chip ──────────────────────────────────────────────────────────
class VariantChip extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const VariantChip({super.key, required this.label, required this.bgColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textColor)),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const EmptyState({super.key, required this.emoji, required this.title,
      required this.subtitle, this.buttonLabel, this.onButton});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 64)),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        if (buttonLabel != null) ...[
          const SizedBox(height: 24),
          SizedBox(width: 180, child: GradientButton(label: buttonLabel!, onTap: onButton)),
        ],
      ]),
    ));
  }
}

// ── Star rating row ────────────────────────────────────────────────────────
class StarRating extends StatelessWidget {
  final double rating;
  final int count;
  final double size;

  const StarRating({super.key, required this.rating, this.count = 0, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ...List.generate(5, (i) => Icon(
        i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
        color: AppColors.star, size: size)),
      if (count > 0) ...[
        const SizedBox(width: 4),
        Text('($count)', style: TextStyle(fontSize: size - 2, color: AppColors.textSecondary)),
      ],
    ]);
  }
}
