import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

// Currently selected date range filter — null means "all time"
final orderDateFilterProvider = StateProvider.autoDispose<DateTimeRange?>((ref) => null);

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// autoDispose = re-fetches every time the screen is opened.
// Watches the date filter, so picking a new range automatically re-fetches.
final ordersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final range = ref.watch(orderDateFilterProvider);
  final params = <String, dynamic>{'per_page': 50};
  if (range != null) {
    params['from'] = _isoDate(range.start);
    params['to']   = _isoDate(range.end);
  }
  final res  = await ApiService.get(ApiConstants.orders, params: params);
  final body = res.data;
  if (body is List)              return body;
  if (body['data'] is List)      return body['data'] as List;
  return [];
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  Future<void> _pickFilter(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8, left: 4),
                child: Text('Filter by date',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              )),
          _FilterTile(label: 'All time', onTap: () => Navigator.pop(context, 'all')),
          _FilterTile(label: 'Last 30 days', onTap: () => Navigator.pop(context, '30d')),
          _FilterTile(label: 'Last 3 months', onTap: () => Navigator.pop(context, '3m')),
          _FilterTile(label: 'Last 6 months', onTap: () => Navigator.pop(context, '6m')),
          _FilterTile(label: 'This year', onTap: () => Navigator.pop(context, 'year')),
          _FilterTile(label: 'Custom range…', onTap: () => Navigator.pop(context, 'custom')),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return;

    switch (choice) {
      case 'all':
        ref.read(orderDateFilterProvider.notifier).state = null;
        break;
      case '30d':
        ref.read(orderDateFilterProvider.notifier).state =
            DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
        break;
      case '3m':
        ref.read(orderDateFilterProvider.notifier).state =
            DateTimeRange(start: DateTime(now.year, now.month - 3, now.day), end: now);
        break;
      case '6m':
        ref.read(orderDateFilterProvider.notifier).state =
            DateTimeRange(start: DateTime(now.year, now.month - 6, now.day), end: now);
        break;
      case 'year':
        ref.read(orderDateFilterProvider.notifier).state =
            DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
        break;
      case 'custom':
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 5),
          lastDate: now,
          initialDateRange: ref.read(orderDateFilterProvider),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary)),
            child: child!,
          ),
        );
        if (picked != null) {
          ref.read(orderDateFilterProvider.notifier).state = picked;
        }
        break;
    }
  }

  String _filterLabel(DateTimeRange range) {
    String fmt(DateTime d) {
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    }
    return '${fmt(range.start)} – ${fmt(range.end)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final activeFilter = ref.watch(orderDateFilterProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (_) => context.go('/'),
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface, elevation: 0,
        title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        actions: [
          IconButton(
            onPressed: () => _pickFilter(context, ref),
            icon: Icon(Icons.filter_list,
                color: activeFilter != null ? AppColors.primary : AppColors.textPrimary),
          ),
        ],
      ),
      body: Column(children: [
        if (activeFilter != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.event, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_filterLabel(activeFilter),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ),
                    GestureDetector(
                      onTap: () => ref.read(orderDateFilterProvider.notifier).state = null,
                      child: const Icon(Icons.close, size: 16, color: AppColors.primary),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        Expanded(
          child: ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.refresh(ordersProvider.future),
              child: ListView(children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.4,
                  child: Center(child: Text('Error: $e'))),
              ]),
            ),
            data: (orders) => RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.refresh(ordersProvider.future),
              child: orders.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 200),
                      EmptyState(emoji: activeFilter != null ? '🗓️' : '📦',
                          title: activeFilter != null ? 'No orders in this range' : 'No orders yet',
                          subtitle: activeFilter != null
                              ? 'Try a different date range'
                              : 'Start shopping and your orders will appear here'),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: orders.length,
                      itemBuilder: (_, i) => _OrderCard(order: orders[i]),
                    ),
            ),
          ),
        ),
      ]),
    ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FilterTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final dynamic order;
  const _OrderCard({required this.order});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  bool _downloadingInvoice = false;

  Future<void> _downloadInvoice() async {
    setState(() => _downloadingInvoice = true);
    try {
      final orderNumber = widget.order['order_number'] as String;
      final res = await ApiService.get(ApiConstants.orderInvoiceLink(orderNumber));
      final url = res.data['url'] as String;
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open the invoice. Please try again.'),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      if (mounted) {
        final msg = e is DioException ? apiErrorMessage(e) : 'Could not download the invoice.';
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _downloadingInvoice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order    = widget.order;
    final status   = order['status'] ?? 'pending';
    final color    = _statusColor(status);
    final items    = order['items'] as List? ?? [];

    return GestureDetector(
      onTap: () => context.push('/orders/${order['order_number']}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: Column(children: [
          // Header
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.borderLight,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order['order_number'], style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13)),
                Text(_formatDate(order['created_at'] ?? ''),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(order['status_label'] ?? status,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color))),
            ])),

          // Items preview — thumbnail + name + variant/color
          Padding(padding: const EdgeInsets.all(12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...items.take(3).map((item) {
                final variantDetails = item['variant_details'] as String?;
                final parts = variantDetails?.split(' | ')
                    .where((p) => p.trim().isNotEmpty).toList() ?? [];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    AppNetworkImage(
                        url: item['thumbnail'],
                        width: 48, height: 48,
                        borderRadius: BorderRadius.circular(8),
                        fit: BoxFit.contain),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['product_name'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        if (parts.isNotEmpty)
                          Wrap(spacing: 4, runSpacing: 2,
                            children: parts.map((p) {
                              final isColor   = p.startsWith('Color:');
                              final isRam     = p.startsWith('RAM:');
                              final isStorage = p.startsWith('Storage:');
                              return Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isColor
                                      ? AppColors.primaryLight
                                      : isRam
                                          ? const Color(0xFFDEF7EC)
                                          : isStorage
                                              ? const Color(0xFFFEF3C7)
                                              : AppColors.borderLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(p,
                                    style: TextStyle(
                                        fontSize: 10, fontWeight: FontWeight.w700,
                                        color: isColor
                                            ? AppColors.primary
                                            : isRam
                                                ? AppColors.success
                                                : isStorage
                                                    ? const Color(0xFF92400E)
                                                    : AppColors.textSecondary)),
                              );
                            }).toList()),
                        Text('Qty: ${item['quantity']}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    )),
                  ]),
                );
              }),
              if (items.length > 3)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('+${items.length - 3} more item${items.length - 3 > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
              const SizedBox(height: 4),
              Row(children: [
                const Text('Order Total:',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 6),
                Text('₹${_fmt((order['total'] as num).toDouble())}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: AppOutlinedButton(label: 'View Details', height: 36,
                  onTap: () => context.push('/orders/${order['order_number']}'))),
                if (status == 'delivered') ...[
                  const SizedBox(width: 8),
                  Expanded(child: GradientButton(
                    label: _downloadingInvoice ? 'Please wait…' : '📄 Invoice',
                    height: 36,
                    loading: _downloadingInvoice,
                    onTap: _downloadingInvoice ? null : _downloadInvoice,
                  )),
                ] else if (status != 'cancelled' && status != 'refunded') ...[
                  const SizedBox(width: 8),
                  Expanded(child: GradientButton(label: 'Track Order', height: 36,
                    onTap: () => context.push('/orders/${order['order_number']}'))),
                ],
              ]),
            ],
          )),
        ]),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'delivered' => AppColors.success,
      'cancelled' => AppColors.error,
      'shipped' || 'out_for_delivery' => AppColors.primary,
      'confirmed' => AppColors.info,
      _ => AppColors.warning,
    };
  }

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) { return iso; }
  }
}
