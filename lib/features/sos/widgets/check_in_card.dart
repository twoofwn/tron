import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../models/sos_settings.dart';
import '../providers/sos_providers.dart';
import '../services/sos_message.dart';
import '../services/sos_platform.dart';

String _clock(DateTime time) => SosMessage.formatTime(time).substring(0, 5);

String _durationLabel(Duration duration) => duration.inMinutes < 60
    ? '${duration.inMinutes} phút'
    : '${duration.inHours} giờ';

/// Thời gian còn lại tới [deadline], tự cập nhật mỗi giây.
class CountdownText extends StatefulWidget {
  const CountdownText({super.key, required this.deadline, this.style});
  final DateTime deadline;
  final TextStyle? style;

  static String format(Duration left) {
    if (left.isNegative) {
      return '0:00';
    }
    String two(int value) => value.toString().padLeft(2, '0');
    final hours = left.inHours;
    final minutes = left.inMinutes % 60;
    final seconds = left.inSeconds % 60;
    return hours > 0
        ? '$hours:${two(minutes)}:${two(seconds)}'
        : '$minutes:${two(seconds)}';
  }

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    CountdownText.format(widget.deadline.difference(DateTime.now())),
    style: widget.style,
  );
}

Future<void> _guard(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      showMessage(context, 'Chưa thực hiện được. Vui lòng thử lại.');
    }
  }
}

/// Kết quả lần tự gửi SOS gần nhất (khi hết giờ báo an toàn).
class _FiredNotice extends ConsumerWidget {
  const _FiredNotice({required this.status});
  final CheckInStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GlassCard(
    tint: AppColors.red.withValues(alpha: 0.25),
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        const Icon(Icons.sos_rounded, color: AppColors.red),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Đã tự gửi SOS lúc ${_clock(status.firedAt!)} vì chưa báo an toàn · '
            '${status.sent}/${status.total} tin'
            '${status.located ? ' kèm vị trí' : ''}.',
          ),
        ),
        TextButton(
          onPressed: () => _guard(
            context,
            () => ref.read(checkInProvider.notifier).clearResult(),
          ),
          child: const Text('Đã xem'),
        ),
      ],
    ),
  );
}

/// Hẹn giờ "Báo an toàn" trong màn cài đặt SOS.
class CheckInCard extends ConsumerStatefulWidget {
  const CheckInCard({super.key, required this.settings});
  final SosSettings settings;

  @override
  ConsumerState<CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends ConsumerState<CheckInCard> {
  Duration _duration = const Duration(minutes: 30);
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    await _guard(context, action);
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _start() => _run(() async {
    final permissions = ref.read(sosPermissionServiceProvider);
    for (final permission in [
      SosPermission.sms,
      SosPermission.location,
      SosPermission.notifications,
      if (widget.settings.autoCall) SosPermission.call,
    ]) {
      if (!await permissions.isGranted(permission)) {
        await permissions.request(permission);
      }
    }
    ref.invalidate(sosPermissionsProvider);
    if (!await permissions.isGranted(SosPermission.sms)) {
      if (mounted) {
        showMessage(context, 'Cần quyền gửi SMS để tự gửi khi hết giờ.');
      }
      return;
    }
    final exact = await ref.read(checkInProvider.notifier).start(_duration);
    if (!exact && mounted) {
      showMessage(
        context,
        'Chưa cho phép "Báo thức chính xác": tin có thể gửi trễ vài phút. '
        'Cấp quyền ở mục Quyền bên dưới.',
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(checkInProvider).value ?? const CheckInStatus();
    final supported = ref.watch(sosPlatformProvider).isSupported;
    final deadline = status.deadline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status.firedAt != null) ...[
          _FiredNotice(status: status),
          const SizedBox(height: 12),
        ],
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hẹn giờ báo an toàn', style: AppTextStyles.cardTitle),
              const SizedBox(height: 6),
              const Text(
                'Hết giờ mà bạn chưa bấm "Tôi an toàn", app tự gửi SOS kèm vị trí '
                'cho mọi người liên hệ, kể cả khi máy khóa hoặc app đã đóng.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 14),
              if (!supported)
                const Text(
                  'Chỉ hỗ trợ trên Android.',
                  style: TextStyle(color: AppColors.muted),
                )
              else if (deadline != null) ...[
                Center(
                  child: CountdownText(
                    key: const ValueKey('check-in-countdown'),
                    deadline: deadline,
                    style: AppTextStyles.title.copyWith(fontSize: 40),
                  ),
                ),
                Center(
                  child: Text(
                    'Tự gửi SOS lúc ${_clock(deadline)}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 14),
                AppButton(
                  label: 'Tôi an toàn',
                  icon: Icons.verified_user_outlined,
                  isLoading: _busy,
                  onPressed: () =>
                      _run(() => ref.read(checkInProvider.notifier).cancel()),
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Thêm ${_durationLabel(CheckInNotifier.extension)}',
                  icon: Icons.more_time_rounded,
                  isSecondary: true,
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => ref.read(checkInProvider.notifier).extend(),
                        ),
                ),
              ] else if (!widget.settings.isReady)
                const Text(
                  'Thêm người liên hệ trước khi hẹn giờ.',
                  style: TextStyle(color: AppColors.muted),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final duration in CheckInNotifier.durations)
                      ChoiceChip(
                        label: Text(_durationLabel(duration)),
                        selected: _duration == duration,
                        onSelected: (_) => setState(() => _duration = duration),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                AppButton(
                  label: 'Bắt đầu hẹn giờ',
                  icon: Icons.timer_outlined,
                  isLoading: _busy,
                  onPressed: _start,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Dải nhỏ ở màn Home khi đang hẹn giờ báo an toàn, hoặc app vừa tự gửi SOS.
class CheckInBanner extends ConsumerWidget {
  const CheckInBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(checkInProvider).value;
    if (status == null) {
      return const SizedBox.shrink();
    }
    if (status.firedAt != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _FiredNotice(status: status),
      );
    }
    final deadline = status.deadline;
    if (deadline == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        tint: AppColors.green.withValues(alpha: 0.18),
        onTap: () => Navigator.pushNamed(context, RouteNames.sos),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: AppColors.green),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Báo an toàn · còn '),
                  CountdownText(
                    deadline: deadline,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _guard(
                context,
                () => ref.read(checkInProvider.notifier).cancel(),
              ),
              child: const Text('Tôi an toàn'),
            ),
          ],
        ),
      ),
    );
  }
}
