import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/theme_provider.dart';
import '../../../app/router/route_names.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../home/widgets/emergency_sheet.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../widgets/phone_style_picker.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    AppSettings Function(AppSettings current) change,
  ) async {
    try {
      await ref.read(settingsProvider.notifier).modify(change);
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Chưa thể lưu cài đặt. Vui lòng thử lại.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final detected = ref.watch(resolvedPhoneStyleProvider).value;
    final isLight =
        (ref.watch(themeModeProvider).value ?? ThemeMode.dark) ==
        ThemeMode.light;
    return ScreenShell(
      title: 'Cài đặt',
      child: settings.when(
        loading: () => const AppLoading(),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Chưa thể tải cài đặt trên thiết bị.'),
              TextButton(
                onPressed: () => ref.invalidate(settingsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          children: [
            Text('LOẠI ĐIỆN THOẠI', style: AppTextStyles.section),
            const SizedBox(height: 6),
            const Text(
              'Màn hình cuộc gọi “Điện thoại” sẽ giống giao diện gọi mặc định của máy bạn.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: PhoneStylePicker(
                selected: value.phoneStyle,
                detected: detected,
                onSelected: (style) => _update(
                  context,
                  ref,
                  (current) => current.copyWith(phoneStyle: style),
                ),
              ),
            ),
            const SizedBox(height: 22),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: const Text('Rung khi có cuộc gọi'),
                    value: value.vibrateOnCall,
                    onChanged: (on) => _update(
                      context,
                      ref,
                      (current) => current.copyWith(vibrateOnCall: on),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: const Text('Giao diện sáng'),
                    value: isLight,
                    onChanged: (_) async {
                      try {
                        await ref.read(themeModeProvider.notifier).toggle();
                      } catch (_) {
                        if (context.mounted) {
                          showMessage(context, 'Không thể lưu giao diện.');
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _LinkRow(
                    title: 'Sao lưu, xuất / nhập combo',
                    onTap: () =>
                        Navigator.pushNamed(context, RouteNames.sharing),
                  ),
                  _LinkRow(
                    title: 'Màn hình ngụy trang',
                    onTap: () =>
                        Navigator.pushNamed(context, RouteNames.camouflage),
                  ),
                  _LinkRow(
                    title: 'SOS khẩn cấp',
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => const EmergencySheet(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
