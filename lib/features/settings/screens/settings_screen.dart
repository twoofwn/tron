import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/theme_provider.dart';
import '../../../app/router/route_names.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../activation/services/permission_service.dart';
import '../../fake_call/services/reply_listener.dart';
import '../../home/widgets/delay_selector.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import '../widgets/gesture_test_sheet.dart';
import '../widgets/permission_card.dart';
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

  /// Bật chế độ nền cần thông báo thường trực, nên hỏi quyền trước khi bật.
  Future<void> _setBackgroundArmed(
    BuildContext context,
    WidgetRef ref,
    bool on,
  ) async {
    if (on) {
      final granted = (await ref.read(permissionSnapshotProvider.future))
          .notifications;
      if (!granted) {
        await ref
            .read(permissionServiceProvider)
            .request(CallPermission.notifications);
        ref.invalidate(permissionSnapshotProvider);
      }
    }
    if (!context.mounted) {
      return;
    }
    await _update(
      context,
      ref,
      (current) => current.copyWith(backgroundArmed: on),
    );
  }

  /// Bật chờ người dùng đáp thì xin quyền micro luôn, vì lúc cuộc gọi giả đổ
  /// chuông không được hiện hộp thoại xin quyền.
  Future<void> _setWaitForReply(
    BuildContext context,
    WidgetRef ref,
    bool on,
  ) async {
    await _update(
      context,
      ref,
      (current) => current.copyWith(waitForReply: on),
    );
    if (!on || !context.mounted) {
      return;
    }
    final listener = ref.read(replyListenerProvider);
    if (!listener.isSupported) {
      showMessage(
        context,
        'Máy này chưa nghe được qua micro: người gọi chờ khoảng 3 giây rồi nói tiếp.',
      );
      return;
    }
    if (!await listener.hasPermission(request: true) && context.mounted) {
      showMessage(
        context,
        'Chưa có quyền micro: người gọi chờ khoảng 3 giây rồi nói tiếp.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
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
            Text('HẸN GIỜ & KÍCH HOẠT', style: AppTextStyles.section),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mức gọi sau mặc định',
                    style: AppTextStyles.cardTitle,
                  ),
                  const SizedBox(height: 12),
                  const DelaySelector(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: const Text('Lật úp máy'),
                    subtitle: const Text(
                      'Úp màn hình xuống khoảng 1 giây để hẹn cuộc gọi.',
                    ),
                    value: value.flipEnabled,
                    onChanged: (on) => _update(
                      context,
                      ref,
                      (current) => current.copyWith(flipEnabled: on),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Độ nhạy'),
                        const SizedBox(height: 8),
                        SegmentedButton<TriggerSensitivity>(
                          showSelectedIcon: false,
                          segments: [
                            for (final level in TriggerSensitivity.values)
                              ButtonSegment(
                                value: level,
                                label: Text(level.label),
                              ),
                          ],
                          selected: {value.sensitivity},
                          onSelectionChanged: (selection) => _update(
                            context,
                            ref,
                            (current) =>
                                current.copyWith(sensitivity: selection.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAndroid)
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      title: const Text('Sẵn sàng khi tắt màn hình'),
                      subtitle: const Text(
                        'Hiện thông báo thường trực để lật máy vẫn hoạt động. Tốn pin hơn.',
                      ),
                      value: value.backgroundArmed,
                      onChanged: (on) => _setBackgroundArmed(context, ref, on),
                    ),
                  const Divider(height: 1),
                  _LinkRow(
                    title: 'Thử cử chỉ',
                    subtitle: 'Xem máy nhận lật úp thế nào.',
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => const GestureTestSheet(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('QUYỀN TRUY CẬP', style: AppTextStyles.section),
            const SizedBox(height: 12),
            const PermissionCard(),
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
                  if (isAndroid)
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      title: const Text('Về màn hình chính sau khi tắt máy'),
                      subtitle: const Text(
                        'Cuộc gọi kết thúc thì app tự ẩn, như app gọi thật.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: value.leaveAppAfterCall,
                      onChanged: (on) => _update(
                        context,
                        ref,
                        (current) => current.copyWith(leaveAppAfterCall: on),
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: const Text('Chờ tôi nói xong mới nói tiếp'),
                    subtitle: const Text(
                      'Nghe qua micro, không lưu giọng của bạn. Không có micro thì chờ khoảng 3 giây.',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: value.waitForReply,
                    onChanged: (on) => _setWaitForReply(context, ref, on),
                  ),
                  if (value.waitForReply)
                    ReplyPauseTile(
                      pause: value.replyPause,
                      onChanged: (pause) => _update(
                        context,
                        ref,
                        (current) => current.copyWith(replyPause: pause),
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
                    subtitle: 'Người liên hệ, tin nhắn, hẹn giờ báo an toàn',
                    onTap: () => Navigator.pushNamed(context, RouteNames.sos),
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
  const _LinkRow({required this.title, required this.onTap, this.subtitle});

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

/// Chỉnh thời gian người gọi chờ sau khi người dùng nói xong (0,5–5 giây).
/// Trong lúc kéo chỉ đổi số trên màn hình; thả tay mới lưu một lần.
class ReplyPauseTile extends StatefulWidget {
  const ReplyPauseTile({
    super.key,
    required this.pause,
    required this.onChanged,
  });
  final Duration pause;
  final ValueChanged<Duration> onChanged;

  /// Ví dụ 1500 ms → "1,5 giây".
  static String label(Duration pause) {
    final seconds = pause.inMilliseconds / 1000;
    final text = seconds == seconds.roundToDouble()
        ? seconds.toStringAsFixed(0)
        : seconds.toStringAsFixed(1).replaceAll('.', ',');
    return '$text giây';
  }

  @override
  State<ReplyPauseTile> createState() => _ReplyPauseTileState();
}

class _ReplyPauseTileState extends State<ReplyPauseTile> {
  /// Giá trị đang kéo; `null` khi không kéo thì theo cài đặt đã lưu.
  Duration? _dragging;

  @override
  void didUpdateWidget(ReplyPauseTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Đã lưu xong giá trị vừa chọn thì thôi giữ số đang kéo.
    if (widget.pause != oldWidget.pause) _dragging = null;
  }

  @override
  Widget build(BuildContext context) {
    final step = replyPauseStep.inMilliseconds;
    final min = AppSettings.minReplyPause.inMilliseconds.toDouble();
    final max = AppSettings.maxReplyPause.inMilliseconds.toDouble();
    final shown = _dragging ?? widget.pause;
    Duration snap(double ms) =>
        clampReplyPause(Duration(milliseconds: ms.round()));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Chờ sau khi bạn nói xong')),
              Text(
                ReplyPauseTile.label(shown),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Slider(
            min: min,
            max: max,
            divisions: (max - min) ~/ step,
            value: shown.inMilliseconds.toDouble().clamp(min, max),
            label: ReplyPauseTile.label(shown),
            semanticFormatterCallback: (ms) => ReplyPauseTile.label(snap(ms)),
            onChanged: (ms) => setState(() => _dragging = snap(ms)),
            onChangeEnd: (ms) {
              final chosen = snap(ms);
              if (chosen == widget.pause) {
                setState(() => _dragging = null);
              } else {
                // Giữ số vừa chọn tới khi lưu xong, tránh nháy về số cũ.
                setState(() => _dragging = chosen);
                widget.onChanged(chosen);
              }
            },
          ),
          const Text(
            'Bạn im lặng chừng này thì người gọi nói câu tiếp. Ngắn quá dễ bị cắt lời khi bạn ngừng giữa câu.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
