import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/audio_service.dart';
import '../../../core/services/background_loop.dart';
import '../../../core/services/background_preview.dart';
import '../../../core/services/file_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../widgets/scenario_picker_card.dart';
import '../../../shared/enums/call_interface.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../scenarios/data/scenario_lookup.dart';
import '../../scenarios/providers/scenario_provider.dart';
import '../../settings/models/app_settings.dart';
import '../../settings/providers/settings_provider.dart';
import '../models/combo_model.dart';
import '../providers/combo_provider.dart';
import '../widgets/background_preview_controls.dart';
import '../widgets/background_sound_selector.dart';
import '../widgets/call_interface_selector.dart';
import '../widgets/call_type_selector.dart';
import '../widgets/ringtone_selector.dart';
import '../widgets/video_end_action_selector.dart';
import '../widgets/video_recorder_card.dart';
import '../widgets/voice_recorder_card.dart';

class ComboFormScreen extends ConsumerStatefulWidget {
  const ComboFormScreen({super.key, this.combo});
  final ComboModel? combo;
  @override
  ConsumerState<ComboFormScreen> createState() => _ComboFormScreenState();
}

class _ComboFormScreenState extends ConsumerState<ComboFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _callerController;
  late String _scenarioId;
  late CallInterface _callInterface;
  late RingtoneType _ringtoneType;
  late Set<String> _backgrounds;
  String? _ringtonePath;
  String? _customBackgroundPath;
  String? _voicePath;
  late CallType _callType;
  String? _videoPath;
  late VideoEndAction _videoEndAction;
  bool _isSaving = false;
  bool _isPicking = false;
  bool _isRecording = false;

  /// Bản thu giọng và video tạo ra trong lần sửa này. Bản nào không được lưu thì xoá file.
  final _takes = <String>{};
  bool _committed = false;
  late final FileService _files;
  late final BackgroundPreviewNotifier _backgroundPreview;

  /// Âm lượng nền đang kéo trên thanh trượt, trước khi lưu vào cài đặt.
  double? _draggingVolume;
  bool _hasChanges = false;
  bool _hasSaved = false;
  @override
  void initState() {
    super.initState();
    final combo = widget.combo;
    _nameController = TextEditingController(text: combo?.name ?? '');
    _callerController = TextEditingController(text: combo?.callerName ?? '');
    for (final controller in [_nameController, _callerController]) {
      controller.addListener(() {
        if (!_hasChanges) {
          setState(() => _hasChanges = true);
        }
      });
    }
    _scenarioId = combo?.scenarioId ?? 'boss';
    _callInterface = combo?.callInterface ?? CallInterface.zalo;
    _ringtoneType = combo?.ringtoneType ?? RingtoneType.interfaceDefault;
    _backgrounds = {...?combo?.backgroundSoundPaths};
    _ringtonePath = combo?.ringtonePath;
    _customBackgroundPath = combo?.customBackgroundPath;
    _voicePath = combo?.voicePath;
    _callType = combo?.callType ?? CallType.voice;
    _videoPath = combo?.videoPath;
    _videoEndAction = combo?.videoEndAction ?? VideoEndAction.hangUp;
    _files = ref.read(fileServiceProvider);
    _backgroundPreview = ref.read(backgroundPreviewProvider.notifier);
  }

  @override
  void dispose() {
    // Không đổi provider khi cây widget đang dựng lại: dừng ngay sau đó.
    final preview = _backgroundPreview;
    unawaited(Future.microtask(preview.stop));
    _nameController.dispose();
    _callerController.dispose();
    // Thoát mà không lưu: các bản thu mới không ai dùng nữa.
    if (!_committed) {
      for (final take in _takes) {
        _files.deleteAudio(take);
      }
    }
    super.dispose();
  }

  void _onVoiceChanged(String? path) {
    final previous = _voicePath;
    _change(() => _voicePath = path);
    _replaceTake(previous, path);
  }

  void _onVideoChanged(String? path) {
    final previous = _videoPath;
    _change(() => _videoPath = path);
    _replaceTake(previous, path);
  }

  /// Bản thu/quay của lần sửa này bị thay hoặc xoá trước khi lưu: xoá file luôn.
  /// File cũ của combo thì để lại, chỉ dọn sau khi lưu.
  void _replaceTake(String? previous, String? path) {
    if (previous != null && previous != path && _takes.remove(previous)) {
      _files.deleteAudio(previous);
    }
    if (path != null) {
      _takes.add(path);
    }
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
    voicePath: _voicePath,
    // Giọng không đổi thì giữ id trên server; thu lại/xoá thì bỏ để gửi bản mới.
    voiceMediaId: _voicePath != null && _voicePath == widget.combo?.voicePath
        ? widget.combo?.voiceMediaId
        : null,
    callType: _callType,
    videoPath: _videoPath,
    videoMediaId: _videoPath != null && _videoPath == widget.combo?.videoPath
        ? widget.combo?.videoMediaId
        : null,
    callerName: ComboModel.cleanCallerName(_callerController.text),
    videoEndAction: _videoEndAction,
  );

  bool get _isVideo => _callType == CallType.video;

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
        if (!isRingtone) {
          _refreshBackgroundPreview();
        }
      }
    } on FormatException catch (error) {
      // Vượt dung lượng, file trống...: báo đúng lý do kèm dung lượng thật.
      if (mounted) {
        showMessage(context, error.message);
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
    if (!_formKey.currentState!.validate() ||
        _isSaving ||
        _isPicking ||
        _isRecording) {
      return;
    }
    // Gọi video không có kịch bản thoại: thiếu video thì cuộc gọi im lặng.
    if (_isVideo && _videoPath == null) {
      showMessage(context, 'Hãy quay hoặc chọn video người gọi.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _stopPreviews();
      final rejection = await ref
          .read(comboListProvider.notifier)
          .saveCombo(_draft());
      _committed = true;
      if (mounted && rejection != null) {
        showMessage(
          context,
          'Đã lưu combo trên máy nhưng chưa đồng bộ được file: $rejection',
        );
      }
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
        await playback.play(
          ScenarioLookup.resolve(
            _scenarioId,
            ref.read(scenarioLibraryProvider).value,
          ).dialogue,
        );
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

  double get _backgroundVolume =>
      _draggingVolume ??
      ref.read(settingsProvider).value?.backgroundVolume ??
      AppSettings.defaultBackgroundVolume;

  List<String> get _backgroundSources =>
      backgroundSources(_backgrounds, _customBackgroundPath);

  Future<void> _toggleBackgroundPreview() async {
    if (ref.read(backgroundPreviewProvider)) {
      await _backgroundPreview.stop();
      return;
    }
    await _playBackgroundPreview();
  }

  Future<void> _playBackgroundPreview() async {
    try {
      await _backgroundPreview.play(_backgroundSources, _backgroundVolume);
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không phát được âm nền. Thử chọn âm nền khác.');
      }
    }
  }

  /// Đang nghe thử mà đổi âm nền thì nghe ngay danh sách mới.
  void _refreshBackgroundPreview() {
    if (!ref.read(backgroundPreviewProvider)) {
      return;
    }
    if (_backgroundSources.isEmpty) {
      unawaited(_backgroundPreview.stop());
    } else {
      unawaited(_playBackgroundPreview());
    }
  }

  void _onVolumeChanged(double value) {
    setState(() => _draggingVolume = value);
    unawaited(_backgroundPreview.setVolume(value));
  }

  Future<void> _saveVolume(double value) async {
    try {
      await ref
          .read(settingsProvider.notifier)
          .modify((current) => current.copyWith(backgroundVolume: value));
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không lưu được âm lượng âm nền.');
      }
    } finally {
      if (mounted) {
        setState(() => _draggingVolume = null);
      }
    }
  }

  /// Dừng mọi thứ đang nghe thử trong form (giọng kịch bản, âm nền).
  Future<void> _stopPreviews() async {
    await ref.read(scenarioPlaybackProvider.notifier).stop();
    await _backgroundPreview.stop();
  }

  void _onRecordingChanged(bool value) {
    // Đang thu giọng thì tắt âm nền nghe thử để không lọt vào bản thu.
    if (value) {
      unawaited(_backgroundPreview.stop());
    }
    setState(() => _isRecording = value);
  }

  Future<void> _onBack(bool didPop) async {
    if (didPop) {
      await _stopPreviews();
      return;
    }
    if (_isSaving) {
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
      await _stopPreviews();
      setState(() => _hasSaved = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  Future<void> _chooseScenario() async {
    await _stopPreviews();
    if (!mounted) {
      return;
    }
    final selected = await Navigator.pushNamed(
      context,
      RouteNames.scenarios,
      arguments: ScenarioLookup.canonicalId(_scenarioId),
    );
    if (selected is String && mounted) {
      _change(() => _scenarioId = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scenario = ScenarioLookup.resolve(
      _scenarioId,
      ref.watch(scenarioLibraryProvider).value,
    );
    final isPlaying = ref.watch(scenarioPlaybackProvider);
    final isBackgroundPlaying = ref.watch(backgroundPreviewProvider);
    final backgroundVolume =
        ref.watch(settingsProvider).value?.backgroundVolume ??
        AppSettings.defaultBackgroundVolume;
    return PopScope(
      // Đang lưu thì không cho thoát: tránh "Bỏ thay đổi" xoá bản thu vừa lưu.
      canPop: !_isSaving && (_hasSaved || !_hasChanges),
      onPopInvokedWithResult: (didPop, _) => _onBack(didPop),
      child: ScreenShell(
        title: widget.combo == null ? 'Tạo combo' : 'Chỉnh sửa combo',
        bottom: AppButton(
          label: 'Lưu combo',
          icon: Icons.check_rounded,
          isLoading: _isSaving,
          onPressed: _isPicking || _isRecording ? null : _save,
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
              const _FieldLabel('Loại cuộc gọi'),
              CallTypeSelector(
                selected: _callType,
                onChanged: (value) {
                  // Gọi video không có âm nền: tắt nghe thử.
                  if (value == CallType.video) {
                    unawaited(_backgroundPreview.stop());
                  }
                  _change(() => _callType = value);
                },
              ),
              const SizedBox(height: 18),
              // Gọi video chỉ cần tên người gọi và video; không dùng kịch bản thoại.
              if (_isVideo) ...[
                const _FieldLabel('Tên người gọi'),
                AppTextField(
                  controller: _callerController,
                  hint: 'Ví dụ: Mẹ',
                  validator: (value) =>
                      _isVideo && (value == null || value.trim().isEmpty)
                      ? 'Nhập tên hiện trên cuộc gọi video'
                      : null,
                ),
                const SizedBox(height: 18),
                VideoRecorderCard(
                  videoPath: _videoPath,
                  onChanged: _onVideoChanged,
                  onBusyChanged: _onRecordingChanged,
                ),
                const SizedBox(height: 18),
                const _FieldLabel('Khi video kết thúc'),
                VideoEndActionSelector(
                  selected: _videoEndAction,
                  onChanged: (value) => _change(() => _videoEndAction = value),
                ),
              ] else ...[
                ScenarioPickerCard(
                  scenario: scenario,
                  isPlaying: isPlaying,
                  onChoose: _chooseScenario,
                  onPreview: _previewScenario,
                ),
                const SizedBox(height: 10),
                VoiceRecorderCard(
                  voicePath: _voicePath,
                  onChanged: _onVoiceChanged,
                  onRecordingChanged: _onRecordingChanged,
                ),
              ],
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
              // Video đã có tiếng của người gọi; âm nền chỉ dùng cho gọi thoại.
              if (!_isVideo) ...[
                const SizedBox(height: 20),
                const _FieldLabel('Âm nền & nhạc nền trong cuộc gọi'),
                BackgroundSoundSelector(
                  selected: _backgrounds,
                  hasCustomFile: _customBackgroundPath != null,
                  onChanged: (key) {
                    _change(() {
                      if (!_backgrounds.add(key)) {
                        _backgrounds.remove(key);
                      }
                    });
                    _refreshBackgroundPreview();
                  },
                  onPickFile: () => _pickAudio(isRingtone: false),
                  onRemoveCustom: () {
                    _change(() => _customBackgroundPath = null);
                    _refreshBackgroundPreview();
                  },
                ),
                const SizedBox(height: 10),
                BackgroundPreviewControls(
                  hasSelection: _backgroundSources.isNotEmpty,
                  isPlaying: isBackgroundPlaying,
                  volume: _draggingVolume ?? backgroundVolume,
                  onToggle: _toggleBackgroundPreview,
                  onVolumeChanged: _onVolumeChanged,
                  onVolumeChangeEnd: _saveVolume,
                ),
              ],
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
                onPressed: _isPicking || _isRecording
                    ? null
                    : () async {
                        await _stopPreviews();
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
