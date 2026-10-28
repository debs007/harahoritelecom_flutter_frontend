import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).register(
        _nameCtrl.text.trim(), _emailCtrl.text.trim(),
        _passwordCtrl.text, _phoneCtrl.text.trim());
    if (ok && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 16),
          IconButton(onPressed: () => context.go('/login'),
              icon: const Icon(Icons.arrow_back_ios_new, size: 20)),
          const SizedBox(height: 16),
          const Text('Create Account 🎉', style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Join Harahori Telecom and start shopping!', style: TextStyle(
              fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 32),

          if (auth.error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(auth.error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),

          _field(_nameCtrl, 'Full Name', 'John Doe',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          const SizedBox(height: 14),
          _field(_emailCtrl, 'Email', 'you@example.com', type: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null),
          const SizedBox(height: 14),
          _field(_phoneCtrl, 'Phone', '+91 99999 99999', type: TextInputType.phone,
              validator: (v) => (v == null || v.trim().length < 10) ? 'Enter a valid phone number' : null),
          const SizedBox(height: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              validator: (v) => (v == null || v.length < 8) ? 'Min 8 characters' : null,
              decoration: InputDecoration(
                hintText: 'Min 8 characters',
                hintStyle: const TextStyle(color: AppColors.textLight),
                filled: true, fillColor: AppColors.borderLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textLight, size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 28),
          GradientButton(label: 'Create Account', onTap: _submit, loading: auth.loading),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Already have an account? ', style: TextStyle(color: AppColors.textSecondary)),
            GestureDetector(onTap: () => context.go('/login'),
              child: const Text('Sign In', style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800))),
          ]),
          ]),
        ),
      )),
    );
  }

  Widget _field(TextEditingController c, String label, String hint,
      {TextInputType? type, String? Function(String?)? validator}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      TextFormField(controller: c, keyboardType: type, validator: validator,
        decoration: InputDecoration(hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textLight),
            filled: true, fillColor: AppColors.borderLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2))),
      ),
    ]);
  }
}
