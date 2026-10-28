import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/common_widgets.dart';

final myGiftsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await ApiService.get(ApiConstants.giftsMine);
  return (res.data['claims'] as List?) ?? [];
});

/// Customer profile → "My Claimed Gifts". Deliberately separate from
/// "My Orders": a free gift is not an order.
class MyGiftsScreen extends ConsumerWidget {
  const MyGiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myGiftsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Claimed Gifts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile'),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          emoji: '⚠️',
          title: 'Could not load gifts',
          subtitle: 'Please check your connection and try again.',
          buttonLabel: 'Retry',
          onButton: () => ref.invalidate(myGiftsProvider),
        ),
        data: (claims) => claims.isEmpty
            ? const EmptyState(
                emoji: '🎁',
                title: 'No gifts claimed yet',
                subtitle: 'Gifts you claim will show up here.')
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(myGiftsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: claims.length,
                  itemBuilder: (_, i) => _GiftCard(c: claims[i]),
                ),
              ),
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  final dynamic c;
  const _GiftCard({required this.c});

  @override
  Widget build(BuildContext context) {
    final confirmed = c['status'] == 'confirmed';
    final date = DateTime.tryParse(c['claimed_at'] ?? '')?.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🎁', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(c['gift_name'] ?? 'Free gift',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: confirmed
                  ? const Color(0xFFDBEAFE)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(confirmed ? 'Confirmed' : 'Pending',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: confirmed
                        ? const Color(0xFF1E40AF)
                        : const Color(0xFF92400E))),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
            '${c['claim_number']}${date != null ? '  ·  ${date.day}/${date.month}/${date.year}' : ''}',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        const Divider(height: 20),
        const Text('Delivering to',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight)),
        const SizedBox(height: 2),
        Text('${c['ship_name'] ?? ''}  ·  ${c['ship_phone'] ?? ''}',
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        Text(c['address'] ?? '',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Text(
            confirmed
                ? 'Your gift is confirmed and will be delivered soon.'
                : 'Awaiting confirmation from the store.',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ]),
    );
  }
}
