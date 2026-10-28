import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../cart/providers/cart_provider.dart';
import '../../auth/providers/auth_provider.dart';

final shippingZonesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ApiService.get(ApiConstants.shippingZones);
  return {
    'zones':         res.data['shipping_zones'] as List,
    'cod_available': res.data['cod_available'] as bool? ?? true,
  };
});

final addressesProvider = FutureProvider<List<dynamic>>((ref) async {
  final res = await ApiService.get(ApiConstants.addresses);
  // addresses returns ResourceCollection — might be wrapped in 'data'
  final body = res.data;
  if (body is List) return body;
  if (body['data'] != null) return body['data'] as List;
  return [];
});

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int? _selectedAddressId;
  int? _selectedZoneId;
  String? _selectedZoneName;
  double _zoneRate       = 0;
  String _paymentMethod      = 'cod';
  bool   _placing            = false;
  bool   _redeemLoyalty      = false;
  int    _loyaltyPointsToUse = 0;
  double _loyaltyDiscount    = 0;
  bool   _loyaltyLoading     = false;
  late   Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR,   _onPaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // Auto-select: default address + metro zone
  void _autoSelect(List<dynamic> addresses, List<dynamic> zones) {
    if (_selectedAddressId == null && addresses.isNotEmpty) {
      final def = addresses.firstWhere(
        (a) => a['is_default'] == true,
        orElse: () => addresses.first,
      );
      setState(() => _selectedAddressId = def['id']);
    }

    if (_selectedZoneId == null && zones.isNotEmpty) {
      // Prefer metro zone, else first zone
      final metro = zones.firstWhere(
        (z) => (z['name'] as String).toLowerCase().contains('metro'),
        orElse: () => zones.first,
      );
      _selectZone(metro);
    }
  }

  void _selectZone(Map<String, dynamic> zone) {
    final rate     = (zone['rate'] as num).toDouble();
    final freeAbove= zone['free_above'] != null ? (zone['free_above'] as num).toDouble() : null;
    final subtotal = ref.read(cartProvider).subtotal;
    final isFree   = freeAbove != null && subtotal >= freeAbove;

    setState(() {
      _selectedZoneId   = zone['id'];
      _selectedZoneName = zone['name'];
      _zoneRate         = isFree ? 0 : rate;
    });
  }

  Future<void> _placeOrder() async {
    if (_selectedAddressId == null) {
      _snack('Please select a delivery address', isError: true); return;
    }
    if (_selectedZoneId == null) {
      _snack('Please select a shipping method', isError: true); return;
    }

    setState(() => _placing = true);
    try {
      final res = await ApiService.post(ApiConstants.orders, data: {
        'address_id':              _selectedAddressId,
        'shipping_zone_id':        _selectedZoneId,
        'payment_method':          _paymentMethod,
        'loyalty_points_to_redeem': _redeemLoyalty ? _loyaltyPointsToUse : 0,
      });

      final data     = res.data as Map<String, dynamic>;
      final orderNum = data['order_number'] as String;
      final rzData   = data['razorpay'] as Map<String, dynamic>?;

      if (_paymentMethod == 'razorpay' && rzData != null) {
        _openRazorpay(rzData, orderNum);
      } else {
        // Refresh cart count
        ref.read(cartProvider.notifier).loadCart();
        if (mounted) {
          context.push('/orders/$orderNum');
          _snack('Order placed successfully! 🎉');
        }
      }
    } catch (e) {
      setState(() => _placing = false);
      final msg = e is DioException ? apiErrorMessage(e) : e.toString();
      _snack(msg, isError: true);
    }
  }

  void _openRazorpay(Map<String, dynamic> data, String orderNum) {
    _razorpay.open({
      'key':        data['key'],
      'amount':     data['amount'],
      'currency':   'INR',
      'order_id':   data['order_id'],
      'name':       'Harahori Telecom LLP',
      'description': 'Order #$orderNum',
      'image':      '${ApiConstants.webBaseUrl}/images/harahori.jpg',
      'theme':      {'color': '#7C3AED'},
    });
  }

  void _onPaymentSuccess(PaymentSuccessResponse res) async {
    try {
      await ApiService.post(ApiConstants.razorpayVerify, data: {
        'order_number':        _lastOrderNum ?? '',
        'razorpay_order_id':   res.orderId,
        'razorpay_payment_id': res.paymentId,
        'razorpay_signature':  res.signature,
      });
      ref.read(cartProvider.notifier).loadCart();
      if (mounted) {
        setState(() => _placing = false);
        context.push('/orders/${_lastOrderNum ?? ''}');
        _snack('Payment successful! 🎉');
      }
    } catch (e) {
      setState(() => _placing = false);
      final msg = e is DioException ? apiErrorMessage(e) : 'Payment verification failed. If money was deducted, please contact support with your order number.';
      _snack(msg, isError: true);
    }
  }

  void _onPaymentError(PaymentFailureResponse res) {
    setState(() => _placing = false);
    _snack('Payment failed: ${res.message}', isError: true);
  }

  String? _lastOrderNum;

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  Future<void> _openAddAddressSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddAddressSheet(),
    );
    if (added == true) {
      ref.invalidate(addressesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart       = ref.watch(cartProvider);
    final zonesAsync = ref.watch(shippingZonesProvider);
    final addrsAsync = ref.watch(addressesProvider);

    if (!ref.watch(authProvider).isLoggedIn) {
      return Scaffold(body: EmptyState(
        emoji: '🔒', title: 'Login required',
        subtitle: 'Please sign in to checkout',
        buttonLabel: 'Login', onButton: () => context.go('/login'),
      ));
    }

    // Auto-select defaults once both are loaded
    if (addrsAsync.hasValue && zonesAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSelect(addrsAsync.value!, zonesAsync.value!['zones'] as List);
        final codAvailable = zonesAsync.value!['cod_available'] as bool;
        if (!codAvailable && _paymentMethod == 'cod') {
          setState(() => _paymentMethod = 'razorpay');
        }
      });
    }

    final discount         = cart.discount;
    final exchangeDiscount = cart.exchangeDiscount;
    final approxTotal      = (cart.subtotal - discount - exchangeDiscount - _loyaltyDiscount + _zoneRate).clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: AppColors.surface,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: const Text('Checkout',
            style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        // ── DELIVERY ADDRESS ────────────────────────────────────────────
        _SectionCard(title: '📍 Delivery Address',
          child: addrsAsync.when(
            loading: () => const _LoadingRow(),
            error:   (e, _) => Text('$e', style: const TextStyle(color: AppColors.error)),
            data:    (addresses) => addresses.isEmpty
                ? _NoAddresses(onAdd: _openAddAddressSheet)
                : Column(children: [
                    ...addresses.map((addr) {
                      final sel = _selectedAddressId == addr['id'];
                      return _SelectableRow(
                        selected: sel,
                        onTap: () => setState(() => _selectedAddressId = addr['id']),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(addr['full_name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(width: 8),
                            Text(addr['phone'] ?? '',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            if (addr['is_default'] == true) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Text('Default',
                                    style: TextStyle(fontSize: 10,
                                        color: AppColors.primary, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ]),
                          const SizedBox(height: 3),
                          Text(addr['full_address'] ?? '',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 2),
                        ]),
                      );
                    }),
                    const SizedBox(height: 4),
                    AppOutlinedButton(
                      label: '+ Add New Address',
                      onTap: _openAddAddressSheet,
                      height: 38,
                    ),
                  ]),
          )),

        const SizedBox(height: 12),

        // ── SHIPPING METHOD ─────────────────────────────────────────────
        _SectionCard(title: '🚚 Shipping Method',
          child: zonesAsync.when(
            loading: () => const _LoadingRow(),
            error:   (e, _) => Text('$e', style: const TextStyle(color: AppColors.error)),
            data:    (result) => Column(children: (result['zones'] as List).map((zone) {
                final sel       = _selectedZoneId == zone['id'];
                final rate      = (zone['rate'] as num).toDouble();
                final freeAbove = zone['free_above'] != null
                    ? (zone['free_above'] as num).toDouble() : null;
                final isFree    = freeAbove != null && cart.subtotal >= freeAbove;
                final isMetro   = (zone['name'] as String).toLowerCase().contains('metro');

                return _SelectableRow(
                  selected: sel,
                  onTap: () => _selectZone(zone as Map<String, dynamic>),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(zone['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        if (isMetro) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.shade200)),
                            child: Text('Popular',
                                style: TextStyle(fontSize: 10,
                                    color: Colors.blue.shade700, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ]),
                      Text('${zone['estimated_days']} business days',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      if (freeAbove != null)
                        Text('Free above ₹${freeAbove.toInt()}',
                            style: const TextStyle(fontSize: 11, color: AppColors.success,
                                fontWeight: FontWeight.w600)),
                    ])),
                    Text(
                      isFree ? 'FREE' : (rate == 0 ? 'FREE' : '₹${rate.toInt()}'),
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 15,
                          color: isFree || rate == 0 ? AppColors.success : AppColors.textPrimary),
                    ),
                  ]),
                );
              }).toList()),
          )),

        const SizedBox(height: 12),

        // ── LOYALTY POINTS ──────────────────────────────────────────────
        Consumer(builder: (context, ref, _) {
          final user = ref.watch(authProvider).user;
          if (user == null || user.loyaltyPoints <= 0) return const SizedBox.shrink();
          return Column(children: [
            _SectionCard(
              title: '🌟 Loyalty Points',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('You have ${user.loyaltyPoints} points',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text('Worth ₹${(user.loyaltyPoints * 0.25).toStringAsFixed(2)} at checkout',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ])),
                  Switch(
                    value: _redeemLoyalty,
                    activeColor: AppColors.primary,
                    onChanged: (val) async {
                      setState(() { _redeemLoyalty = val; });
                      if (val) {
                        setState(() => _loyaltyLoading = true);
                        try {
                          final res = await ApiService.post(
                            ApiConstants.loyaltyPreview,
                            data: {'points_to_redeem': user.loyaltyPoints},
                          );
                          final data = res.data as Map<String, dynamic>;
                          setState(() {
                            _loyaltyPointsToUse = data['points_to_redeem'] as int;
                            _loyaltyDiscount    = (data['discount_amount'] as num).toDouble();
                            _loyaltyLoading     = false;
                          });
                        } catch (_) {
                          setState(() { _redeemLoyalty = false; _loyaltyLoading = false; });
                        }
                      } else {
                        setState(() { _loyaltyDiscount = 0; _loyaltyPointsToUse = 0; });
                      }
                    },
                  ),
                ]),
                if (_redeemLoyalty && _loyaltyLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(color: AppColors.primary),
                  ),
                if (_redeemLoyalty && !_loyaltyLoading && _loyaltyDiscount > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Using $_loyaltyPointsToUse points — saving ₹${_loyaltyDiscount.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 13, color: Colors.green.shade800,
                            fontWeight: FontWeight.w700),
                      )),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
          ]);
        }),

        // ── PAYMENT METHOD ──────────────────────────────────────────────
        _SectionCard(title: '💳 Payment Method',
          child: Column(children: [
            if (zonesAsync.value?['cod_available'] as bool? ?? true) ...[
              _PayOption(
                label: '💵 Cash on Delivery',
                sub:   'Pay when your order arrives',
                value: 'cod', current: _paymentMethod,
                onTap: () => setState(() => _paymentMethod = 'cod'),
              ),
              const SizedBox(height: 8),
            ],
            _PayOption(
              label: '💳 Razorpay — UPI / Card / Wallet',
              sub:   'Secure online payment',
              value: 'razorpay', current: _paymentMethod,
              onTap: () => setState(() => _paymentMethod = 'razorpay'),
            ),
          ])),

        const SizedBox(height: 12),

        // ── ORDER SUMMARY ───────────────────────────────────────────────
        _SectionCard(title: '🧾 Order Summary',
          child: Column(children: [
            ...cart.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppNetworkImage(url: item.thumbnail, width: 52, height: 52,
                      fit: BoxFit.contain),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      maxLines: 2),
                  Wrap(spacing: 4, children: [
                    if (item.selectedColor != null)
                      VariantChip(label: item.selectedColor!,
                          bgColor: AppColors.primaryLight, textColor: AppColors.primary),
                    if (item.variantLabel != null && item.variantLabel!.isNotEmpty)
                      VariantChip(label: item.variantLabel!,
                          bgColor: const Color(0xFFDEF7EC), textColor: AppColors.success),
                  ]),
                  Text('× ${item.quantity}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  // Show exchange badge if this item has exchange applied
                  if (item.exchangeData != null && item.exchangeData!['brand'] != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🔄', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 4),
                        Flexible(child: Text(
                          '${item.exchangeData!['brand']} ${item.exchangeData!['model'] ?? ''} • ${item.exchangeData!['condition'] ?? ''}',
                          style: TextStyle(fontSize: 10, color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        )),
                      ]),
                    ),
                ])),
                Text('₹${_fmt(item.subtotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            )),
            const Divider(height: 20),
            _PRow('Subtotal', cart.subtotal),
            if (discount > 0) _PRow('Coupon Discount', discount, prefix: '−', color: AppColors.success),
            if (exchangeDiscount > 0) _PRow('🔄 Exchange Discount', exchangeDiscount, prefix: '−', color: Colors.orange.shade700),
            if (_loyaltyDiscount > 0) _PRow('🌟 Loyalty Points ($_loyaltyPointsToUse pts)', _loyaltyDiscount, prefix: '−', color: Colors.green.shade700),
            _PRow('Shipping', _zoneRate,
                altText: _selectedZoneId == null ? 'Select zone above' : null),
            const Divider(height: 16),
            _PRow('Total Payable', approxTotal, bold: true),
          ])),

        const SizedBox(height: 100),
      ]),

      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: GradientButton(
          label: 'Place Order   ₹${_fmt(approxTotal)}',
          onTap: _placing ? null : _placeOrder,
          loading: _placing,
          height: 54,
        ),
      ),
    );
  }

  Widget _PRow(String label, double value,
      {String prefix = '', Color? color, bool bold = false, String? altText}) {
    final v = _fmt(value);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      const Spacer(),
      altText != null
          ? Text(altText, style: const TextStyle(fontSize: 11, color: AppColors.textLight))
          : Text('$prefix₹$v', style: TextStyle(
              fontSize: bold ? 16 : 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              color: color ?? (bold ? AppColors.primary : AppColors.textPrimary))),
    ]));
  }

  String _fmt(double v) => v.clamp(0, double.infinity).toInt()
      .toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ── Reusable widgets ────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

