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

/// "30 giây", "1 phút 30 giây", "15 phút", "1 giờ", "2 giờ 35 phút".
String durationLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;
  return [
    if (hours > 0) '$hours giờ',
    if (minutes > 0) '$minutes phút',
    if (seconds > 0) '$seconds giây',
  ].join(' ');
}

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

String _sendingTitle({required bool overdue}) =>
    overdue ? 'Hết giờ · đang gửi SOS…' : 'Đang gửi SOS…';

String _sendingDetail(int contacts) => contacts > 0
    ? 'Đang lấy vị trí và nhắn tin cho $contacts người liên hệ.'
    : 'Đang lấy vị trí và nhắn tin cho người liên hệ.';

/// Lúc hết giờ: thay đồng hồ 0:00 bằng vòng xoay "đang gửi".
/// [overdue] là lúc Android chưa bắt đầu gửi, người dùng vẫn huỷ được.
class SendingSosState extends StatelessWidget {
  const SendingSosState({
    super.key,
    required this.contacts,
    this.overdue = false,
  });
  final int contacts;
  final bool overdue;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('check-in-sending'),
    children: [
      const SizedBox(
        width: 44,
        height: 44,
        child: CircularProgressIndicator(
          strokeWidth: 3.5,
          color: AppColors.red,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        _sendingTitle(overdue: overdue),
        textAlign: TextAlign.center,
        style: AppTextStyles.cardTitle.copyWith(fontSize: 20),
      ),
      const SizedBox(height: 6),
      Text(
        overdue
            ? 'Bấm "Tôi an toàn" ngay nếu bạn vẫn ổn để huỷ gửi.'
            : '${_sendingDetail(contacts)} Bạn có thể đóng app.',
        textAlign: TextAlign.center,
        style: AppTextStyles.caption,
      ),
    ],
  );
}

/// Biểu tượng tròn đầu dải "Báo an toàn" ở Home.
class _BannerBadge extends StatelessWidget {
  const _BannerBadge({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      shape: BoxShape.circle,
    ),
    child: child,
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
  int _step = CheckInNotifier.durations.indexOf(
    CheckInNotifier.defaultDuration,
  );
  bool _busy = false;

  Duration get _duration => CheckInNotifier.durations[_step];

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
    final now = DateTime.now();
    final sending = status.isSending(now);
    final overdue = status.isOverdue(now);
    final contacts = widget.settings.contacts.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status.hasResult(now)) ...[
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
              else if (sending)
                SendingSosState(contacts: contacts)
              else if (deadline != null && overdue) ...[
                SendingSosState(contacts: contacts, overdue: true),
                const SizedBox(height: 14),
                AppButton(
                  label: 'Tôi an toàn',
                  icon: Icons.verified_user_outlined,
                  isLoading: _busy,
                  onPressed: () =>
                      _run(() => ref.read(checkInProvider.notifier).cancel()),
                ),
              ] else if (deadline != null) ...[
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
                  label: 'Thêm ${durationLabel(CheckInNotifier.extension)}',
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
                Center(
                  child: Text(
                    'Tự gửi SOS sau ${durationLabel(_duration)}',
                    key: const ValueKey('check-in-duration'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.cardTitle,
                  ),
                ),
                Slider(
                  key: const ValueKey('check-in-slider'),
                  value: _step.toDouble(),
                  max: (CheckInNotifier.durations.length - 1).toDouble(),
                  divisions: CheckInNotifier.durations.length - 1,
                  label: durationLabel(_duration),
                  semanticFormatterCallback: (_) => durationLabel(_duration),
                  onChanged: (value) => setState(() => _step = value.round()),
                ),
                Row(
                  children: [
                    Text(
                      durationLabel(CheckInNotifier.durations.first),
                      style: AppTextStyles.caption,
                    ),
                    const Spacer(),
                    Text(
                      durationLabel(CheckInNotifier.durations.last),
                      style: AppTextStyles.caption,
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
    final now = DateTime.now();
    if (status.hasResult(now)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _FiredNotice(status: status),
      );
    }
    final sending = status.isSending(now);
    final deadline = status.deadline;
    if (deadline == null && !sending) {
      return const SizedBox.shrink();
    }
    final overdue = status.isOverdue(now);
    final contacts = ref.watch(sosSettingsProvider).value?.contacts.length ?? 0;
    const spinner = SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.red),
    );
    // Nền thẻ giữ màu mặc định; màu chỉ ở biểu tượng và nút để chữ dễ đọc.
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        key: const ValueKey('check-in-banner'),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        onTap: () => Navigator.pushNamed(context, RouteNames.sos),
        child: Row(
          children: [
            sending || overdue
                ? const _BannerBadge(color: AppColors.red, child: spinner)
                : const _BannerBadge(
                    color: AppColors.green,
                    child: Icon(
                      Icons.timer_outlined,
                      color: AppColors.green,
                      size: 22,
                    ),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: sending || overdue
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _sendingTitle(overdue: overdue && !sending),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          sending
                              ? _sendingDetail(contacts)
                              : 'Bấm "Tôi an toàn" để huỷ.',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Báo an toàn · còn',
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        CountdownText(
                          deadline: deadline!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
            ),
            if (!sending) ...[
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const ValueKey('check-in-safe'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: const Color(0xFF06261A),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => _guard(
                  context,
                  () => ref.read(checkInProvider.notifier).cancel(),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Tôi an toàn'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
