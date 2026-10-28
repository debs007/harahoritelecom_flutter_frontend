import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/device_id_service.dart';
import '../auth/providers/auth_provider.dart';
import 'burst_effect.dart';

/// What the server says about the free gift for this device / account.
/// `null` = nothing to offer (campaign off, or already claimed).
/// Re-fetched whenever the logged-in user changes, so the home button appears
/// right after login and disappears right after claiming.
final giftOfferProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  ref.watch(authProvider.select((s) => s.user?.id));
  try {
    final deviceId = await DeviceIdService.get();
    final res =
        await ApiService.get(ApiConstants.gift, params: {'device_id': deviceId});
    final d = res.data as Map<String, dynamic>;
    return d['active'] == true ? d : null;
  } catch (_) {
    return null; // never block the app over a promo
  }
});

/// True while a guest has tapped "Claim" and been sent to sign up; once they
/// are logged in they are taken straight to the gift address screen.
final _pendingGiftClaim = StateProvider<bool>((_) => false);

/// Shows the gift banner sheet and, on "Claim", moves on to the next step:
/// the gift address screen if logged in, otherwise sign-up first.
Future<void> openGiftSheet(BuildContext context, WidgetRef ref) async {
  final offer = ref.read(giftOfferProvider).value;
  if (offer == null) return;

  final claim = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GiftSheet(offer: offer),
  );
  if (claim != true || !context.mounted) return;

  if (ref.read(authProvider).isLoggedIn) {
    context.push('/gift-claim');
  } else {
    ref.read(_pendingGiftClaim.notifier).state = true;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Create your account to claim your free gift 🎁'),
    ));
    context.push('/register');
  }
}

/// Wraps the main shell. On app launch it shows the gift sheet once (if
/// there is a gift to offer), and finishes the "guest tapped Claim → signed
/// up" hand-off by opening the gift address screen after login.
class GiftHost extends ConsumerStatefulWidget {
  final Widget child;
  const GiftHost({super.key, required this.child});

  @override
  ConsumerState<GiftHost> createState() => _GiftHostState();
}

class _GiftHostState extends ConsumerState<GiftHost> {
  // Once per app process, so navigating tabs never re-triggers the popup.
  static bool _shownThisLaunch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  Future<void> _maybeShow() async {
    if (_shownThisLaunch || !mounted) return;
    _shownThisLaunch = true;
    try {
      await ref.read(giftOfferProvider.future);
      if (!mounted) return;
      await openGiftSheet(context, ref);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (prev, next) {
      if (next.isLoggedIn &&
          !(prev?.isLoggedIn ?? false) &&
          ref.read(_pendingGiftClaim)) {
        ref.read(_pendingGiftClaim.notifier).state = false;
        // Let the router finish leaving the sign-up screen first.
        Future.delayed(const Duration(milliseconds: 600), () async {
          if (!mounted) return;
          // The offer is re-fetched for the new account (it may have claimed
          // on another device); only continue if a gift is still available.
          final offer = await ref.refresh(giftOfferProvider.future);
          if (mounted && offer != null) context.push('/gift-claim');
        });
      }
    });
    return widget.child;
  }
}

class _GiftSheet extends StatelessWidget {
  final Map<String, dynamic> offer;
  const _GiftSheet({required this.offer});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final title = offer['title'] as String? ?? 'A free gift for you!';
    final giftName = offer['gift_name'] as String? ?? 'gift';
    final desc = (offer['description'] as String?)?.trim() ?? '';
    return SizedBox(
      height: h * 0.52,
      child: Stack(children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                child: SizedBox(
                  width: double.infinity,
                  child: Image.network(
                    offer['banner'] as String,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient),
                      alignment: Alignment.center,
                      child: const Text('🎁', style: TextStyle(fontSize: 72)),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(desc.isNotEmpty ? desc : 'Claim your free $giftName',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('🎁  Claim my free gift'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Maybe later',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ]),
            ),
          ]),
        ),
        const Positioned.fill(child: BurstEffect()),
        Positioned(
          top: 10,
          right: 10,
          child: Material(
            color: Colors.black38,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(false),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
