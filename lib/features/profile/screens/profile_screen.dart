import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/product_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../products/models/product_model.dart';

import '../../products/providers/wishlist_provider.dart';

// addressesProvider stays here
final addressesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiService.get(ApiConstants.addresses);
  final data = res.data;
  final list = (data is List ? data : data['data']) as List? ?? [];
  return list.cast<Map<String, dynamic>>();
});

// ── Main Profile Screen ─────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    if (!auth.isLoggedIn) {
      return Scaffold(
        body: EmptyState(
            emoji: '👤',
            title: 'Not logged in',
            subtitle: 'Sign in to view your profile and orders',
            buttonLabel: 'Sign In',
            onButton: () => context.go('/login')),
      );
    }

    final user = auth.user!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: AppColors.primary,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: SafeArea(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: user.avatarUrl != null
                              ? CachedNetworkImageProvider(user.avatarUrl!)
                              : null,
                          child: user.avatarUrl == null
                              ? Text(user.name[0].toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white))
                              : null),
                      const SizedBox(height: 10),
                      Text(user.name,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      Text(user.email,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white70)),
                      if (user.loyaltyPoints > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Text('🌟', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              '${user.loyaltyPoints} Loyalty Points',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ]),
              ),
            ),
          ),
        ),
        SliverList(
            delegate: SliverChildListDelegate([
          const SizedBox(height: 16),
          _MenuGroup(title: 'Shopping', items: [
            _MenuItem(
                icon: Icons.shopping_bag_outlined,
                label: 'My Orders',
                onTap: () => context.push('/orders')),
            _MenuItem(
                icon: Icons.favorite_border,
                label: 'Wishlist',
                onTap: () => _showWishlist(context, ref)),
            _MenuItem(
                icon: Icons.card_giftcard_outlined,
                label: 'My Claimed Gifts',
                onTap: () => context.push('/profile/gifts')),
          ]),
          const SizedBox(height: 16),
          _MenuGroup(title: 'Account', items: [
            _MenuItem(
                icon: Icons.edit_outlined,
                label: 'Edit Profile',
                onTap: () => context.push('/profile/edit')),
            _MenuItem(
                icon: Icons.location_on_outlined,
                label: 'Saved Addresses',
                onTap: () => _showAddresses(context, ref)),
            _MenuItem(
                icon: Icons.lock_outline,
                label: 'Change Password',
                onTap: () => _showChangePassword(context, ref)),
          ]),
          const SizedBox(height: 16),
          _MenuGroup(title: 'Support', items: [
            _MenuItem(
                icon: Icons.help_outline,
                label: 'Help & Support',
                onTap: () => _showHelp(context)),
            _MenuItem(
                icon: Icons.star_outline,
                label: 'Rate this App',
                onTap: () => _showRateApp(context)),
            _MenuItem(
                icon: Icons.info_outline,
                label: 'About Harahori Telecom',
                onTap: () => _showAbout(context)),
          ]),
          const SizedBox(height: 16),
          _MenuGroup(title: 'Legal', items: [
            _MenuItem(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => _openUrl(context, ApiConstants.privacyPolicyUrl)),
            _MenuItem(
                icon: Icons.description_outlined,
                label: 'Terms & Conditions',
                onTap: () => _openUrl(context, ApiConstants.termsUrl)),
          ]),
          const SizedBox(height: 16),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.error.withOpacity(0.3))),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: AppColors.error, size: 20),
                          SizedBox(width: 8),
                          Text('Logout',
                              style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                        ])),
              )),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: () => context.push('/profile/delete-account'),
              child: Text('Delete Account',
                  style: TextStyle(
                      color: AppColors.error.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.error.withOpacity(0.4))),
            ),
          ),
          const SizedBox(height: 40),
        ])),
      ]),
    );
  }

  void _showWishlist(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const WishlistSheet(),
      ),
    );
  }

  void _showAddresses(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _AddressesSheet(),
      ),
    );
  }

  void _showChangePassword(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: const _ChangePasswordSheet(),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HelpSheet(),
    );
  }

  void _showRateApp(BuildContext context) {
    showDialog(context: context, builder: (_) => const _RateAppDialog());
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AboutSheet(),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the page.')),
      );
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WISHLIST SHEET
// ══════════════════════════════════════════════════════════════════════════════

