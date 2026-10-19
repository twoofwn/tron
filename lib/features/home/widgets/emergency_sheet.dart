import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../shared/widgets/screen_shell.dart';

final emergencyContactProvider =
    AsyncNotifierProvider<EmergencyContactNotifier, String>(
      EmergencyContactNotifier.new,
    );

class EmergencyContactNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async =>
      await ref.watch(storageServiceProvider).read('tron.emergency') ?? '';
  Future<void> save(String number) async {
    await ref.read(storageServiceProvider).write('tron.emergency', number);
    state = AsyncData(number);
  }
}

class EmergencySheet extends ConsumerStatefulWidget {
  const EmergencySheet({super.key});
  @override
  ConsumerState<EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends ConsumerState<EmergencySheet> {
  final _numberController = TextEditingController();
  bool _isSaving = false;
  @override
  void initState() {
    super.initState();
    ref.read(emergencyContactProvider.future).then((number) {
      if (mounted) {
        _numberController.text = number;
      }
    });
  }

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _saveAndCall() async {
    final number = _numberController.text.trim().replaceAll(
      RegExp(r'[\s()-]'),
      '',
    );
    if (!RegExp(r'^\+?[0-9]{3,15}$').hasMatch(number)) {
      showMessage(context, 'Nhập số điện thoại hợp lệ.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(emergencyContactProvider.notifier).save(number);
      if (!await launchUrl(Uri(scheme: 'tel', path: number))) {
        throw StateError('dialer');
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không mở được trình gọi điện trên thiết bị này.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      8,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 28,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Người bạn tin cậy',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Lưu số người thân để mở nhanh trình gọi điện khi bạn cần hỗ trợ.',
        ),
        const SizedBox(height: 20),
        AppTextField(
          controller: _numberController,
          hint: 'Số điện thoại liên hệ',
          keyboardType: TextInputType.phone,
          maxLength: 20,
        ),
        const SizedBox(height: 18),
        AppButton(
          label: 'Lưu và mở gọi điện',
          icon: Icons.phone_outlined,
          isLoading: _isSaving,
          onPressed: _saveAndCall,
        ),
      ],
    ),
  );
}
