import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _confirmChecked = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmAndDelete() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_confirmChecked) {
      setState(() => _error = 'Please confirm you understand this action is permanent.');
      return;
    }

    final reallySure = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete your account?',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text(
            'This is permanent. Your profile, addresses, wishlist and in-app order history will be removed and you\'ll be signed out.',
            style: TextStyle(height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (reallySure != true || !mounted) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await ref.read(authProvider.notifier).deleteAccount(_passwordCtrl.text);
    if (!mounted) return;

    if (ok) {
      context.go('/login');
    } else {
      setState(() {
        _submitting = false;
        _error = ref.read(authProvider).error ?? 'Could not delete your account. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: const Text('Delete Account',
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withOpacity(0.25))),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This can\'t be undone. Deleting your account removes your profile, saved addresses, wishlist and in-app order history.',
                      style: TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              const Text('What gets removed',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              const _Bullet('Your profile — name, email, phone and saved addresses'),
              const _Bullet('Wishlist, cart items and saved preferences'),
              const _Bullet('In-app access to your order history'),
              const _Bullet('Any loyalty points balance'),
              const SizedBox(height: 16),
              const Text('What we keep',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              const _Bullet('Invoice records, as required by tax law'),
              const _Bullet('Warranty registrations tied to a device\'s IMEI'),
              const _Bullet('Records needed for any open dispute or claim'),
              const SizedBox(height: 24),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ),
              const Text('Confirm your password',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                decoration: InputDecoration(
                  hintText: 'Your current password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                        size: 20, color: AppColors.textLight),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Checkbox(
                  value: _confirmChecked,
                  activeColor: AppColors.error,
                  onChanged: (v) => setState(() => _confirmChecked = v ?? false),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                        'I understand this action is permanent and cannot be undone.',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _submitting ? null : _confirmAndDelete,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _submitting ? AppColors.error.withOpacity(0.5) : AppColors.error,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('Delete My Account',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 5, color: AppColors.textLight),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
        ),
      ]),
    );
  }
}
