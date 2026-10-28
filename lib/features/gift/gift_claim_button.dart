import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import 'gift_host.dart';

/// Glowing, sparkling "Free Gift" pill for the home header, shown next to the
/// wishlist icon. Visible only to logged-in users who can still claim.
class GiftClaimButton extends ConsumerStatefulWidget {
  const GiftClaimButton({super.key});

  @override
  ConsumerState<GiftClaimButton> createState() => _GiftClaimButtonState();
}

class _GiftClaimButtonState extends ConsumerState<GiftClaimButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(authProvider.select((s) => s.isLoggedIn))) {
      return const SizedBox.shrink();
    }
    final offer = ref.watch(giftOfferProvider).value;
    if (offer == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          // 0→1→0 pulse for the glow; sparkles twinkle out of phase.
          final pulse = (sin(_c.value * 2 * pi) + 1) / 2;
          double twinkle(double phase) =>
              ((sin((_c.value + phase) * 2 * pi) + 1) / 2);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openGiftSheet(context, ref),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFBBF24)
                          .withOpacity(0.35 + 0.45 * pulse),
                      blurRadius: 6 + 10 * pulse,
                      spreadRadius: 0.5 + 2 * pulse,
                    ),
                  ],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('🎁', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 4),
                  Text('Free Gift',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900)),
                ]),
              ),
              Positioned(
                top: -6,
                right: -2,
                child: Opacity(
                  opacity: 0.25 + 0.75 * twinkle(0),
                  child: const Icon(Icons.auto_awesome,
                      size: 13, color: Color(0xFFFBBF24)),
                ),
              ),
              Positioned(
                bottom: -5,
                left: 2,
                child: Opacity(
                  opacity: 0.25 + 0.75 * twinkle(0.5),
                  child: const Icon(Icons.auto_awesome,
                      size: 10, color: Color(0xFFFBBF24)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}