class _SelectableRow extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _SelectableRow({required this.selected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? AppColors.primary : AppColors.textLight,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ]),
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  final String label, sub, value, current;
  final VoidCallback onTap;
  const _PayOption({required this.label, required this.sub,
      required this.value, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return GestureDetector(onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? AppColors.primaryLight : AppColors.surface,
          border: Border.all(color: sel ? AppColors.primary : AppColors.border,
              width: sel ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: sel ? AppColors.primary : AppColors.textLight, size: 20),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ]),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();
  @override Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppColors.primary)));
}

class _NoAddresses extends StatelessWidget {
  final VoidCallback onAdd;
  const _NoAddresses({required this.onAdd});
  @override Widget build(BuildContext context) {
    return Column(children: [
      const Text('No saved addresses.',
          style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 10),
      AppOutlinedButton(label: '+ Add Address', onTap: onAdd, height: 38),
    ]);
  }
}

// ── Add Address Bottom Sheet ──────────────────────────────────────────────────
class AddAddressSheet extends StatefulWidget {
  const AddAddressSheet();
  @override State<AddAddressSheet> createState() => AddAddressSheetState();
}

class AddAddressSheetState extends State<AddAddressSheet> {
  final _fullNameCtrl   = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _line1Ctrl      = TextEditingController();
  final _line2Ctrl      = TextEditingController();
  final _cityCtrl       = TextEditingController();
  final _stateCtrl      = TextEditingController();
  final _pincodeCtrl    = TextEditingController();
  bool _isDefault       = false;
  bool _saving          = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_fullNameCtrl, _phoneCtrl, _line1Ctrl, _line2Ctrl,
                     _cityCtrl, _stateCtrl, _pincodeCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    // Basic validation
    if (_fullNameCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty ||
        _line1Ctrl.text.trim().isEmpty ||
        _cityCtrl.text.trim().isEmpty ||
        _stateCtrl.text.trim().isEmpty ||
        _pincodeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in all required fields.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ApiService.post(ApiConstants.addresses, data: {
        'full_name':  _fullNameCtrl.text.trim(),
        'phone':      _phoneCtrl.text.trim(),
        'address_line1': _line1Ctrl.text.trim(),
        'address_line2': _line2Ctrl.text.trim(),
        'city':       _cityCtrl.text.trim(),
        'state':      _stateCtrl.text.trim(),
        'pincode':    _pincodeCtrl.text.trim(),
        'country':    'India',
        'is_default': _isDefault,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle bar
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          const Text('Add Delivery Address',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withOpacity(0.3))),
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
          ],

          _Field(ctrl: _fullNameCtrl, label: 'Full Name *', hint: 'John Doe'),
          const SizedBox(height: 12),
          _Field(ctrl: _phoneCtrl, label: 'Phone *', hint: '+91 99999 99999',
              type: TextInputType.phone),
          const SizedBox(height: 12),
          _Field(ctrl: _line1Ctrl, label: 'Address Line 1 *',
              hint: 'House no., Street, Area'),
          const SizedBox(height: 12),
          _Field(ctrl: _line2Ctrl, label: 'Address Line 2',
              hint: 'Landmark, Colony (optional)'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Field(ctrl: _cityCtrl, label: 'City *', hint: 'Mumbai')),
            const SizedBox(width: 10),
            Expanded(child: _Field(ctrl: _stateCtrl, label: 'State *', hint: 'Maharashtra')),
          ]),
          const SizedBox(height: 12),
          _Field(ctrl: _pincodeCtrl, label: 'Pincode *', hint: '400001',
              type: TextInputType.number, maxLength: 6),
          const SizedBox(height: 14),

          // Set as default toggle
          GestureDetector(
            onTap: () => setState(() => _isDefault = !_isDefault),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: _isDefault ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: _isDefault ? AppColors.primary : AppColors.border,
                      width: 2),
                ),
                child: _isDefault
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: 10),
              const Text('Set as default address',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 20),

          GradientButton(
            label: 'Save Address',
            onTap: _saving ? null : _save,
            loading: _saving,
            height: 50,
          ),
        ]),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final TextInputType? type;
  final int? maxLength;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.type,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        keyboardType: type,
        maxLength: maxLength,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
          filled: true,
          fillColor: AppColors.borderLight,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        ),
      ),
    ]);
  }
}
