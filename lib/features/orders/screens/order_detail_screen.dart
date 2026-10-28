import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';

final orderDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, number) async {
  final res = await ApiService.get('/orders/$number');
  final body = res.data;
  // API returns flat map directly (no 'data' wrapper for single order)
  if (body is Map<String, dynamic>) return body;
  if (body['data'] != null) return body['data'] as Map<String, dynamic>;
  return body as Map<String, dynamic>;
});

class OrderDetailScreen extends ConsumerWidget {
  final String orderNumber;
  const OrderDetailScreen({super.key, required this.orderNumber});

  void _goBack(BuildContext context) {
    context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderDetailProvider(orderNumber));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => _goBack(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text('Order #$orderNumber',
            style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: AppColors.textPrimary)),
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.refresh(orderDetailProvider(orderNumber).future),
          child: ListView(children: [
            SizedBox(height: 300,
              child: Center(child: Text('Error: $e'))),
          ]),
        ),
        data: (data) {
          final status = data['status'] ?? 'pending';
          final items = data['items'] as List? ?? [];
          final address = data['address'] as Map?;
          final logs = data['status_logs'] as List? ?? [];
          final exchange = data['exchange_request'] as Map?;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.refresh(orderDetailProvider(orderNumber).future),
            child: ListView(padding: const EdgeInsets.all(16), children: [
            // Status card
            _StatusCard(
                status: status,
                statusLabel: data['status_label'] ?? status,
                orderNumber: orderNumber,
                createdAt: data['created_at'] ?? '',
                trackingNumber: data['tracking_number'],
                courierName: data['courier_name']),
            const SizedBox(height: 16),

            // Tracking timeline
            _TrackingTimeline(status: status, logs: logs),
            const SizedBox(height: 16),

            // Items + price breakdown
            _card(
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Items Ordered',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...items.map((item) => _ItemRow(item: item)),
              const Divider(height: 20),
              _priceRow('Subtotal', data['subtotal']),
              if ((data['discount'] as num? ?? 0) > 0)
                _priceRow('Coupon Discount', data['discount'],
                    prefix: '−', color: AppColors.success),
              if ((data['exchange_discount'] as num? ?? 0) > 0)
                _priceRow('🔄 Exchange Discount', data['exchange_discount'],
                    prefix: '−', color: Colors.orange),
              if ((data['loyalty_discount'] as num? ?? 0) > 0)
                _priceRow(
                  '🌟 Loyalty Points (${data['loyalty_points_used'] ?? 0} pts)',
                  data['loyalty_discount'],
                  prefix: '−', color: Colors.green.shade700,
                ),
              _priceRow('Shipping', data['shipping_charge']),
              const Divider(height: 12),
              _priceRow('Total Paid', data['total'], bold: true),
              if (data['refund_amount'] != null)
                _priceRow('Refunded', data['refund_amount'],
                    prefix: '−', color: Colors.grey.shade600),
            ])),
            const SizedBox(height: 16),

            // Address
            if (address != null)
              _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Delivery Address',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(address['full_name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(address['phone'] ?? '',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    Text(address['full_address'] ?? '',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ])),
            const SizedBox(height: 16),

            // Payment
            _card(
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Payment',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _infoRow('Method',
                  (data['payment_method'] ?? '').toString().toUpperCase()),
              _infoRow('Status', data['payment_status'] ?? '',
                  valueColor: data['payment_status'] == 'paid'
                      ? AppColors.success
                      : data['payment_status'] == 'refunded'
                          ? Colors.grey
                          : AppColors.warning),
            ])),

            // Cancel Order (only for pending/confirmed)
            if (status == 'pending' || status == 'confirmed') ...[
              const SizedBox(height: 16),
              _CancelOrderSection(
                orderNumber: orderNumber,
                onCancelled: () {
                  ref.invalidate(orderDetailProvider(orderNumber));
                },
              ),
            ],

            // Exchange
            if (exchange != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('🔄 Exchange Request',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.deepOrange)),
                        const Spacer(),
                        _StatusPill(status: exchange['status'] ?? 'pending'),
                      ]),
                      const SizedBox(height: 12),

                      // Product the exchange was applied to
                      if (exchange['exchange_for_product'] != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: Colors.orange.shade100)),
                          child: Row(children: [
                            if (exchange['exchange_for_product']['thumbnail'] !=
                                null)
                              AppNetworkImage(
                                  url: exchange['exchange_for_product']
                                      ['thumbnail'],
                                  width: 40,
                                  height: 40,
                                  borderRadius: BorderRadius.circular(8),
                                  fit: BoxFit.contain),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  const Text('Applied on',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary)),
                                  Text(
                                      exchange['exchange_for_product']
                                              ['name'] ??
                                          '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13),
                                      maxLines: 2),
                                  Text(
                                      '₹${_fmtNum(exchange['exchange_for_product']['price'])}',
                                      style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12)),
                                ])),
                          ]),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Old phone info
                      _infoRow('Old Phone',
                          '${exchange['brand']} ${exchange['model']}'),
                      _infoRow(
                          'Condition',
                          exchange['condition_label'] ??
                              exchange['condition'] ??
                              ''),
                      _infoRow('IMEI', exchange['imei'] ?? ''),
                      const Divider(height: 14),
                      _infoRow('Estimated Value',
                          '₹${_fmtNum(exchange['estimated_value'])}',
                          valueColor: Colors.orange.shade800),
                      if (exchange['approved_value'] != null)
                        _infoRow('Approved Value',
                            '₹${_fmtNum(exchange['approved_value'])}',
                            valueColor: AppColors.success),
                      _infoRow('Deducted from Total',
                          '−₹${_fmtNum(data['exchange_discount'])}',
                          valueColor: Colors.orange),
                    ]),
              ),
            ],

            // Refund info
            if (data['refund'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Text('💸', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text('Refund Processed',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 10),
                      _infoRow('Amount Refunded',
                          '₹${_fmtNum(data['refund']['amount'])}',
                          valueColor: AppColors.success),
                      _infoRow('Reason', data['refund']['reason'] ?? ''),
                      if (data['refund']['transaction_id'] != null)
                        _infoRow(
                            'Reference ID', data['refund']['transaction_id']),
                    ]),
              ),
            ] else if (data['refund_reason'] != null &&
                data['refunded_at'] == null) ...[
              // Refund requested, pending admin
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.yellow.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.yellow.shade300)),
                child: const Row(children: [
                  Text('⏳', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Refund Request Submitted',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14)),
                        SizedBox(height: 3),
                        Text(
                            'Our team is reviewing your request. Allow 3–5 business days.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ])),
                ]),
              ),
            ] else if (status == 'delivered') ...[
              // Show refund claim button if within 7 days
              const SizedBox(height: 16),
              _RefundClaimSection(
                  orderNumber: orderNumber,
                  deliveredAt: data['delivered_at'],
                  onRefundSubmitted: () =>
                      ref.invalidate(orderDetailProvider(orderNumber))),
            ],

            const SizedBox(height: 80),
          ]),  // ListView
          );   // RefreshIndicator
        },
      ),
    ); // Scaffold
  }

  String _fmtNum(dynamic v) {
    final d = (v as num? ?? 0).toDouble();
    return d
        .toInt()
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  Widget _priceRow(String label, dynamic value,
      {String prefix = '', Color? color, bool bold = false}) {
    final v = (value as num? ?? 0)
        .toInt()
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text('$prefix₹$v',
              style: TextStyle(
                  fontSize: bold ? 16 : 13,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                  color: color ??
                      (bold ? AppColors.primary : AppColors.textPrimary))),
        ]));
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textPrimary)),
        ]));
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: child,
      );
}

