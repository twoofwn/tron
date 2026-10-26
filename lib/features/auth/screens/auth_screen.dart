import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../backup/services/backup_service.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isRegisterMode = false;
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isBusy) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      final notifier = ref.read(authStateProvider.notifier);
      if (_isRegisterMode) {
        await notifier.register(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _displayNameController.text,
        );
        // Perform initial backup of default/existing local combos
        try {
          await ref.read(backupServiceProvider).performBackup();
        } catch (_) {}
      } else {
        await notifier.login(_emailController.text, _passwordController.text);
      }

      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : 'Đăng nhập không thành công. Vui lòng kiểm tra lại thông tin và thử lại.';
          _passwordController.clear();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ScreenShell(
    title: _isRegisterMode ? 'Tạo tài khoản' : 'Đăng nhập TRỐN',
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sao lưu & Chia sẻ trực tuyến',
              style: AppTextStyles.title,
            ),
            const SizedBox(height: 8),
            const Text(
              'Đăng nhập để sao lưu combo, kịch bản cá nhân lên máy chủ và tạo mã chia sẻ EH-XXXXXX trực tuyến.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isRegisterMode) ...[
                    const Text(
                      'Tên hiển thị',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _displayNameController,
                      hint: 'Ví dụ: Minh Nguyễn',
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nhập tên hiển thị của bạn'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Email',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _emailController,
                    hint: 'ban@example.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Nhập email hợp lệ'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mật khẩu',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    validator: (v) => v == null || v.length < 8
                        ? 'Mật khẩu tối thiểu 8 ký tự (có chữ và số)'
                        : null,
                    decoration: const InputDecoration(
                      hintText: 'Tối thiểu 8 ký tự, gồm chữ và số',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.red.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: AppColors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.red,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  AppButton(
                    label: _isRegisterMode ? 'Đăng ký tài khoản' : 'Đăng nhập',
                    icon: _isRegisterMode
                        ? Icons.person_add_alt_1_rounded
                        : Icons.login_rounded,
                    isLoading: _isBusy,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: _isBusy
                    ? null
                    : () => setState(() {
                        _isRegisterMode = !_isRegisterMode;
                        _error = null;
                      }),
                child: Text(
                  _isRegisterMode
                      ? 'Đã có tài khoản? Đăng nhập ngay'
                      : 'Chưa có tài khoản? Đăng ký mới',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
