import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/enums/call_interface.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../activation/services/permission_service.dart';
import '../../activation/widgets/permission_request_sheet.dart';
import '../../combo/models/combo_model.dart';
import '../../combo/providers/combo_provider.dart';
import '../../fake_call/providers/call_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../widgets/combo_card.dart';
import '../widgets/delay_selector.dart';
import '../widgets/emergency_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  Future<void> _manage(
    BuildContext context,
    WidgetRef ref,
    ComboModel combo,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(combo.name, style: AppTextStyles.cardTitle),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Chỉnh sửa combo'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Nhân bản combo'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.red,
              ),
              title: const Text(
                'Xóa combo',
                style: TextStyle(color: AppColors.red),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) {
      return;
    }
    try {
      switch (action) {
        case 'edit':
          Navigator.pushNamed(context, RouteNames.comboForm, arguments: combo);
        case 'copy':
          await ref.read(comboListProvider.notifier).duplicateCombo(combo);
        case 'delete':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Xóa combo?'),
              content: Text('“${combo.name}” sẽ bị xóa khỏi thiết bị.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Giữ lại'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Xóa'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await ref.read(comboListProvider.notifier).deleteCombo(combo.id);
          }
      }
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Chưa thể lưu thay đổi. Vui lòng thử lại.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ScreenShell(
    child: ref
        .watch(comboListProvider)
        .when(
          loading: () => const AppLoading(),
          error: (error, stack) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Chưa thể tải combo trên thiết bị.'),
                TextButton(
                  onPressed: () => ref.invalidate(comboListProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
          data: (combos) {
            final selectedId = ref.watch(selectedComboIdProvider);
            final selected =
                combos.where((combo) => combo.id == selectedId).firstOrNull ??
                combos.firstOrNull;
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.pagePadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 44).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const HomeHeader(),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'COMBO CỦA BẠN',
                                style: AppTextStyles.section.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                RouteNames.sharing,
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              child: const Text(
                                'Nhập / Xuất',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(
                                context,
                                RouteNames.comboForm,
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.only(left: 4),
                              ),
                              child: const Text(
                                '+ Tạo combo',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (combos.isEmpty)
                          GlassCard(
                            child: Column(
                              children: [
                                const Icon(Icons.layers_outlined, size: 36),
                                const SizedBox(height: 12),
                                const Text('Tình huống nào cũng có lối ra.'),
                                const SizedBox(height: 12),
                                AppButton(
                                  label: 'Tạo combo đầu tiên',
                                  onPressed: () => Navigator.pushNamed(
                                    context,
                                    RouteNames.comboForm,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        for (final combo in combos)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ComboCard(
                              combo: combo,
                              isSelected: selected?.id == combo.id,
                              onTap: () => ref
                                  .read(selectedComboIdProvider.notifier)
                                  .selectCombo(combo.id),
                              onMenu: () => _manage(context, ref, combo),
                            ),
                          ),
                        const SizedBox(height: 12),
                        CallSchedulerCard(combo: selected),
                        const SizedBox(height: 24),
                        const Spacer(),
                        const HomeQuickActions(),
                        const SizedBox(height: 14),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 12,
                                color: AppColors.muted.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'Riêng tư trên thiết bị. An tâm là chính mình.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
  );
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  'TRỐN',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Chào bạn,',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text('Cần lối thoát?', style: AppTextStyles.title),
          ],
        ),
      ),
      GlassCard(
        padding: EdgeInsets.zero,
        child: IconButton(
          onPressed: () => Navigator.pushNamed(context, RouteNames.settings),
          tooltip: 'Cài đặt',
          icon: const Icon(Icons.settings_outlined, size: 21),
        ),
      ),
    ],
  );
}

class CallSchedulerCard extends ConsumerWidget {
  const CallSchedulerCard({super.key, required this.combo});
  final ComboModel? combo;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callProvider);
    final delay = ref.watch(callDelayProvider);
    final isScheduled = call.status == CallStatus.scheduled;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isScheduled ? 'CUỘC GỌI ĐANG CHỜ' : 'GỌI SAU',
                style: AppTextStyles.section.copyWith(color: AppColors.muted),
              ),
              const Spacer(),
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: AppColors.muted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const DelaySelector(),
          const SizedBox(height: 13),
          if (isScheduled) ...[
            Text(
              '${call.combo?.name} · còn ${call.remaining.inSeconds + 1} giây',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          AppButton(
            label: isScheduled
                ? 'Đổi lịch · gọi sau ${delayLabel(delay)}'
                : 'Hẹn giờ · gọi sau ${delayLabel(delay)}',
            icon: Icons.timer_outlined,
            onPressed: combo == null
                ? null
                : () => _schedule(context, ref, combo!, delay),
          ),
          if (isScheduled)
            Center(
              child: TextButton(
                onPressed: () => ref.read(callProvider.notifier).cancel(),
                child: const Text(
                  'Hủy cuộc gọi chờ',
                  style: TextStyle(color: AppColors.red),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: _NotificationHint(
              onRequest: () => _requestNotifications(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _schedule(
    BuildContext context,
    WidgetRef ref,
    ComboModel combo,
    Duration delay,
  ) async {
    // Đọc lại quyền mỗi lần hẹn: người dùng có thể vừa đổi quyền trong cài đặt hệ thống.
    ref.invalidate(permissionSnapshotProvider);
    final permissions = await ref.read(permissionSnapshotProvider.future);
    if (!permissions.notifications && context.mounted) {
      await _requestNotifications(context, ref);
    }
    if (!permissions.exactAlarm && context.mounted) {
      await _requestExactAlarm(context, ref);
    }
    if (!context.mounted) {
      return;
    }
    final armed = await ref.read(callProvider.notifier).schedule(combo, delay);
    if (!armed && context.mounted) {
      showMessage(
        context,
        'Chưa đặt được chuông khi khóa máy. Cuộc gọi vẫn đổ khi app đang mở.',
      );
    }
  }

  Future<void> _requestNotifications(
    BuildContext context,
    WidgetRef ref,
  ) => _requestPermission(
    context,
    ref,
    permission: CallPermission.notifications,
    title: 'Cho phép thông báo để đổ chuông đúng giờ',
    message:
        'TRỐN dùng thông báo để cuộc gọi đổ đúng giờ kể cả khi máy đang khóa. '
        'Nếu không cho phép, cuộc gọi chỉ đổ khi app đang mở.',
  );

  Future<void> _requestExactAlarm(
    BuildContext context,
    WidgetRef ref,
  ) => _requestPermission(
    context,
    ref,
    permission: CallPermission.exactAlarm,
    title: 'Cho phép báo thức chính xác',
    message:
        'Để chuông đổ đúng thời điểm đã hẹn. Máy sẽ mở trang cài đặt báo thức '
        'để bạn bật quyền này, rồi quay lại TRỐN.',
  );

  Future<void> _requestPermission(
    BuildContext context,
    WidgetRef ref, {
    required CallPermission permission,
    required String title,
    required String message,
  }) async {
    final allow = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (_) => PermissionRequestSheet(title: title, message: message),
    );
    if (allow != true) {
      return;
    }
    await ref.read(permissionServiceProvider).request(permission);
    ref.invalidate(permissionSnapshotProvider);
  }
}

class _NotificationHint extends ConsumerWidget {
  const _NotificationHint({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granted = ref.watch(permissionSnapshotProvider).value?.notifications;
    if (granted == null) {
      return const SizedBox.shrink();
    }
    if (granted) {
      return const Text(
        'Sẽ đổ chuông kể cả khi khóa máy',
        style: TextStyle(fontSize: 10, color: AppColors.muted),
      );
    }
    return TextButton(
      onPressed: onRequest,
      child: const Text(
        'Chưa cho phép thông báo: chỉ đổ khi app mở · Cấp quyền',
        style: TextStyle(fontSize: 10, color: AppColors.accent),
      ),
    );
  }
}

class HomeQuickActions extends ConsumerWidget {
  const HomeQuickActions({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final active = [
      settings?.flipEnabled,
      settings?.knockEnabled,
    ].where((on) => on == true).length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            onTap: () => Navigator.pushNamed(context, RouteNames.settings),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kích hoạt vô ảnh',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 5),
                Text(
                  'Lật máy, gõ lưng · ${active == 0 ? 'Đang tắt' : '$active đang bật'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            tint: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF301C22)
                : const Color(0xFFFFE8E9),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => const EmergencySheet(),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOS khẩn cấp',
                  style: TextStyle(
                    color: AppColors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Liên hệ người tin cậy',
                  style: TextStyle(color: AppColors.red, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
