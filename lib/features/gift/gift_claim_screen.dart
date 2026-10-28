import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/device_id_service.dart';
import '../../core/widgets/common_widgets.dart';
import '../checkout/screens/checkout_screen.dart'
    show addressesProvider, AddAddressSheet;
import 'burst_effect.dart';
import 'gift_host.dart';
import 'my_gifts_screen.dart';

/// Separate, app-only "checkout" for the free gift: no cart, no payment —
/// just choose (or add) a delivery address and confirm.
class GiftClaimScreen extends ConsumerStatefulWidget {
  const GiftClaimScreen({super.key});

  @override
  ConsumerState<GiftClaimScreen> createState() => _GiftClaimScreenState();
}

class _GiftClaimScreenState extends ConsumerState<GiftClaimScreen> {
  int? _selectedAddressId;
  bool _submitting = false;

  void _autoSelect(List<dynamic> addresses) {
    if (_selectedAddressId == null && addresses.isNotEmpty) {
      final def = addresses.firstWhere((a) => a['is_default'] == true,
          orElse: () => addresses.first);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedAddressId = def['id'] as int);
      });
    }
  }

  Future<void> _addAddress() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddAddressSheet(),
    );
    if (added == true) ref.invalidate(addressesProvider);
  }

  Future<void> _confirm() async {
    if (_selectedAddressId == null) {
      _snack('Please select a delivery address', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      final deviceId = await DeviceIdService.get();
      await ApiService.post(ApiConstants.giftClaim, data: {
        'device_id': deviceId,
        'address_id': _selectedAddressId,
      });
      ref.invalidate(giftOfferProvider);
      ref.invalidate(myGiftsProvider);
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => const _SuccessDialog(),
      );
      if (mounted) context.go('/profile/gifts');
    } on DioException catch (e) {
      _snack(apiErrorMessage(e), error: true);
      // e.g. "already claimed": refresh so the home button disappears.
      if (e.response?.statusCode == 409) ref.invalidate(giftOfferProvider);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final offerAsync = ref.watch(giftOfferProvider);
    final addrsAsync = ref.watch(addressesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Claim your free gift')),
      body: offerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
        data: (offer) {
          if (offer == null) {
            return EmptyState(
              emoji: '🎁',
              title: 'No gift to claim',
              subtitle:
                  'The free gift is either already claimed or not available right now.',
              buttonLabel: 'Go home',
              onButton: () => context.go('/'),
            );
          }
          return Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _GiftSummary(offer: offer),
                const SizedBox(height: 16),
                const Text('📍 Delivery address',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                addrsAsync.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Text('$e',
                      style: const TextStyle(color: AppColors.error)),
                  data: (addresses) {
                    _autoSelect(addresses);
                    return Column(children: [
                      if (addresses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No saved addresses yet.',
                              style:
                                  TextStyle(color: AppColors.textSecondary)),
                        ),
                      ...addresses.map((a) => _AddressTile(
                            addr: a,
                            selected: _selectedAddressId == a['id'],
                            onTap: () =>
                                setState(() => _selectedAddressId = a['id']),
                          )),
                      const SizedBox(height: 6),
                      AppOutlinedButton(
                        label: '+ Add New Address',
                        onTap: _addAddress,
                        height: 42,
                      ),
                    ]);
                  },
                ),
              ]),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: GradientButton(
                  label: 'Confirm & claim gift',
                  loading: _submitting,
                  onTap: _confirm,
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _GiftSummary extends StatelessWidget {
  final Map<String, dynamic> offer;
  const _GiftSummary({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(offer['banner'] as String,
              width: 84,
              height: 84,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  width: 84,
                  height: 84,
                  color: AppColors.primaryLight,
                  alignment: Alignment.center,
                  child: const Text('🎁', style: TextStyle(fontSize: 32)))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(offer['gift_name'] as String? ?? 'Free gift',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('FREE · ₹0',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F46))),
            ),
            const SizedBox(height: 4),
            const Text('Free delivery, no payment needed',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}

class _AddressTile extends StatelessWidget {
  final dynamic addr;
  final bool selected;
  final VoidCallback onTap;
  const _AddressTile(
      {required this.addr, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.textLight),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${addr['full_name'] ?? ''}  ·  ${addr['phone'] ?? ''}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 3),
              Text(addr['full_address'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog();

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Center(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🎉', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              const Text('Gift claimed!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text(
                  'We will confirm it shortly and deliver it to your address.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Text('View my gifts'),
                ),
              ),
            ]),
          ),
        ),
      ),
      const Positioned.fill(child: BurstEffect()),
    ]);
  }
}
