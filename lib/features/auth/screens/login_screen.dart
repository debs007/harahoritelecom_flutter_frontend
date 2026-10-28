import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref.read(authProvider.notifier).login(
        _emailCtrl.text.trim(), _passwordCtrl.text);
    if (ok && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 24),

          // Logo
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Image.asset(
                'assets/images/harahori.jpg',
                width: 54,
                height: 54,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            RichText(text: const TextSpan(
              children: [
                TextSpan(text: 'Harahori ', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary)),
                TextSpan(text: 'Telecom', style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: AppColors.primary)),
              ],
            )),
          ]),

          const SizedBox(height: 40),
          const Text('Welcome back 👋', style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('Sign in to continue shopping', style: TextStyle(
              fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 36),

          // Error
          if (auth.error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(auth.error!, style: const TextStyle(
                    color: AppColors.error, fontSize: 13))),
              ]),
            ),

          // Email
          _InputField(controller: _emailCtrl, label: 'Email Address',
              hint: 'you@example.com', keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),

          // Password
          _InputField(
            controller: _passwordCtrl, label: 'Password', hint: '••••••••',
            obscure: _obscure,
            suffix: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textLight, size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),

          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => context.push('/forgot-password'), child: const Text(
              'Forgot Password?', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)))),

          const SizedBox(height: 24),
          GradientButton(label: 'Sign In', onTap: _submit, loading: auth.loading),
          const SizedBox(height: 24),

          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text("Don't have an account? ", style: TextStyle(color: AppColors.textSecondary)),
            GestureDetector(onTap: () => context.go('/register'),
              child: const Text('Sign Up', style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800))),
          ]),

          const SizedBox(height: 16),
          // Demo credentials
          // Container(padding: const EdgeInsets.all(14),
          //   decoration: BoxDecoration(color: AppColors.primaryLight,
          //       borderRadius: BorderRadius.circular(12)),
          //   child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          //     const Text('Demo Credentials', style: TextStyle(
          //         fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          //     const SizedBox(height: 4),
          //     const Text('Email: customer@test.com\nPassword: password',
          //         style: TextStyle(fontSize: 12, color: AppColors.primaryDark)),
          //     const SizedBox(height: 8),
          //     GestureDetector(
          //       onTap: () {
          //         _emailCtrl.text = 'customer@test.com';
          //         _passwordCtrl.text = 'password';
          //       },
          //       child: const Text('Tap to fill', style: TextStyle(
          //           fontSize: 11, color: AppColors.primary,
          //           fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
          //     ),
          //   ]),
          // ),
        ]),
      )),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;

  const _InputField({required this.controller, required this.label,
      required this.hint, this.keyboardType, this.obscure = false, this.suffix});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textLight),
          filled: true, fillColor: AppColors.borderLight,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          suffixIcon: suffix,
        ),
      ),
    ]);
  }
}
