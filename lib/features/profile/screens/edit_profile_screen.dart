import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl  = TextEditingController(text: user?.name ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
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
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
            title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
            title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 1000);
    if (picked == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    final ok = await ref.read(authProvider.notifier).updateAvatar(File(picked.path));
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);

    if (!ok) {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Could not update photo.'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).updateProfile(
        _nameCtrl.text.trim(), _emailCtrl.text.trim());
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.'), backgroundColor: AppColors.success),
      );
      context.pop();
    } else {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Could not update profile.'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: const Text('Edit Profile',
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textPrimary)),
      ),
      body: user == null
          ? const SizedBox()
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    Center(
                      child: GestureDetector(
                        onTap: _uploadingAvatar ? null : _pickAvatar,
                        child: Stack(children: [
                          ClipOval(
                            child: user.avatarUrl != null
                                ? AppNetworkImage(url: user.avatarUrl, width: 96, height: 96)
                                : Container(
                                    width: 96,
                                    height: 96,
                                    decoration: const BoxDecoration(
                                        gradient: AppColors.heroGradient, shape: BoxShape.circle),
                                    child: Center(
                                      child: Text(
                                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                          ),
                          if (_uploadingAvatar)
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(
                                    color: Colors.black38, shape: BoxShape.circle),
                                child: const Center(
                                  child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2.5)),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2)),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 15),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _uploadingAvatar ? null : _pickAvatar,
                        child: const Text('Change Photo',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _EditField(
                        label: 'Full Name',
                        controller: _nameCtrl,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
                    const SizedBox(height: 14),
                    _EditField(
                        label: 'Email',
                        controller: _emailCtrl,
                        type: TextInputType.emailAddress,
                        validator: (v) =>
                            (v == null || !v.contains('@')) ? 'Enter a valid email' : null),
                    const SizedBox(height: 14),
                    _EditField(
                        label: 'Phone',
                        controller: _phoneCtrl,
                        type: TextInputType.phone,
                        readOnly: true,
                        helperText: "Phone number can't be changed here. Contact support if it needs updating."),
                    const SizedBox(height: 28),
                    GradientButton(label: 'Save Changes', onTap: _save, loading: auth.loading),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? type;
  final String? Function(String?)? validator;
  final bool readOnly;
  final String? helperText;

  const _EditField({
    required this.label,
    required this.controller,
    this.type,
    this.validator,
    this.readOnly = false,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: type,
        validator: validator,
        readOnly: readOnly,
        style: readOnly ? const TextStyle(color: AppColors.textSecondary) : null,
        decoration: InputDecoration(
          hintText: label,
          filled: readOnly ? true : null,
          fillColor: readOnly ? AppColors.borderLight : null,
          suffixIcon: readOnly
              ? const Icon(Icons.lock_outline, size: 18, color: AppColors.textLight)
              : null,
          helperText: helperText,
          helperMaxLines: 2,
          helperStyle: const TextStyle(fontSize: 11.5, color: AppColors.textLight, height: 1.3),
        ),
      ),
    ]);
  }
}
