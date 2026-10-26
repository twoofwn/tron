import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../activation/services/permission_service.dart';

class PermissionCard extends ConsumerWidget {
  const PermissionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(permissionServiceProvider);
    final snapshot = ref.watch(permissionSnapshotProvider);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: snapshot.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(18),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => const Padding(
          padding: EdgeInsets.all(18),
          child: Text('Chưa kiểm tra được quyền trên thiết bị này.'),
        ),
        data: (state) => Column(
          children: [
            _PermissionRow(
              title: 'Thông báo',
              description: 'Đổ chuông đúng giờ khi máy đang khóa.',
              granted: state.notifications,
              onRequest: () => _request(ref, CallPermission.notifications),
            ),
            if (service.supports(CallPermission.exactAlarm)) ...[
              const Divider(height: 1),
              _PermissionRow(
                title: 'Báo thức chính xác',
                description: 'Đổ đúng thời điểm đã hẹn, không trễ.',
                granted: state.exactAlarm,
                onRequest: () => _request(ref, CallPermission.exactAlarm),
              ),
            ],
            if (service.supports(CallPermission.batteryUnrestricted)) ...[
              const Divider(height: 1),
              _PermissionRow(
                title: 'Bỏ tối ưu pin',
                description:
                    'Xiaomi, Huawei hay ngắt app chạy nền nếu không tắt.',
                granted: state.batteryUnrestricted,
                onRequest: () =>
                    _request(ref, CallPermission.batteryUnrestricted),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: const Text('Hiện khi khóa máy'),
                subtitle: const Text(
                  'Mở cài đặt để cho phép màn gọi hiện trên màn khóa.',
                ),
                trailing: TextButton(
                  onPressed: () => service.openFullScreenSettings(),
                  child: const Text('Mở cài đặt'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _request(WidgetRef ref, CallPermission permission) async {
    await ref.read(permissionServiceProvider).request(permission);
    ref.invalidate(permissionSnapshotProvider);
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.title,
    required this.description,
    required this.granted,
    required this.onRequest,
  });

  final String title;
  final String description;
  final bool granted;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.cardTitle),
        const SizedBox(height: 2),
        Text(
          description,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            if (granted)
              const _StatusText(
                text: 'Đã cấp',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.green,
              )
            else ...[
              const _StatusText(
                text: 'Chưa cấp',
                icon: Icons.error_outline_rounded,
                color: AppColors.red,
              ),
              TextButton(onPressed: onRequest, child: const Text('Cấp quyền')),
            ],
          ],
        ),
      ],
    ),
  );
}

class _StatusText extends StatelessWidget {
  const _StatusText({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12, color: color)),
    ],
  );
}
