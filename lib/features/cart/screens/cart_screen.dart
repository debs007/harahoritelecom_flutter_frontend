import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../providers/cart_provider.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh cart every time this screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cartProvider.notifier).loadCart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          surfaceTintColor: AppColors.surface,
        ),
        body: cart.loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : cart.error != null && cart.items.isEmpty
                ? _ErrorState(
                    error: cart.error!,
                    onRetry: () => ref.read(cartProvider.notifier).loadCart())
                : cart.items.isEmpty
                    ? EmptyState(
                        emoji: '🛒',
                        title: 'Your cart is empty',
                        subtitle:
                            'Looks like you haven\'t added\nany phones yet.',
                        buttonLabel: 'Browse Phones',
                        onButton: () => context.go('/'),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () =>
                            ref.read(cartProvider.notifier).loadCart(),
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                children: [
                                  ...cart.items
                                      .map((item) => _CartTile(item: item)),
                                  const SizedBox(height: 8),
                                  _CouponSection(),
                                  const SizedBox(height: 8),
                                  _OrderSummary(cart: cart),
                                  const SizedBox(height: 8),
                                  _TrustBadges(),
                                ],
                              ),
                            ),
                            _CheckoutBar(cart: cart),
                          ],
                        ),
                      ),
      ),
    );
  }

  void _confirmClearCart(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cart?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Remove all items from your cart?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final notifier = ref.read(cartProvider.notifier);
              // Remove all items one by one
              final items = ref.read(cartProvider).items;
              for (final item in items) {
                await notifier.removeItem(item.id);
              }
            },
            child:
                const Text('Clear', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Cart Item Tile ──────────────────────────────────────────────────────────
class _CartTile extends ConsumerStatefulWidget {
  final CartItem item;
  const _CartTile({required this.item});

  @override
  ConsumerState<_CartTile> createState() => _CartTileState();
}

class _CartTileState extends ConsumerState<_CartTile> {
  bool _updating = false;

  Future<void> _updateQty(int newQty) async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      if (newQty < 1) {
        await ref.read(cartProvider.notifier).removeItem(widget.item.id);
      } else {
        await ref
            .read(cartProvider.notifier)
            .updateQuantity(widget.item.id, newQty);
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _updating = true);
    try {
      await ref.read(cartProvider.notifier).removeItem(widget.item.id);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Image with color badge ──────────────────────────────────
          GestureDetector(
            onTap: () => context.push('/products/${item.productSlug}'),
            child: Stack(children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppNetworkImage(
                    url: item.thumbnail,
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Color badge on image
              if (item.selectedColor != null)
                Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.88),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12)),
                      ),
                      child: Text(item.selectedColor!,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    )),
            ]),
          ),

          const SizedBox(width: 12),

          // ── Product info ─────────────────────────────────────────────
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Remove button top right
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          context.push('/products/${item.productSlug}'),
                      child: Text(item.productName,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  GestureDetector(
                    onTap: _updating ? null : _remove,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded,
                          size: 18,
                          color: _updating
                              ? AppColors.textLight
                              : AppColors.textSecondary),
                    ),
                  ),
                ]),

                const SizedBox(height: 6),

                // ── Variant chips (Color, RAM, Storage) ──────────────────
                Wrap(spacing: 5, runSpacing: 5, children: [
                  if (item.selectedColor != null)
                    _Chip(
                      label: item.selectedColor!,
                      emoji: '🎨',
                      bgColor: AppColors.primaryLight,
                      textColor: AppColors.primary,
                    ),
                  if (item.variantLabel != null &&
                      item.variantLabel!.isNotEmpty)
                    ..._parseVariantLabel(item.variantLabel!),
                ]),

                // ── Exchange info ────────────────────────────────────────
                if (item.exchangeData != null &&
                    (item.exchangeData!['brand'] ?? '').toString().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🔄', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        '${item.exchangeData!['brand']} ${item.exchangeData!['model']}'
                        ' · ${item.exchangeData!['condition'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.orange,
                            fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),

                const SizedBox(height: 10),

                // ── Price + Qty stepper ──────────────────────────────────
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₹${_fmt(item.subtotal)}',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary)),
                        if (item.quantity > 1)
                          Text('₹${_fmt(item.unitPrice)} each',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textLight)),
                      ]),
                  const Spacer(),

                  // Qty stepper
                  _updating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary))
                      : Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _QtyButton(
                              icon: item.quantity <= 1
                                  ? Icons.delete_outline_rounded
                                  : Icons.remove_rounded,
                              iconColor: item.quantity <= 1
                                  ? AppColors.error
                                  : AppColors.textPrimary,
                              onTap: () => _updateQty(item.quantity - 1),
                            ),
                            Container(
                              width: 36,
                              alignment: Alignment.center,
                              child: Text('${item.quantity}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                            ),
                            _QtyButton(
                              icon: Icons.add_rounded,
                              iconColor: item.quantity >= 10
                                  ? AppColors.textLight
                                  : AppColors.textPrimary,
                              onTap: item.quantity >= 10
                                  ? null
                                  : () => _updateQty(item.quantity + 1),
                            ),
                          ]),
                        ),
                ]),
              ])),
        ]),
      ),
    );
  }

  // Parse "8GB + 256GB" label into RAM + Storage chips
  List<Widget> _parseVariantLabel(String label) {
    final parts = label.split('+').map((s) => s.trim()).toList();
    return parts.map((p) {
      final isRam = p.toLowerCase().contains('gb') && parts.indexOf(p) == 0;
      final isStorage = parts.indexOf(p) == 1;
      return _Chip(
        label: p,
        emoji: isRam ? '🧠' : '💾',
        bgColor: isRam ? const Color(0xFFDEF7EC) : const Color(0xFFFEF3C7),
        textColor: isRam ? const Color(0xFF065F46) : const Color(0xFF92400E),
      );
    }).toList();
  }

  String _fmt(double v) {
    final n = v.toInt();
    return n
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _Chip extends StatelessWidget {
  final String label, emoji;
  final Color bgColor, textColor;
  const _Chip(
      {required this.label,
      required this.emoji,
      required this.bgColor,
      required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: textColor)),
      ]),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  const _QtyButton({required this.icon, required this.iconColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }
}