class WishlistSheet extends ConsumerWidget {
  const WishlistSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(wishlistProvider);

    // Keep wishlistIdsProvider in sync so heart icons stay correct
    wishlistAsync.whenData((items) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(wishlistIdsProvider.notifier).setFromProducts(items);
      });
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(children: [
              const Text('My Wishlist',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const Spacer(),
              wishlistAsync.maybeWhen(
                  data: (items) => Text('${items.length} items',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  orElse: () => const SizedBox()),
            ]),
          ),
          Expanded(
            child: wishlistAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('😕', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text('$e',
                    style:
                        const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                TextButton(
                    onPressed: () => ref.invalidate(wishlistProvider),
                    child: const Text('Retry')),
              ])),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      emoji: '💔',
                      title: 'Wishlist is empty',
                      subtitle: 'Save phones you love for later')
                  : GridView.builder(
                      controller: controller,
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.63,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10),
                      itemCount: items.length,
                      itemBuilder: (_, i) =>
                          ProductCard(product: items[i]),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ADDRESSES SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _AddressesSheet extends ConsumerStatefulWidget {
  const _AddressesSheet();

  @override
  ConsumerState<_AddressesSheet> createState() => _AddressesSheetState();
}

class _AddressesSheetState extends ConsumerState<_AddressesSheet> {
  bool _showAddForm = false;

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(children: [
              Text(_showAddForm ? 'Add New Address' : 'Saved Addresses',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
              const Spacer(),
              if (!_showAddForm)
                GestureDetector(
                  onTap: () => setState(() => _showAddForm = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('+ Add New',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                )
              else
                TextButton(
                    onPressed: () => setState(() => _showAddForm = false),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.error))),
            ]),
          ),
          Expanded(
            child: _showAddForm
                ? _AddAddressForm(onSuccess: () {
                    ref.invalidate(addressesProvider);
                    setState(() => _showAddForm = false);
                  })
                : addressesAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),
                    error: (e, _) => Center(
                        child: Text('$e',
                            style: const TextStyle(
                                color: AppColors.textSecondary))),
                    data: (addresses) => addresses.isEmpty
                        ? EmptyState(
                            emoji: '📍',
                            title: 'No saved addresses',
                            subtitle:
                                'Add a delivery address to get started',
                            buttonLabel: '+ Add Address',
                            onButton: () =>
                                setState(() => _showAddForm = true))
                        : ListView.builder(
                            controller: controller,
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: addresses.length,
                            itemBuilder: (_, i) => _AddressCard(
                              address: addresses[i],
                              onSetDefault: () async {
                                await ApiService.patch(
                                    '${ApiConstants.addresses}/${addresses[i]['id']}/default');
                                ref.invalidate(addressesProvider);
                              },
                              onDelete: () async {
                                await ApiService.delete(
                                    '${ApiConstants.addresses}/${addresses[i]['id']}');
                                ref.invalidate(addressesProvider);
                              },
                            ),
                          ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Map<String, dynamic> address;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _AddressCard(
      {required this.address,
      required this.onSetDefault,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDefault = address['is_default'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDefault ? AppColors.primaryLight.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDefault ? AppColors.primary : AppColors.border,
            width: isDefault ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(address['full_name'] ?? '',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text(address['phone'] ?? '',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          if (isDefault)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Default',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 6),
        Text(
          [
            address['address_line1'],
            address['address_line2'],
            address['city'],
            address['state'],
            address['pincode'],
          ]
              .where((e) => e != null && e.toString().isNotEmpty)
              .join(', '),
          style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4),
        ),
        const SizedBox(height: 12),
        Row(children: [
          if (!isDefault)
            GestureDetector(
              onTap: onSetDefault,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Set Default',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          const Spacer(),
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Delete Address',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                content:
                    const Text('Remove this address from your account?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                      child: const Text('Delete',
                          style: TextStyle(color: AppColors.error))),
                ],
              ),
            ),
            child: const Icon(Icons.delete_outline,
                color: AppColors.error, size: 20),
          ),
        ]),
      ]),
    );
  }
}

