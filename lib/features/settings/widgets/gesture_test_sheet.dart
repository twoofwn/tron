import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_button.dart';
import '../../activation/providers/activation_provider.dart';
import '../../activation/services/gesture_detectors.dart';
import '../../activation/services/motion_trigger_service.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';

/// Hiện cử chỉ đang được nhận để người dùng chỉnh độ nhạy, không hẹn cuộc gọi.
class GestureTestSheet extends ConsumerStatefulWidget {
  const GestureTestSheet({super.key});

  @override
  ConsumerState<GestureTestSheet> createState() => _GestureTestSheetState();
}

class _GestureTestSheetState extends ConsumerState<GestureTestSheet> {
  // Dùng instance riêng để không tranh cảm biến với service đang hẹn giờ.
  final _service = MotionTriggerService();
  StreamSubscription<TriggerEvent>? _subscription;
  String _last = 'Chưa nhận cử chỉ nào. Thử lật úp máy hoặc gõ lưng.';
  late final GestureTestingNotifier _testing;

  @override
  void initState() {
    super.initState();
    _testing = ref.read(gestureTestingProvider.notifier)..setTesting(true);
    final sensitivity =
        ref.read(settingsProvider).value?.sensitivity ??
        TriggerSensitivity.medium;
    _service.start(flip: true, knock: true, sensitivity: sensitivity);
    _subscription = _service.triggers.listen((event) {
      if (!mounted) {
        return;
      }
      setState(() {
        _last = event.kind == TriggerKind.flip
            ? 'Đã nhận: lật máy ✓'
            : 'Đã nhận: gõ lưng ✓';
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _service.dispose();
    _testing.setTesting(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Thử cử chỉ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(_last),
          const SizedBox(height: 14),
          const Text(
            'Nếu cử chỉ không được nhận, hãy chọn độ nhạy cao hơn. '
            'Nếu nhận nhầm khi đang cầm máy đi lại, hãy chọn độ nhạy thấp hơn.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Xong',
            isSecondary: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