class _StatusCard extends StatelessWidget {
  final String status, statusLabel, orderNumber, createdAt;
  final String? trackingNumber, courierName;
  const _StatusCard(
      {required this.status,
      required this.statusLabel,
      required this.orderNumber,
      required this.createdAt,
      this.trackingNumber,
      this.courierName});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Order Number',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Text(orderNumber,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(_formatDate(createdAt),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ]),
          const Spacer(),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: color))),
        ]),
        if (trackingNumber != null) ...[
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.local_shipping_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(courierName ?? '',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                  Text(trackingNumber!,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark)),
                ]),
              ])),
        ],
      ]),
    );
  }

  Color _statusColor(String s) => switch (s) {
        'delivered' => AppColors.success,
        'cancelled' => AppColors.error,
        'shipped' || 'out_for_delivery' => AppColors.primary,
        'confirmed' => AppColors.info,
        _ => AppColors.warning,
      };

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _TrackingTimeline extends StatelessWidget {
  final String status;
  final List logs;
  const _TrackingTimeline({required this.status, required this.logs});

  static const _steps = [
    ('pending', '🛍️', 'Order Placed', 'Your order has been received'),
    ('confirmed', '✅', 'Confirmed', 'Payment verified and confirmed'),
    ('processing', '⚙️', 'Processing', 'Your items are being packed'),
    ('shipped', '📦', 'Shipped', 'Handed over to courier'),
    ('out_for_delivery', '🚚', 'Out for Delivery', 'On the way to you!'),
    ('delivered', '🎉', 'Delivered', 'Enjoy your new phone!'),
  ];

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withOpacity(0.3))),
          child: const Row(children: [
            Text('❌', style: TextStyle(fontSize: 24)),
            SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order Cancelled',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.error)),
              Text('This order has been cancelled',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ]));
    }

    final statusOrder = _steps.map((s) => s.$1).toList();
    final currentIdx = statusOrder.indexOf(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(children: [
        const Align(
            alignment: Alignment.centerLeft,
            child: Text('Order Progress',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
        const SizedBox(height: 16),
        ..._steps.asMap().entries.map((entry) {
          final idx = entry.key;
          final step = entry.value;
          final done = idx <= currentIdx;
          final curr = idx == currentIdx;

          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: done ? AppColors.primary : AppColors.borderLight,
                    shape: BoxShape.circle,
                    boxShadow: curr
                        ? [
                            BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2)
                          ]
                        : null,
                  ),
                  child: Center(
                      child:
                          Text(step.$2, style: const TextStyle(fontSize: 16)))),
              if (idx < _steps.length - 1)
                Container(
                    width: 2,
                    height: 32,
                    color: done && idx < currentIdx
                        ? AppColors.primary
                        : AppColors.borderLight),
            ]),
            const SizedBox(width: 12),
            Expanded(
                child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.$3,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: done
                                ? AppColors.textPrimary
                                : AppColors.textLight)),
                    Text(step.$4,
                        style: TextStyle(
                            fontSize: 11,
                            color: done
                                ? AppColors.textSecondary
                                : AppColors.textLight)),
                  ]),
            )),
          ]);
        }),
      ]),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final dynamic item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final variantDetails = item['variant_details'] as String?;
    final parts = variantDetails?.split(' | ') ?? [];

    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppNetworkImage(
              url: item['thumbnail'],
              width: 52,
              height: 52,
              fit: BoxFit.contain,
              borderRadius: BorderRadius.circular(8)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item['product_name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                if (parts.isNotEmpty)
                  Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: parts.map((p) {
                        final isColor = p.startsWith('Color:');
                        final isRam = p.startsWith('RAM:');
                        final isStorage = p.startsWith('Storage:');
                        return VariantChip(
                            label: p,
                            bgColor: isColor
                                ? AppColors.primaryLight
                                : isRam
                                    ? const Color(0xFFDEF7EC)
                                    : isStorage
                                        ? const Color(0xFFFEF3C7)
                                        : AppColors.borderLight,
                            textColor: isColor
                                ? AppColors.primary
                                : isRam
                                    ? AppColors.success
                                    : isStorage
                                        ? const Color(0xFF92400E)
                                        : AppColors.textSecondary);
                      }).toList()),
                Text('Qty: ${item['quantity']}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ])),
          Text('₹${_fmt((item['subtotal'] as num).toDouble())}',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ]));
  }

  String _fmt(double v) => v
      .toInt()
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      'verified' => AppColors.info,
      _ => AppColors.warning,
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Text(status.toUpperCase(),
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)));
  }
}

