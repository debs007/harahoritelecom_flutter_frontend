import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/common_widgets.dart';

// Three steps: email → OTP → new password
enum _ForgotStep { email, otp, newPassword }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  _ForgotStep _step = _ForgotStep.email;

  // Controllers
  final _emailCtrl       = TextEditingController();
  final _otpCtrl         = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmCtrl     = TextEditingController();

  bool   _loading        = false;
  bool   _obscurePass    = true;
  bool   _obscureConfirm = true;
  String? _error;
  String? _resetToken;   // returned by verifyOtp, sent to resetPassword

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _setError(String? msg) => setState(() => _error = msg);
  void _setLoading(bool v)    => setState(() { _loading = v; _error = null; });

  // ── Step 1: Send OTP ────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) { _setError('Please enter your email address.'); return; }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      _setError('Please enter a valid email address.'); return;
    }

    _setLoading(true);
    try {
      await ApiService.post(ApiConstants.forgotSendOtp, data: {'email': email});
      setState(() { _step = _ForgotStep.otp; _error = null; });
    } on DioException catch (e) {
      _setError(_extractError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Step 2: Verify OTP ──────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) { _setError('Please enter the 6-digit OTP.'); return; }

    _setLoading(true);
    try {
      final res = await ApiService.post(ApiConstants.forgotVerifyOtp, data: {
        'email': _emailCtrl.text.trim(),
        'otp':   otp,
      });
      _resetToken = res.data['reset_token'] as String;
      setState(() { _step = _ForgotStep.newPassword; _error = null; });
    } on DioException catch (e) {
      _setError(_extractError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Step 3: Reset Password ──────────────────────────────────────────────────
  Future<void> _resetPassword() async {
    final pass    = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (pass.length < 8) {
      _setError('Password must be at least 8 characters.'); return;
    }
    if (pass != confirm) {
      _setError('Passwords do not match.'); return;
    }

    _setLoading(true);
    try {
      await ApiService.post(ApiConstants.forgotReset, data: {
        'email':                  _emailCtrl.text.trim(),
        'reset_token':            _resetToken,
        'password':               pass,
        'password_confirmation':  confirm,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password reset successfully! Please log in.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ));
        context.go('/login');
      }
    } on DioException catch (e) {
      _setError(_extractError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      if (data['message'] != null) return data['message'].toString();
      if (data['errors'] != null) {
        final errors = data['errors'] as Map;
        final first  = errors.values.first;
        return first is List ? first.first.toString() : first.toString();
      }
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            if (_step == _ForgotStep.otp) {
              setState(() { _step = _ForgotStep.email; _error = null; });
            } else if (_step == _ForgotStep.newPassword) {
              setState(() { _step = _ForgotStep.otp; _error = null; });
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator
              _StepIndicator(step: _step),
              const SizedBox(height: 28),

              // Heading
              Text(
                _stepTitle(_step),
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                _stepSubtitle(_step),
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
              const SizedBox(height: 32),

              // Error banner
              if (_error != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.3))),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13))),
                  ]),
                ),
              ],

              // Step content
              if (_step == _ForgotStep.email)   _buildEmailStep(),
              if (_step == _ForgotStep.otp)     _buildOtpStep(),
              if (_step == _ForgotStep.newPassword) _buildNewPasswordStep(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Email step ─────────────────────────────────────────────────────────────
  Widget _buildEmailStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label('Email Address'),
      const SizedBox(height: 6),
      TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: _inputDecor('you@example.com',
            prefix: const Icon(Icons.email_outlined,
                color: AppColors.textLight, size: 20)),
      ),
      const SizedBox(height: 28),
      GradientButton(
        label: 'Send OTP',
        onTap: _loading ? null : _sendOtp,
        loading: _loading,
        height: 52,
        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
      ),
      const SizedBox(height: 20),
      Center(
        child: GestureDetector(
          onTap: () => context.go('/login'),
          child: const Text('Back to Sign In',
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
        ),
      ),
    ]);
  }

  // ── OTP step ───────────────────────────────────────────────────────────────
  Widget _buildOtpStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Email display (non-editable)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.email_outlined,
              color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Text(_emailCtrl.text.trim(),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          const Spacer(),
          GestureDetector(
            onTap: () =>
                setState(() { _step = _ForgotStep.email; _error = null; }),
            child: const Text('Change',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline)),
          ),
        ]),
      ),
      const SizedBox(height: 20),

      _Label('Enter 6-digit OTP'),
      const SizedBox(height: 6),
      TextField(
        controller: _otpCtrl,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 12,
            color: AppColors.textPrimary),
        decoration: _inputDecor('------').copyWith(counterText: ''),
      ),
      const SizedBox(height: 8),

      // Resend OTP
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _loading ? null : _sendOtp,
          child: const Text('Resend OTP',
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(height: 16),

      GradientButton(
        label: 'Verify OTP',
        onTap: _loading ? null : _verifyOtp,
        loading: _loading,
        height: 52,
      ),
    ]);
  }

  // ── New password step ──────────────────────────────────────────────────────
  Widget _buildNewPasswordStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Label('New Password'),
      const SizedBox(height: 6),
      TextField(
        controller: _passwordCtrl,
        obscureText: _obscurePass,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: _inputDecor('Min 8 characters').copyWith(
          suffixIcon: IconButton(
            icon: Icon(
                _obscurePass ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textLight, size: 20),
            onPressed: () =>
                setState(() => _obscurePass = !_obscurePass),
          ),
        ),
      ),
      const SizedBox(height: 16),

      _Label('Confirm New Password'),
      const SizedBox(height: 6),
      TextField(
        controller: _confirmCtrl,
        obscureText: _obscureConfirm,
        style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
        decoration: _inputDecor('Re-enter password').copyWith(
          suffixIcon: IconButton(
            icon: Icon(
                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                color: AppColors.textLight, size: 20),
            onPressed: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
      ),
      const SizedBox(height: 28),

      GradientButton(
        label: 'Reset Password',
        onTap: _loading ? null : _resetPassword,
        loading: _loading,
        height: 52,
        icon: const Icon(Icons.lock_reset_rounded,
            color: Colors.white, size: 18),
      ),
    ]);
  }

  String _stepTitle(_ForgotStep s) => switch (s) {
    _ForgotStep.email       => 'Forgot Password? 🔐',
    _ForgotStep.otp         => 'Check your email 📩',
    _ForgotStep.newPassword => 'Set new password 🔑',
  };

  String _stepSubtitle(_ForgotStep s) => switch (s) {
    _ForgotStep.email =>
      'Enter your registered email and we\'ll send you a one-time password.',
    _ForgotStep.otp =>
      'We\'ve sent a 6-digit OTP to your email. It expires in 10 minutes.',
    _ForgotStep.newPassword =>
      'Almost done! Choose a strong password that you haven\'t used before.',
  };

  InputDecoration _inputDecor(String hint, {Widget? prefix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textLight),
        prefixIcon: prefix,
        filled: true,
        fillColor: AppColors.borderLight,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2)),
      );
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary));
}

class _StepIndicator extends StatelessWidget {
  final _ForgotStep step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    final steps = ['Email', 'OTP', 'Password'];
    final current = step.index;
    return Row(children: List.generate(steps.length, (i) {
      final done   = i < current;
      final active = i == current;
      return Expanded(
        child: Row(children: [
          // Circle
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done || active ? AppColors.primary : AppColors.borderLight,
              border: Border.all(
                  color: done || active ? AppColors.primary : AppColors.border),
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: active
                              ? Colors.white
                              : AppColors.textLight)),
            ),
          ),
          const SizedBox(width: 4),
          Text(steps[i],
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active
                      ? AppColors.primary
                      : AppColors.textSecondary)),
          // Connector line (except after last)
          if (i < steps.length - 1) ...[
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                  height: 2,
                  color: i < current ? AppColors.primary : AppColors.border),
            ),
            const SizedBox(width: 4),
          ],
        ]),
      );
    }));
  }
}