class _AddAddressForm extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  const _AddAddressForm({required this.onSuccess});

  @override
  ConsumerState<_AddAddressForm> createState() => _AddAddressFormState();
}

class _AddAddressFormState extends ConsumerState<_AddAddressForm> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincode = TextEditingController();
  bool _isDefault = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose(); _phone.dispose(); _line1.dispose();
    _line2.dispose(); _city.dispose(); _stateCtrl.dispose(); _pincode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.post(ApiConstants.addresses, data: {
        'full_name': _fullName.text.trim(),
        'phone': _phone.text.trim(),
        'address_line1': _line1.text.trim(),
        'address_line2': _line2.text.trim(),
        'city': _city.text.trim(),
        'state': _stateCtrl.text.trim(),
        'pincode': _pincode.text.trim(),
        'country': 'India',
        'is_default': _isDefault,
      });
      widget.onSuccess();
    } catch (e) {
      setState(() => _error = 'Failed to save address. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(_error!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 13)),
            ),
          _FormField(controller: _fullName, label: 'Full Name',
              hint: 'e.g. Rahul Sharma',
              validator: (v) => v!.isEmpty ? 'Required' : null),
          _FormField(controller: _phone, label: 'Phone',
              hint: '10-digit mobile number',
              keyboard: TextInputType.phone,
              validator: (v) => v!.length < 10 ? 'Enter valid phone' : null),
          _FormField(controller: _line1, label: 'Address Line 1',
              hint: 'House/Flat no., Street, Area',
              validator: (v) => v!.isEmpty ? 'Required' : null),
          _FormField(controller: _line2, label: 'Address Line 2 (Optional)',
              hint: 'Landmark, Colony etc.'),
          Row(children: [
            Expanded(child: _FormField(controller: _city, label: 'City',
                hint: 'City',
                validator: (v) => v!.isEmpty ? 'Required' : null)),
            const SizedBox(width: 12),
            Expanded(child: _FormField(controller: _stateCtrl, label: 'State',
                hint: 'State',
                validator: (v) => v!.isEmpty ? 'Required' : null)),
          ]),
          _FormField(controller: _pincode, label: 'Pincode',
              hint: '6-digit pincode',
              keyboard: TextInputType.number,
              validator: (v) => v!.length != 6 ? 'Enter valid pincode' : null),
          const SizedBox(height: 4),
          Row(children: [
            Checkbox(
              value: _isDefault,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _isDefault = v ?? false),
            ),
            const Text('Set as default address',
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          GradientButton(
              label: 'Save Address',
              onTap: _submit,
              loading: _loading,
              height: 50),
        ]),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final TextInputType keyboard;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboard = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          validator: validator,
          decoration: InputDecoration(hintText: hint),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CHANGE PASSWORD SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _showCurrent = false, _showNew = false, _showConfirm = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _current.dispose(); _newPass.dispose(); _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.patch('${ApiConstants.profile}/password', data: {
        'current_password': _current.text,
        'password': _newPass.text,
        'password_confirmation': _confirm.text,
      });
      setState(() => _success = true);
    } catch (e) {
      setState(() => _error = 'Current password is incorrect.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 30),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SheetHandle(),
          const SizedBox(height: 8),
          const Text('Change Password',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          if (_success) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 48),
                const SizedBox(height: 12),
                const Text('Password Updated!',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success)),
                const SizedBox(height: 6),
                const Text(
                    'Your password has been changed successfully.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                GradientButton(
                    label: 'Done',
                    onTap: () => Navigator.pop(context),
                    height: 44),
              ]),
            ),
          ] else ...[
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Text(_error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13)),
                ]),
              ),
            Form(
              key: _formKey,
              child: Column(children: [
                _PasswordField(
                    controller: _current,
                    label: 'Current Password',
                    show: _showCurrent,
                    onToggle: () => setState(
                        () => _showCurrent = !_showCurrent),
                    validator: (v) => v!.isEmpty ? 'Required' : null),
                _PasswordField(
                    controller: _newPass,
                    label: 'New Password',
                    show: _showNew,
                    onToggle: () =>
                        setState(() => _showNew = !_showNew),
                    validator: (v) => v!.length < 8
                        ? 'Min 8 characters'
                        : null),
                _PasswordField(
                    controller: _confirm,
                    label: 'Confirm New Password',
                    show: _showConfirm,
                    onToggle: () =>
                        setState(() => _showConfirm = !_showConfirm),
                    validator: (v) => v != _newPass.text
                        ? 'Passwords do not match'
                        : null),
                const SizedBox(height: 8),
                GradientButton(
                    label: 'Update Password',
                    onTap: _submit,
                    loading: _loading,
                    height: 50),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool show;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.show,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: !show,
          validator: validator,
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: GestureDetector(
              onTap: onToggle,
              child: Icon(
                  show
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.textLight),
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HELP & SUPPORT SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  static const _faqs = [
    {
      'q': 'How do I track my order?',
      'a': 'Go to My Orders → tap on any order to see live status and tracking details.',
    },
    {
      'q': 'What is the return policy?',
      'a': '7-day easy return on all products. Items must be unused and in original packaging.',
    },
    {
      'q': 'How do I apply a coupon?',
      'a': 'Add items to cart → on the cart screen, enter your coupon code in the "Apply Coupon" field.',
    },
    {
      'q': 'How does the Exchange Offer work?',
      'a': 'On any product page, tap "Apply Exchange", enter your old phone details and IMEI. The estimated value is deducted from your total at checkout.',
    },
    {
      'q': 'Is online payment secure?',
      'a': 'Yes! We use Razorpay, a PCI-DSS compliant payment gateway. Your card details are never stored on our servers.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.80,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          _SheetHandle(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Help & Support',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900)),
            ),
          ),
          Expanded(
            child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Contact Us',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 12),
                          _ContactRow(
                              icon: Icons.email_outlined,
                              text: 'support@harahoritelecom.net'),
                          const SizedBox(height: 8),
                          _ContactRow(
                              icon: Icons.phone_outlined,
                              text: '+91 98765 43210'),
                          const SizedBox(height: 8),
                          _ContactRow(
                              icon: Icons.access_time_outlined,
                              text: 'Mon–Sat, 10 AM – 7 PM'),
                        ]),
                  ),
                  const Text('Frequently Asked Questions',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  ..._faqs.map((faq) =>
                      _FaqTile(q: faq['q']!, a: faq['a']!)),
                ]),
          ),
        ]),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ]);
}

