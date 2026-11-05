import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../combo/providers/combo_provider.dart';
import '../../scenarios/providers/scenario_provider.dart';
import '../providers/auth_provider.dart';
import 'auth_screen.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _isBusy = false;

  Future<void> _reloadFromDatabase() async {
    setState(() => _isBusy = true);
    try {
      ref.invalidate(comboListProvider);
      ref.invalidate(scenarioLibraryProvider);
      await ref.read(comboListProvider.future);
      await ref.read(scenarioLibraryProvider.future);
      await ref.read(authStateProvider.notifier).refreshProfile();
      if (mounted) {
        showMessage(
          context,
          'Đã tải dữ liệu mới nhất trực tiếp từ cơ sở dữ liệu.',
        );
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is ApiException ? e.message : 'Không thể làm mới dữ liệu lúc này.',
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text(
          'Dữ liệu của bạn đã được lưu an toàn trong cơ sở dữ liệu SQL Server trực tuyến.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await ref
          .read(authStateProvider.notifier)
          .logout(clearLocalUserData: true);
      ref.invalidate(comboListProvider);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa vĩnh viễn tài khoản?'),
        content: const Text(
          'Toàn bộ combo, kịch bản cá nhân, gói đã đăng trên Chợ và file âm thanh trên máy chủ sẽ bị xóa vĩnh viễn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Xóa tài khoản',
              style: TextStyle(color: AppColors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await ref.read(authStateProvider.notifier).deleteAccount();
      ref.invalidate(comboListProvider);
      if (mounted) {
        showMessage(context, 'Đã xóa tài khoản.');
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          context,
          e is ApiException ? e.message : 'Không thể xóa tài khoản.',
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _changePasswordDialog() async {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? dialogError;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Đổi mật khẩu', style: AppTextStyles.title),
                    const SizedBox(height: 6),
                    const Text(
                      'Nhập mật khẩu hiện tại và mật khẩu mới.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Mật khẩu hiện tại',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: currentPasswordCtrl,
                      obscureText: true,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Nhập mật khẩu hiện tại'
                          : null,
                      decoration: const InputDecoration(
                        hintText: 'Mật khẩu đang sử dụng',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Mật khẩu mới',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: newPasswordCtrl,
                      obscureText: true,
                      validator: (v) => v == null || v.length < 8
                          ? 'Mật khẩu mới tối thiểu 8 ký tự'
                          : null,
                      decoration: const InputDecoration(
                        hintText: 'Tối thiểu 8 ký tự, gồm cả chữ và số',
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
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
                                dialogError!,
                                style: const TextStyle(
                                  color: AppColors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'Cập nhật mật khẩu',
                      icon: Icons.lock_reset_rounded,
                      isLoading: isSubmitting,
                      onPressed: () async {
                        if (!formKey.currentState!.validate() || isSubmitting) {
                          return;
                        }
                        setModalState(() {
                          isSubmitting = true;
                          dialogError = null;
                        });
                        try {
                          await ref
                              .read(authStateProvider.notifier)
                              .changePassword(
                                currentPassword: currentPasswordCtrl.text,
                                newPassword: newPasswordCtrl.text,
                              );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            showMessage(
                              this.context,
                              'Đổi mật khẩu thành công!',
                            );
                          }
                        } catch (e) {
                          setModalState(() {
                            dialogError = e is ApiException ? e.message : 'Đổi mật khẩu thất bại. Vui lòng kiểm tra lại mật khẩu hiện tại.';
                            currentPasswordCtrl.clear();
                            newPasswordCtrl.clear();
                            isSubmitting = false;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    currentPasswordCtrl.dispose();
    newPasswordCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    return authAsync.when(
      loading: () => const ScreenShell(title: 'Tài khoản', child: AppLoading()),
      error: (_, _) => const AuthScreen(),
      data: (user) {
        if (user == null) {
          return const AuthScreen();
        }
        final usedMb = (user.usedMediaBytes / (1024 * 1024)).toStringAsFixed(1);
        final quotaMb = (user.quotaMediaBytes / (1024 * 1024)).toStringAsFixed(
          0,
        );

        return ScreenShell(
          title: 'Tài khoản TRỐN',
          child: ListView(
            padding: const EdgeInsets.all(AppConstants.pagePadding),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                      child: Text(
                        user.displayName.isNotEmpty
                            ? user.displayName.characters.first.toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            style: AppTextStyles.cardTitle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.cloud_done_outlined,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CƠ SỞ DỮ LIỆU TRỰC TUYẾN',
                          style: AppTextStyles.section.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tự động lưu trực tiếp: Mọi thao tác Thêm, Sửa, Xóa combo và kịch bản đều được cập nhật ngay vào SQL Server.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Đang lưu trong DB: ${user.backupComboCount} combo · ${user.backupScenarioCount} kịch bản cá nhân · $usedMb / $quotaMb MB âm thanh',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Làm mới dữ liệu từ máy chủ',
                      icon: Icons.sync_rounded,
                      isLoading: _isBusy,
                      isSecondary: true,
                      onPressed: _reloadFromDatabase,
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: 'Mở Chợ Tình Huống (Nhận / Đăng gói)',
                      icon: Icons.storefront_outlined,
                      onPressed: () =>
                          Navigator.pushNamed(context, RouteNames.sharing),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Đổi mật khẩu',
                icon: Icons.lock_reset_rounded,
                isSecondary: true,
                onPressed: _isBusy ? null : _changePasswordDialog,
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Đăng xuất',
                icon: Icons.logout_rounded,
                isSecondary: true,
                onPressed: _isBusy ? null : _logout,
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _isBusy ? null : _deleteAccount,
                  child: const Text(
                    'Xóa vĩnh viễn tài khoản',
                    style: TextStyle(color: AppColors.red, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