// ── Coupon Section ─────────────────────────────────────────────────────────
class _CouponSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CouponSection> createState() => _CouponSectionState();
}

class _CouponSectionState extends ConsumerState<_CouponSection> {
  final _ctrl = TextEditingController();
  bool _applying = false;
  String? _errorMsg;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _applying = true;
      _errorMsg = null;
    });
    try {
      final msg = await ref.read(cartProvider.notifier).applyCoupon(code);
      if (msg != null && mounted) {
        _ctrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted)
        setState(() => _errorMsg = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coupon = ref.watch(cartProvider).coupon;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_offer_rounded,
                  color: Colors.white, size: 16)),
          const SizedBox(width: 10),
          const Text('Apply Coupon',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
        ]),
        const SizedBox(height: 14),

        // Applied state
        if (coupon != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.success, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(coupon['code'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: AppColors.success,
                                letterSpacing: 1)),
                      ),
                      const SizedBox(width: 6),
                      const Text('applied!',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                        'You save ₹${_fmt((coupon['discount'] as num? ?? 0).toDouble())}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.success)),
                  ])),
              TextButton(
                onPressed: () => ref.read(cartProvider.notifier).removeCoupon(),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4)),
                child: const Text('Remove',
                    style: TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          )

        // Input state
        else ...[
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter coupon code',
                  hintStyle: const TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: AppColors.borderLight,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _errorMsg != null
                              ? AppColors.error
                              : AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 2)),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _errorMsg = null);
                          })
                      : null,
                ),
                onChanged: (_) => setState(() => _errorMsg = null),
                onSubmitted: (_) => _apply(),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _applying ? null : _apply,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                decoration: BoxDecoration(
                  gradient: _applying ? null : AppColors.primaryGradient,
                  color: _applying ? AppColors.border : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _applying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Apply',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
              ),
            ),
          ]),
          if (_errorMsg != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 13, color: AppColors.error),
                const SizedBox(width: 4),
                Text(_errorMsg!,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.error)),
              ]),
            ),
        ],
      ]),
    );
  }

  String _fmt(double v) => v
      .toInt()
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ── Order Summary ──────────────────────────────────────────────────────────
class _OrderSummary extends StatelessWidget {
  final CartState cart;
  const _OrderSummary({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        // Header
        Row(children: [
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  color: AppColors.primary, size: 16)),
          const SizedBox(width: 10),
          const Text('Order Summary',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),

        _PriceRow(
            label: 'Subtotal',
            value: cart.subtotal,
            subtext: '${cart.count} item${cart.count > 1 ? 's' : ''}'),

        if (cart.discount > 0) ...[
          const SizedBox(height: 4),
          _PriceRow(
              label: '🎟️ Coupon Discount',
              value: -cart.discount,
              valueColor: AppColors.success,
              prefix: '−'),
        ],

        if (cart.exchangeDiscount > 0) ...[
          const SizedBox(height: 4),
          _PriceRow(
              label: '🔄 Exchange Discount',
              value: -cart.exchangeDiscount,
              valueColor: Colors.orange.shade700,
              prefix: '−'),
        ],

        const SizedBox(height: 4),
        Row(children: [
          const Text('Shipping',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Calculated at checkout',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
        ]),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Expanded(child: Divider(color: AppColors.border)),
          ]),
        ),