class _FaqTile extends StatefulWidget {
  final String q, a;
  const _FaqTile({required this.q, required this.a});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                  child: Text(widget.q,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700))),
              Icon(_open ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primary),
            ]),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(widget.a,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5)),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RATE APP DIALOG
// ══════════════════════════════════════════════════════════════════════════════

class _RateAppDialog extends StatefulWidget {
  const _RateAppDialog();

  @override
  State<_RateAppDialog> createState() => _RateAppDialogState();
}

class _RateAppDialogState extends State<_RateAppDialog> {
  int _rating = 0;
  bool _submitted = false;

  static const _labels = [
    '', 'Poor 😞', 'Fair 😐', 'Good 🙂', 'Great 😊', 'Excellent! 🤩'
  ];

  static const _playPackage = 'com.harahori.tel';

  Future<void> _openPlayStore() async {
    // market:// opens the native Play Store app directly when available —
    // a better landing experience than the web page. Falls back to the
    // plain web URL (which still deep-links to the Play Store app on most
    // Android devices) if that scheme isn't handled at all.
    const marketUri = 'market://details?id=$_playPackage';
    const webUri    = 'https://play.google.com/store/apps/details?id=$_playPackage';
    try {
      final opened = await launchUrl(Uri.parse(marketUri), mode: LaunchMode.externalApplication);
      if (!opened) await launchUrl(Uri.parse(webUri), mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(Uri.parse(webUri), mode: LaunchMode.externalApplication);
      } catch (_) {
        // Nothing more we can do here — the rating itself was still recorded.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _submitted
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🎉', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('Thank You!',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Your feedback means a lot to us 💜',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 20),
                GradientButton(
                    label: 'Close',
                    onTap: () => Navigator.pop(context),
                    height: 44),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('📱', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 12),
                const Text('Rate Harahori Telecom',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('How would you rate your experience?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 24),
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                        5,
                        (i) => GestureDetector(
                              onTap: () =>
                                  setState(() => _rating = i + 1),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 150),
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 6),
                                child: Icon(
                                  i < _rating
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 42,
                                  color: i < _rating
                                      ? const Color(0xFFFACC15)
                                      : AppColors.textLight,
                                ),
                              ),
                            ))),
                if (_rating > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    _labels[_rating],
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ],
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Maybe Later',
                          style: TextStyle(
                              color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: 'Submit',
                      onTap: _rating > 0
                          ? () {
                              setState(() => _submitted = true);
                              _openPlayStore();
                            }
                          : null,
                      height: 44,
                    ),
                  ),
                ]),
              ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ABOUT SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.90,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              _SheetHandle(),
              const SizedBox(height: 12),
              Center(
                child: Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Image.asset('assets/images/harahori.jpg',
                        width: 44, height: 44, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 14),
                  const Text('Harahori Telecom',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  const Text('Version 1.0.0',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary)),
                ]),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border)),
                child: const Text(
                  'Harahori Telecom is your trusted destination for premium smartphones '
                  'and mobile accessories. We bring you the latest devices from top brands '
                  'at the best prices, with a seamless shopping experience.\n\n'
                  'From flagship phones to budget picks, exchange offers to doorstep '
                  'delivery — we\'ve got everything to keep you connected.',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6),
                ),
              ),
              const SizedBox(height: 16),
              _AboutRow(
                  icon: Icons.location_city_outlined,
                  label: 'Headquartered in',
                  value: 'India'),
              _AboutRow(
                  icon: Icons.verified_outlined,
                  label: 'Authorized Dealer',
                  value: 'All Major Brands'),
              _AboutRow(
                  icon: Icons.local_shipping_outlined,
                  label: 'Delivery',
                  value: 'Pan India'),
              _AboutRow(
                  icon: Icons.support_agent_outlined,
                  label: 'Customer Support',
                  value: 'Mon–Sat, 10AM–7PM'),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              const Center(
                child: Text('Made with 💜 in India',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                    '© 2026 Harahori Telecom. All rights reserved.',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textLight)),
              ),
              const SizedBox(height: 20),
            ]),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _AboutRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _MenuGroup extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8)),
        ),
        Container(
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border)),
          child: Column(
              children: items.asMap().entries.map((e) {
            final isLast = e.key == items.length - 1;
            return Column(children: [
              e.value,
              if (!isLast) const Divider(height: 1, indent: 56),
            ]);
          }).toList()),
        ),
      ]),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.primary, size: 18)),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios,
              size: 14, color: AppColors.textLight),
        ]),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        width: 40, height: 4,
        decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}