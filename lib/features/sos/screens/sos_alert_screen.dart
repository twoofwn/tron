import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../providers/sos_alert_controller.dart';

const _background = Color(0xFF2A0D12);
const _soft = Color(0xFFFFC9CE);

/// Màn SOS: đếm ngược (có nút hủy) → lấy vị trí → gửi tin → gọi → kết quả.
class SosAlertScreen extends ConsumerStatefulWidget {
  const SosAlertScreen({super.key});

  @override
  ConsumerState<SosAlertScreen> createState() => _SosAlertScreenState();
}

class _SosAlertScreenState extends ConsumerState<SosAlertScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(ref.read(sosAlertProvider.notifier).start()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sosAlertProvider, (previous, next) {
      if (next.phase == SosPhase.countdown &&
          next.secondsLeft != previous?.secondsLeft) {
        unawaited(HapticFeedback.heavyImpact());
      }
      if (next.phase == SosPhase.cancelled) {
        // Đợi khung hình sau để PopScope đã cho phép thoát.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).maybePop();
          }
        });
      }
    });
    final state = ref.watch(sosAlertProvider);
    final busy = switch (state.phase) {
      SosPhase.locating || SosPhase.sending || SosPhase.calling => true,
      _ => false,
    };
    return PopScope(
      // Đang gửi thì không cho thoát giữa chừng; đang đếm ngược thì thoát = hủy.
      canPop: !busy && state.phase != SosPhase.countdown,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.phase == SosPhase.countdown) {
          ref.read(sosAlertProvider.notifier).cancel();
        }
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: _background,
          textTheme: Theme.of(context).textTheme
              .apply(bodyColor: Colors.white, displayColor: Colors.white),
        ),
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: switch (state.phase) {
                  SosPhase.countdown => _Countdown(state: state),
                  SosPhase.cancelled => const SizedBox.shrink(),
                  _ => _Progress(state: state),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Countdown extends ConsumerWidget {
  const _Countdown({required this.state});
  final SosAlertState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = state.deliveries.length;
    // Máy nhỏ hoặc chữ to: vòng tròn nhỏ lại, thiếu chỗ thì cuộn được.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
          ),
          child: IntrinsicHeight(
            child: _content(
              context,
              ref,
              count,
              (constraints.maxHeight * 0.28).clamp(110.0, 180.0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    int count,
    double circle,
  ) {
    return Column(
      children: [
        const Spacer(),
        const Text(
          'Sắp gửi SOS',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),
        Container(
          width: circle,
          height: circle,
          alignment: Alignment.center,
          padding: EdgeInsets.all(circle * 0.2),
          decoration: const BoxDecoration(
            color: AppColors.red,
            shape: BoxShape.circle,
          ),
          child: FittedBox(
            child: Text(
              state.settings == null ? '' : '${state.secondsLeft}',
              key: const ValueKey('sos-seconds'),
              style: const TextStyle(
                fontSize: 84,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          state.settings?.autoCall == true && count > 0
              ? 'Gửi tin cho $count người rồi gọi '
                    '${state.deliveries.first.contact.label}.'
              : 'Gửi tin cho $count người.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _soft),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _background,
              minimumSize: const Size.fromHeight(64),
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => ref.read(sosAlertProvider.notifier).cancel(),
            child: const Text('HỦY'),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: state.settings == null
              ? null
              : () => ref.read(sosAlertProvider.notifier).sendNow(),
          child: const Text('Gửi ngay', style: TextStyle(color: _soft)),
        ),
      ],
    );
  }
}

class _Progress extends ConsumerWidget {
  const _Progress({required this.state});
  final SosAlertState state;

  String get _title => switch (state.phase) {
    SosPhase.locating => 'Đang lấy vị trí…',
    SosPhase.sending => 'Đang gửi tin nhắn…',
    SosPhase.calling => 'Đang gọi…',
    _ when state.deliveries.isEmpty => 'Chưa có người liên hệ',
    _ when state.hasFailures => 'Chưa gửi được hết',
    _ => 'Đã gửi SOS',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(sosAlertProvider.notifier);
    final done = state.phase == SosPhase.done;
    final next = state.nextCallIndex;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            if (!done) ...[
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Text(
                _title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.locationTried)
          Text(
            state.location == null
                ? 'Không lấy được vị trí: tin vẫn được gửi, không kèm vị trí.'
                : 'Đã gửi kèm vị trí (sai số ~${state.location!.accuracy?.round() ?? '?'} m).',
            style: const TextStyle(color: _soft),
          ),
        if (state.deliveries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Thêm người liên hệ trong cài đặt SOS. Bạn vẫn có thể gọi số khẩn cấp.',
              style: TextStyle(color: _soft),
            ),
          ),
        const SizedBox(height: 18),
        for (final (index, delivery) in state.deliveries.indexed)
          _DeliveryTile(
            delivery: delivery,
            called: state.calledIndex == index,
            directCall: state.directCall,
            onRetry: done ? () => controller.retry(delivery.contact.id) : null,
          ),
        if (done) ...[
          const SizedBox(height: 22),
          if (next != null)
            _ActionButton(
              icon: Icons.call_rounded,
              label: state.calledIndex == null
                  ? 'Gọi ${state.deliveries[next].contact.label}'
                  : 'Gọi người tiếp theo: ${state.deliveries[next].contact.label}',
              primary: true,
              onPressed: controller.callNext,
            ),
          if (state.calledIndex != null)
            _ActionButton(
              icon: Icons.replay_rounded,
              label:
                  'Gọi lại ${state.deliveries[state.calledIndex!].contact.label}',
              onPressed: () => controller.callContact(state.calledIndex!),
            ),
          Row(
            children: [
              for (final (number, name) in const [
                ('113', 'Công an'),
                ('115', 'Cấp cứu'),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _ActionButton(
                      icon: Icons.local_phone_outlined,
                      label: '$number · $name',
                      onPressed: () => controller.dialEmergency(number),
                    ),
                  ),
                ),
            ],
          ),
          if (state.message != null) ...[
            const SizedBox(height: 18),
            const Text('Nội dung đã gửi', style: TextStyle(color: _soft)),
            const SizedBox(height: 6),
            SelectableText(state.message!),
          ],
          const SizedBox(height: 22),
          if (state.deliveries.isEmpty)
            TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, RouteNames.sos),
              child: const Text(
                'Thiết lập SOS',
                style: TextStyle(color: Colors.white),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Đóng', style: TextStyle(color: _soft)),
          ),
        ],
      ],
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  const _DeliveryTile({
    required this.delivery,
    required this.called,
    required this.directCall,
    this.onRetry,
  });

  final SosDelivery delivery;
  final bool called;
  final bool directCall;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (delivery.status) {
      DeliveryStatus.pending => (Icons.schedule_rounded, _soft, 'Chờ gửi'),
      DeliveryStatus.sending => (Icons.sms_outlined, _soft, 'Đang gửi…'),
      DeliveryStatus.sent => (
        Icons.check_circle_rounded,
        AppColors.green,
        'Đã gửi',
      ),
      DeliveryStatus.manual => (
        Icons.sms_outlined,
        AppColors.accent,
        'Đã mở app tin nhắn: bấm gửi',
      ),
      DeliveryStatus.failed => (
        Icons.error_outline_rounded,
        AppColors.accent,
        delivery.error == 'permission' ? 'Chưa có quyền gửi SMS' : 'Gửi lỗi',
      ),
    };
    final callNote = called
        ? (directCall ? ' · đã gọi' : ' · đã mở màn gọi')
        : '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(
        delivery.contact.label,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text('$text$callNote', style: TextStyle(color: color)),
      trailing: delivery.status == DeliveryStatus.failed && onRetry != null
          ? TextButton(
              onPressed: onRetry,
              child: const Text(
                'Gửi lại',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: SizedBox(
      width: double.infinity,
      child: primary
          ? FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _background,
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label, textAlign: TextAlign.center),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: _soft),
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label, textAlign: TextAlign.center),
            ),
    ),
  );
}