// ── Cancel Order Section ──────────────────────────────────────────────────────
class _CancelOrderSection extends ConsumerStatefulWidget {
  final String orderNumber;
  final VoidCallback onCancelled;

  const _CancelOrderSection({
    required this.orderNumber,
    required this.onCancelled,
  });

  @override
  ConsumerState<_CancelOrderSection> createState() =>
      _CancelOrderSectionState();
}

class _CancelOrderSectionState extends ConsumerState<_CancelOrderSection> {
  bool _loading = false;
  bool _expanded = false;
  String _selectedReason = 'Changed my mind';

  static const _reasons = [
    'Changed my mind',
    'Found a better price elsewhere',
    'Ordered by mistake',
    'Delivery time too long',
    'Payment issue',
    'Other',
  ];

  Future<void> _cancel() async {
    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('❌', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Text('Cancel Order?',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ]),
        content: const Text(
          'Are you sure you want to cancel this order? '
          'If you already paid, a refund will be initiated automatically.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Go Back',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Yes, Cancel',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await ApiService.post(
        ApiConstants.orderCancel(widget.orderNumber),
        data: {'reason': _selectedReason},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Order cancelled successfully.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ));
        widget.onCancelled();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('❌', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Text('Cancel Order',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.error)),
        ]),
        const SizedBox(height: 6),
        const Text(
          'You can cancel this order while it\'s still pending or confirmed. '
          'Paid orders will be refunded automatically.',
          style: TextStyle(
              fontSize: 12, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        if (!_expanded)
          GestureDetector(
            onTap: () => setState(() => _expanded = true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  border: Border.all(color: AppColors.error),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white),
              child: const Center(
                child: Text('Cancel This Order',
                    style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ),
          )
        else ...[
          // Reason dropdown
          const Text('Reason for cancellation',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedReason,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary),
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600),
                items: _reasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedReason = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => _expanded = false),
                child: const Text('Go Back',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                            color: AppColors.error, strokeWidth: 2.5),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _cancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Confirm Cancel',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter')),
                    ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _RefundClaimSection extends ConsumerStatefulWidget {
  final String orderNumber;
  final String? deliveredAt;
  final VoidCallback onRefundSubmitted;

  const _RefundClaimSection({
    required this.orderNumber,
    required this.deliveredAt,
    required this.onRefundSubmitted,
  });

  @override
  ConsumerState<_RefundClaimSection> createState() =>
      _RefundClaimSectionState();
}

