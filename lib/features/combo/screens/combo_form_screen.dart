import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/file_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../widgets/scenario_picker_card.dart';
import '../../../shared/enums/call_interface.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../scenario/repositories/scenario_repository.dart';
import '../models/combo_model.dart';
import '../providers/combo_provider.dart';
import '../widgets/background_sound_selector.dart';
import '../widgets/call_interface_selector.dart';
import '../widgets/ringtone_selector.dart';

class ComboFormScreen extends ConsumerStatefulWidget {
  const ComboFormScreen({super.key, this.combo});
  final ComboModel? combo;
  @override
  ConsumerState<ComboFormScreen> createState() => _ComboFormScreenState();
}

class _ComboFormScreenState extends ConsumerState<ComboFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _scenarioId;
  late CallInterface _callInterface;
  late RingtoneType _ringtoneType;
  late Set<String> _backgrounds;
  String? _ringtonePath;
  String? _customBackgroundPath;
  bool _isSaving = false;
  bool _isPicking = false;
  bool _hasChanges = false;
  bool _hasSaved = false;
  @override
  void initState() {
    super.initState();
    final combo = widget.combo;
    _nameController = TextEditingController(text: combo?.name ?? '');
    _nameController.addListener(() {
      if (!_hasChanges) {
        setState(() => _hasChanges = true);
      }
    });
    _scenarioId = combo?.scenarioId ?? 'boss';
    _callInterface = combo?.callInterface ?? CallInterface.zalo;
    _ringtoneType = combo?.ringtoneType ?? RingtoneType.interfaceDefault;
    _backgrounds = {...?combo?.backgroundSoundPaths};
    _ringtonePath = combo?.ringtonePath;
    _customBackgroundPath = combo?.customBackgroundPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  ComboModel _draft() => ComboModel(
    id: widget.combo?.id ?? const Uuid().v4(),
    name: _nameController.text.trim().isEmpty
        ? 'Cuộc gọi xem trước'
        : _nameController.text.trim(),
    scenarioId: _scenarioId,
    callInterface: _callInterface,
    createdAt: widget.combo?.createdAt ?? DateTime.now(),
    ringtoneType: _ringtoneType,
    ringtonePath: _ringtonePath,
    backgroundSoundPaths: _backgrounds.toList(),
    customBackgroundPath: _customBackgroundPath,
  );
  void _change(VoidCallback change) {
    setState(() {
      change();
      _hasChanges = true;
    });
  }

  Future<void> _pickAudio({required bool isRingtone}) async {
    if (_isPicking) {
      return;
    }
    setState(() => _isPicking = true);
    try {
      final path = await ref.read(fileServiceProvider).pickAudio();
      if (mounted && path != null) {
        _change(() {
          if (isRingtone) {
            _ringtonePath = path;
            _ringtoneType = RingtoneType.custom;
          } else {
            _customBackgroundPath = path;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Không thể nhập âm thanh. Chọn file MP3 tối đa 10 MB.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving || _isPicking) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(scenarioPlaybackProvider.notifier).stop();
      await ref.read(comboListProvider.notifier).saveCombo(_draft());
      if (mounted) {
        setState(() {
          _hasSaved = true;
          _hasChanges = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không thể lưu combo. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _previewScenario() async {
    try {
      final playback = ref.read(scenarioPlaybackProvider.notifier);
      if (ref.read(scenarioPlaybackProvider)) {
        await playback.stop();
      } else {
        await playback.play(ScenarioRepository.find(_scenarioId).dialogue);
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Không phát được giọng đọc. Kiểm tra giọng tiếng Việt của thiết bị.',
        );
      }
    }
  }

  Future<void> _onBack(bool didPop) async {
    if (didPop) {
      await ref.read(scenarioPlaybackProvider.notifier).stop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ thay đổi?'),
        content: const Text('Combo của bạn chưa được lưu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục sửa'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      await ref.read(scenarioPlaybackProvider.notifier).stop();
      setState(() => _hasSaved = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  Future<void> _chooseScenario() async {
    await ref.read(scenarioPlaybackProvider.notifier).stop();
    if (!mounted) {
      return;
    }
    final selected = await Navigator.pushNamed(
      context,
      RouteNames.scenarios,
      arguments: _scenarioId,
    );
    if (selected is String && mounted) {
      _change(() => _scenarioId = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scenario = ScenarioRepository.find(_scenarioId);
    final isPlaying = ref.watch(scenarioPlaybackProvider);
    return PopScope(
      canPop: _hasSaved || !_hasChanges,
      onPopInvokedWithResult: (didPop, _) => _onBack(didPop),
      child: ScreenShell(
        title: widget.combo == null ? 'Tạo combo' : 'Chỉnh sửa combo',
        bottom: AppButton(
          label: 'Lưu combo',
          icon: Icons.check_rounded,
          isLoading: _isSaving,
          onPressed: _isPicking ? null : _save,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
            children: [
              const _FieldLabel('Tên combo'),
              AppTextField(
                controller: _nameController,
                hint: 'Ví dụ: Sếp gọi gấp',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Hãy đặt tên cho combo của bạn'
                    : null,
              ),
              const SizedBox(height: 18),
              ScenarioPickerCard(
                scenario: scenario,
                isPlaying: isPlaying,
                onChoose: _chooseScenario,
                onPreview: _previewScenario,
              ),
              const SizedBox(height: 18),
              const _FieldLabel('Giao diện cuộc gọi'),
              CallInterfaceSelector(
                selected: _callInterface,
                onChanged: (value) => _change(() => _callInterface = value),
              ),
              const SizedBox(height: 20),
              const _FieldLabel('Nhạc chuông'),
              RingtoneSelector(
                selected: _ringtoneType,
                hasCustomFile: _ringtonePath != null,
                onChanged: (value) => _change(() => _ringtoneType = value),
                onPickFile: () => _pickAudio(isRingtone: true),
              ),
              const SizedBox(height: 20),
              const _FieldLabel('Âm nền & nhạc nền trong cuộc gọi'),
              BackgroundSoundSelector(
                selected: _backgrounds,
                hasCustomFile: _customBackgroundPath != null,
                onChanged: (key) => _change(() {
                  if (!_backgrounds.add(key)) {
                    _backgrounds.remove(key);
                  }
                }),
                onPickFile: () => _pickAudio(isRingtone: false),
                onRemoveCustom: () =>
                    _change(() => _customBackgroundPath = null),
              ),
              if (_isPicking)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Xem trước cuộc gọi',
                icon: Icons.play_circle_outline_rounded,
                isSecondary: true,
                onPressed: _isPicking
                    ? null
                    : () async {
                        await ref
                            .read(scenarioPlaybackProvider.notifier)
                            .stop();
                        if (context.mounted) {
                          Navigator.pushNamed(
                            context,
                            RouteNames.fakeCall,
                            arguments: _draft(),
                          );
                        }
                      },
              ),
              const SizedBox(height: 10),
              const Text(
                'Một cuộc gọi đúng lúc, một lối ra nhẹ nhàng.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
