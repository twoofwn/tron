import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../models/sos_settings.dart';
import '../providers/sos_providers.dart';
import '../services/sos_platform.dart';
import '../widgets/check_in_card.dart';
import '../widgets/sos_contacts_section.dart';
import '../widgets/sos_message_section.dart';

/// Cài đặt SOS: người liên hệ, nội dung tin, cách gọi, quyền và hẹn giờ báo an toàn.
class SosSetupScreen extends ConsumerWidget {
  const SosSetupScreen({super.key});

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    SosSettings Function(SosSettings current) change,
  ) async {
    try {
      await ref.read(sosSettingsProvider.notifier).modify(change);
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Chưa thể lưu cài đặt. Vui lòng thử lại.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(sosSettingsProvider);
    final supported = ref.watch(sosPlatformProvider).isSupported;
    return ScreenShell(
      title: 'SOS khẩn cấp',
      bottom: settings.value?.isReady == true
          ? FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: () =>
                  Navigator.pushNamed(context, RouteNames.sosAlert),
              icon: const Icon(Icons.sos_rounded),
              label: const Text('Gửi SOS ngay'),
            )
          : null,
      child: settings.when(
        loading: () => const AppLoading(),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(sosSettingsProvider),
            child: const Text('Chưa tải được cài đặt SOS · Thử lại'),
          ),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          children: [
            const Text(
              'Khi bấm SOS: app đếm ngược để bạn kịp hủy, rồi gửi SMS kèm vị trí '
              'cho tất cả người liên hệ và gọi người đầu tiên.',
              style: AppTextStyles.caption,
            ),
            if (!supported) ...[
              const SizedBox(height: 10),
              const Text(
                'Tự gửi SMS, gọi thẳng và lấy vị trí chỉ chạy trên Android.',
                style: TextStyle(color: AppColors.accent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 18),
            CheckInCard(settings: value),
            const SizedBox(height: 22),
            Text('NGƯỜI LIÊN HỆ', style: AppTextStyles.section),
            const SizedBox(height: 6),
            const Text(
              'Kéo để đổi thứ tự. Người đầu tiên được gọi trước.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 10),
            SosContactsSection(settings: value),
            const SizedBox(height: 22),
            Text('TIN NHẮN', style: AppTextStyles.section),
            const SizedBox(height: 10),
            SosMessageSection(settings: value),
            const SizedBox(height: 22),
            Text('CÁCH GỬI', style: AppTextStyles.section),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: const Text('Tự gọi sau khi gửi tin'),
                    subtitle: const Text('Gọi người đầu danh sách'),
                    value: value.autoCall,
                    onChanged: (on) => _update(
                      context,
                      ref,
                      (current) => current.copyWith(autoCall: on),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text('Đếm ngược trước khi gửi'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final seconds in SosSettings.countdownOptions)
                          ChoiceChip(
                            label: Text(
                              seconds == 0 ? 'Không' : '$seconds giây',
                            ),
                            selected: value.countdownSeconds == seconds,
                            onSelected: (_) => _update(
                              context,
                              ref,
                              (current) =>
                                  current.copyWith(countdownSeconds: seconds),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (supported) ...[
              const SizedBox(height: 22),
              Text('QUYỀN', style: AppTextStyles.section),
              const SizedBox(height: 6),
              const Text(
                'Cấp trước để lúc khẩn cấp không phải chờ hỏi quyền.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 10),
              const _PermissionsCard(),
            ],
            const SizedBox(height: 22),
            const Text(
              'Số khẩn cấp (113, 114, 115) không gọi thẳng được: app chỉ mở sẵn '
              'màn quay số. Nên bật thêm "SOS khẩn cấp" có sẵn của Android '
              '(bấm nút nguồn 5 lần).',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionsCard extends ConsumerWidget {
  const _PermissionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(sosPermissionsProvider).value;
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final permission in SosPermission.values)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(permission.label),
              subtitle: Text(permission.purpose),
              trailing: statuses == null
                  ? null
                  : statuses[permission] == true
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.green,
                    )
                  : TextButton(
                      onPressed: () async {
                        await ref
                            .read(sosPermissionServiceProvider)
                            .request(permission);
                        ref.invalidate(sosPermissionsProvider);
                      },
                      child: const Text('Cấp quyền'),
                    ),
            ),
        ],
      ),
    );
  }
}