class _RefundClaimSectionState extends ConsumerState<_RefundClaimSection> {
  final _reasonCtrl = TextEditingController();
  bool _loading = false;
  bool _expanded = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  int get _daysLeft {
    if (widget.deliveredAt == null) return 0;
    try {
      final delivered = DateTime.parse(widget.deliveredAt!);
      final diff = DateTime.now().difference(delivered).inDays;
      return (7 - diff).clamp(0, 7);
    } catch (_) {
      return 0;
    }
  }

  Future<void> _submit() async {
    if (_reasonCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ApiService.post(ApiConstants.orderRefundClaim(widget.orderNumber),
          data: {'reason': _reasonCtrl.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Refund request submitted! We\'ll process it within 3–5 days.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 4),
        ));
        widget.onRefundSubmitted();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysLeft;
    if (days <= 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: const Row(children: [
          Text('⏰', style: TextStyle(fontSize: 18)),
          SizedBox(width: 10),
          Expanded(
              child: Text(
            'Refund window has expired (7 days from delivery).',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          )),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🔄', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Text('Request a Refund',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade200)),
            child: Text('$days day${days == 1 ? '' : 's'} left',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade700)),
          ),
        ]),
        const SizedBox(height: 6),
        const Text(
          'Claim within 7 days of delivery. We\'ll process your request in 3–5 business days.',
          style: TextStyle(
              fontSize: 12, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        if (!_expanded)
          GestureDetector(
            onTap: () => setState(() => _expanded = true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('Request Refund',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ),
          )
        else ...[
          TextFormField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText:
                  'Describe your issue (e.g. damaged product, wrong item received)...',
              hintStyle: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextButton(
                onPressed: () => setState(() => _expanded = false),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: GradientButton(
                label: 'Submit Request',
                onTap: _submit,
                loading: _loading,
                height: 44,
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}