        // Total
        Row(children: [
          const Text('Total',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${_fmt(cart.total)}',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary)),
            if (cart.discount > 0 || cart.exchangeDiscount > 0)
              Text('You save ₹${_fmt(cart.discount + cart.exchangeDiscount)}!',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700)),
          ]),
        ]),
      ]),
    );
  }

  String _fmt(double v) => v
      .abs()
      .toInt()
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double value;
  final String? subtext;
  final Color? valueColor;
  final String prefix;

  const _PriceRow(
      {required this.label,
      required this.value,
      this.subtext,
      this.valueColor,
      this.prefix = ''});

  @override
  Widget build(BuildContext context) {
    final fmt = value
        .abs()
        .toInt()
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        if (subtext != null)
          Text(subtext!,
              style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
      ]),
      const Spacer(),
      Text('$prefix₹$fmt',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary)),
    ]);
  }
}

// ── Trust Badges ───────────────────────────────────────────────────────────
class _TrustBadges extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _Badge(emoji: '🔒', label: 'Secure Pay'),
          _Badge(emoji: '↩️', label: '7-day Return'),
          _Badge(emoji: '✅', label: 'Genuine'),
          _Badge(emoji: '🚚', label: 'Fast Delivery'),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String emoji, label;
  const _Badge({required this.emoji, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 3),
      Text(label,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary)),
    ]);
  }
}

// ── Error State ─────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('😕', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text('Could not load cart',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(error.replaceAll('Exception: ', ''),
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        GradientButton(label: 'Retry', onTap: onRetry, height: 44),
      ]),
    ));
  }
}

// ── Checkout Bar ───────────────────────────────────────────────────────────
class _CheckoutBar extends StatelessWidget {
  final CartState cart;
  const _CheckoutBar({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Savings banner
        if (cart.discount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.savings_outlined,
                  size: 15, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                'You are saving ₹${cart.discount.toInt()} on this order! 🎉',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                    fontWeight: FontWeight.w700),
              ),
            ]),
          ),

        GradientButton(
          label: 'Proceed to Checkout  →  ₹${_fmt(cart.total)}',
          onTap: () => context.push('/checkout'),
          height: 54,
        ),
      ]),
    );
  }

  String _fmt(double v) => v
      .toInt()
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
