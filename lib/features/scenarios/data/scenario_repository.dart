import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/file_service.dart';
import '../models/scenario.dart';

class ScenarioRepository extends ChangeNotifier {
  ScenarioRepository({
    Future<io.Directory> Function()? documentsDirectory,
    this.api,
  }) : _customDirectory = documentsDirectory;

  final Future<io.Directory> Function()? _customDirectory;
  final ApiClient? api;
  List<Scenario> _bundled = const [];
  List<Scenario> _user = const [];
  List<AmbientSound> _customBackgrounds = const [];
  bool isLoaded = false;

  static const _userScenariosKey = AppConfig.userScenariosKey;
  static const _backgroundsKey = AppConfig.backgroundsKey;

  static const bundledBackgrounds = [
    AmbientSound(
      id: 'car',
      title: 'Còi xe',
      iconName: 'car',
      audioPath: 'audio/backgrounds/traffic.mp3',
    ),
    AmbientSound(
      id: 'television',
      title: 'Tiếng TV',
      iconName: 'tv',
      audioPath: 'audio/ambient/television.wav',
    ),
    AmbientSound(
      id: 'office',
      title: 'Văn phòng',
      iconName: 'office',
      audioPath: 'audio/backgrounds/office.mp3',
    ),
    AmbientSound(
      id: 'rain',
      title: 'Trời mưa',
      iconName: 'rain',
      audioPath: 'audio/backgrounds/rain.mp3',
    ),
    AmbientSound(
      id: 'dog',
      title: 'Chó sủa',
      iconName: 'dog',
      audioPath: 'audio/backgrounds/dog.mp3',
    ),
    AmbientSound(
      id: 'cafe',
      title: 'Nhạc cà phê',
      iconName: 'cafe',
      audioPath: 'audio/ambient/cafe.wav',
    ),
  ];

  /// Kịch bản mẫu người dùng đã xoá khỏi kho (chỉ ẩn: combo đang dùng vẫn gọi
  /// được). Lưu trên máy.
  Set<String> _hidden = const {};
  static const _hiddenKey = 'tron.scenarios.hiddenBuiltIns';

  /// Kịch bản hiện trong kho. Bản sửa của kịch bản mẫu (kịch bản cá nhân cùng
  /// ID) đứng đúng chỗ của bản gốc; kịch bản mẫu đã ẩn không hiện.
  List<Scenario> get scenarios {
    final personal = {for (final scenario in _user) scenario.id: scenario};
    final bundledIds = {for (final scenario in _bundled) scenario.id};
    return List.unmodifiable([
      for (final scenario in _bundled)
        if (personal.containsKey(scenario.id) || !_hidden.contains(scenario.id))
          personal[scenario.id] ?? scenario,
      for (final scenario in _user)
        if (!bundledIds.contains(scenario.id)) scenario,
    ]);
  }

  List<AmbientSound> get backgrounds =>
      List.unmodifiable([...bundledBackgrounds, ..._customBackgrounds]);

  /// Tìm cả kịch bản mẫu đã ẩn, để combo đang dùng nó vẫn gọi được.
  Scenario? findScenario(String id) {
    for (final scenario in [..._user, ..._bundled]) {
      if (scenario.id == id) return scenario;
    }
    return null;
  }

  /// Số kịch bản mẫu đang bị ẩn khỏi kho. Bỏ qua ID đã lưu của kịch bản mẫu
  /// không còn trong app (ví dụ Chủ trọ cũ) và bản đã sửa vẫn đang hiện.
  int get hiddenBuiltInCount {
    final personalIds = {for (final scenario in _user) scenario.id};
    return _bundled
        .where(
          (scenario) =>
              _hidden.contains(scenario.id) &&
              !personalIds.contains(scenario.id),
        )
        .length;
  }

  /// Kịch bản cá nhân này là bản sửa của một kịch bản mẫu (cùng ID).
  bool isEditedBuiltIn(Scenario scenario) =>
      scenario.source == ScenarioSource.user &&
      _bundled.any((item) => item.id == scenario.id);

  /// Xoá khỏi kho. Kịch bản cá nhân bị xoá hẳn (kèm file giọng đã thu);
  /// kịch bản mẫu (kể cả bản đã sửa) chỉ bị ẩn, hiện lại được bằng
  /// [showHiddenBuiltIns].
  Future<void> deleteScenario(Scenario scenario) async {
    final isBuiltIn =
        scenario.source != ScenarioSource.user || isEditedBuiltIn(scenario);
    if (scenario.source == ScenarioSource.user) {
      await _removePersonal(scenario);
    }
    if (isBuiltIn) {
      await _setHidden({..._hidden, scenario.id});
    }
  }

  /// Bỏ bản sửa, dùng lại kịch bản mẫu gốc.
  Future<void> restoreBuiltIn(Scenario edited) async {
    if (!isEditedBuiltIn(edited)) return;
    await _removePersonal(edited);
  }

  /// Hiện lại mọi kịch bản mẫu đã xoá khỏi kho.
  Future<void> showHiddenBuiltIns() => _setHidden(const {});

  Future<void> _removePersonal(Scenario scenario) async {
    await deleteUserScenario(scenario.id);
    // File giọng chỉ kịch bản này dùng: xoá để khỏi chiếm bộ nhớ.
    final stillUsed = {
      for (final other in _user)
        for (final step in other.steps) ?step.audioPath,
    };
    for (final step in scenario.steps) {
      final path = step.audioPath;
      if (path != null && !isBundledAudio(path) && !stillUsed.contains(path)) {
        await deleteAudio(path);
      }
    }
  }

  Future<void> _setHidden(Set<String> hidden) async {
    _hidden = Set.unmodifiable(hidden);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_hiddenKey, hidden.toList());
    } catch (_) {}
  }

  AmbientSound? findBackground(String? id) {
    if (id == null) return null;
    for (final background in backgrounds) {
      if (background.id == id) return background;
    }
    return null;
  }

  bool get _hasCustomDir => _customDirectory != null;

  Future<io.Directory?> _getStorageDirectory() async {
    if (kIsWeb) return null;
    try {
      if (_customDirectory != null) {
        final dir = await _customDirectory();
        final storage = io.Directory('${dir.path}/escapehatch');
        if (!await storage.exists()) await storage.create(recursive: true);
        return storage;
      }
      final dir = await getApplicationDocumentsDirectory();
      final storage = io.Directory('${dir.path}/escapehatch');
      if (!await storage.exists()) await storage.create(recursive: true);
      return storage;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _readStoredList(
    String fileName,
    String prefKey,
  ) async {
    final storage = await _getStorageDirectory();
    if (storage != null) {
      final file = io.File('${storage.path}/$fileName');
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final decoded = jsonDecode(content) as List<dynamic>;
          return decoded.cast<Map<String, dynamic>>();
        } catch (_) {}
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    return const [];
  }

  Future<void> _writeStoredList(
    String fileName,
    String prefKey,
    List<Map<String, dynamic>> values,
  ) async {
    final storage = await _getStorageDirectory();
    if (storage != null) {
      try {
        final file = io.File('${storage.path}/$fileName');
        final temp = io.File('${file.path}.tmp');
        await temp.writeAsString(jsonEncode(values), flush: true);
        await temp.rename(file.path);
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, jsonEncode(values));
    } catch (_) {}
  }

  Future<void> load() async {
    List<Scenario> bundled = const [];
    try {
      final raw = await rootBundle.loadString(
        'assets/scenarios/scenarios.json',
      );
      bundled = (jsonDecode(raw) as List<dynamic>)
          .map((entry) => Scenario.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {}

    var users = <Scenario>[];
    var customBackgrounds = <AmbientSound>[];

    try {
      final userMaps = await _readStoredList(
        'user_scenarios.json',
        _userScenariosKey,
      );
      users = userMaps.map((entry) => Scenario.fromJson(entry)).toList();

      final bgMaps = await _readStoredList('backgrounds.json', _backgroundsKey);
      customBackgrounds = bgMaps
          .map((entry) => AmbientSound.fromJson(entry))
          .toList();
    } catch (_) {}

    if (api != null) {
      try {
        if (await api!.hasToken()) {
          final bundle = await api!.getJson('/scenarios');
          final remoteScenarios =
              (bundle['customScenarios'] as List?) ?? const [];
          final remoteAmbients =
              (bundle['customAmbientSounds'] as List?) ?? const [];

          final byId = <String, Scenario>{for (final s in users) s.id: s};
          for (final rawSc in remoteScenarios) {
            final map = Map<String, dynamic>.from(rawSc as Map);
            final sc = Scenario.fromJson(map);
            byId[sc.id] = sc;
          }
          users = byId.values.toList();
          await _writeStoredList(
            'user_scenarios.json',
            _userScenariosKey,
            users.map((item) => item.toJson()).toList(),
          );

          final bgById = <String, AmbientSound>{
            for (final b in customBackgrounds) b.id: b,
          };
          for (final rawBg in remoteAmbients) {
            final map = Map<String, dynamic>.from(rawBg as Map);
            final bg = AmbientSound.fromJson(map);
            bgById[bg.id] = bg;
          }
          customBackgrounds = bgById.values.toList();
          await _writeStoredList(
            'backgrounds.json',
            _backgroundsKey,
            customBackgrounds.map((item) => item.toJson()).toList(),
          );
        }
      } catch (_) {
        // Fallback to local
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _hidden = Set.unmodifiable(prefs.getStringList(_hiddenKey) ?? const []);
    } catch (_) {}

    _bundled = bundled;
    _user = List.unmodifiable(users);
    _customBackgrounds = List.unmodifiable(customBackgrounds);
    isLoaded = true;
    notifyListeners();
  }

  Future<void> saveUserScenario(Scenario scenario) async {
    if (scenario.source != ScenarioSource.user) {
      throw ArgumentError('Only personal scenarios can be saved');
    }
    final updated = [..._user];
    final index = updated.indexWhere((item) => item.id == scenario.id);
    if (index < 0) {
      updated.add(scenario);
    } else {
      updated[index] = scenario;
    }
    await _writeStoredList(
      'user_scenarios.json',
      _userScenariosKey,
      updated.map((item) => item.toJson()).toList(),
    );
    _user = updated;
    notifyListeners();

    if (api != null) {
      try {
        if (await api!.hasToken()) {
          await api!.postJson('/scenarios', _scenarioToServerMap(scenario));
        }
      } catch (_) {}
    }
  }

  Future<void> deleteUserScenario(String id) async {
    final updated = _user.where((item) => item.id != id).toList();
    await _writeStoredList(
      'user_scenarios.json',
      _userScenariosKey,
      updated.map((item) => item.toJson()).toList(),
    );
    _user = updated;
    notifyListeners();

    if (api != null) {
      try {
        if (await api!.hasToken()) {
          await api!.delete('/scenarios/$id');
        }
      } catch (_) {}
    }
  }

  /// Audio có sẵn trong app (`audio/voice/...`), không phải file người dùng
  /// thu hay nhập.
  static bool isBundledAudio(String path) =>
      !(path.startsWith('/') ||
          RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path) ||
          path.startsWith('data:') ||
          path.startsWith('blob:') ||
          path.startsWith('http://') ||
          path.startsWith('https://') ||
          path.startsWith('media:'));

  /// Xoá file âm thanh do app thu hoặc nhập cho kịch bản. Chỉ xoá file nằm
  /// trong thư mục audio của kho kịch bản; audio có sẵn, data URI và mọi file
  /// khác được bỏ qua.
  Future<void> deleteAudio(String path) async {
    final storage = await _getStorageDirectory();
    if (storage == null) return;
    final audioDirectory = '${storage.path}/audio/'.replaceAll(r'\', '/');
    final normalized = path.replaceAll(r'\', '/');
    if (!normalized.startsWith(audioDirectory) ||
        normalized.substring(audioDirectory.length).contains('/') ||
        normalized.contains('/../')) {
      return;
    }
    try {
      final file = io.File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // File đang được dùng hoặc đã bị xoá: để lần dọn sau.
    }
  }

  /// Bộ lọc của hộp chọn file: chỉ hiện file âm thanh được hỗ trợ.
  static const audioTypeGroups = [
    XTypeGroup(
      label: 'Âm thanh',
      extensions: ['mp3', 'm4a', 'wav'],
      mimeTypes: ['audio/mpeg', 'audio/mp4', 'audio/x-m4a', 'audio/wav'],
      uniformTypeIdentifiers: ['public.audio'],
    ),
  ];

  /// Câu báo lỗi cho người dùng khi nhập audio (không lộ tên lớp lỗi).
  static String importErrorMessage(Object error) => error is FormatException
      ? error.message
      : 'Không nhập được file âm thanh. Hãy thử file khác.';

  /// Nhập file người dùng chọn: kiểm tra đuôi và dung lượng TRƯỚC khi đọc,
  /// để file quá lớn bị từ chối ngay thay vì nạp hết vào bộ nhớ.
  Future<String> importAudioFile(XFile file) async {
    _checkExtension(file.name);
    FileService.ensureSize(
      await file.length(),
      limit: AppConstants.maxAudioBytes,
      what: 'File “${file.name}”',
    );
    return importAudio(await file.readAsBytes(), file.name);
  }

  static String _checkExtension(String name) {
    final extension = name.split('.').last.toLowerCase();
    if (!{'mp3', 'm4a', 'wav'}.contains(extension)) {
      throw const FormatException(
        'Chỉ hỗ trợ file âm thanh MP3, M4A hoặc WAV.',
      );
    }
    return extension;
  }

  Future<String> importAudio(Uint8List bytes, String originalName) async {
    final extension = _checkExtension(originalName);
    FileService.ensureSize(
      bytes.length,
      limit: AppConstants.maxAudioBytes,
      what: 'File “$originalName”',
    );

    final storage = await _getStorageDirectory();
    if (storage != null && !_hasCustomDir && !kIsWeb) {
      try {
        final audioDirectory = io.Directory('${storage.path}/audio');
        if (!await audioDirectory.exists()) {
          await audioDirectory.create(recursive: true);
        }
        final destination = io.File(
          '${audioDirectory.path}/${DateTime.now().microsecondsSinceEpoch}.$extension',
        );
        await destination.writeAsBytes(bytes, flush: true);
        return destination.path;
      } catch (_) {}
    }

    if (storage != null && _hasCustomDir) {
      final audioDirectory = io.Directory('${storage.path}/audio');
      if (!await audioDirectory.exists()) {
        await audioDirectory.create(recursive: true);
      }
      final destination = io.File(
        '${audioDirectory.path}/${DateTime.now().microsecondsSinceEpoch}.$extension',
      );
      await destination.writeAsBytes(bytes, flush: true);
      return destination.path;
    }

    // Web fallback: data URI
    final mime = extension == 'mp3'
        ? 'audio/mpeg'
        : extension == 'm4a'
        ? 'audio/mp4'
        : 'audio/wav';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  Future<void> addBackground(AmbientSound background) async {
    final updated = [..._customBackgrounds, background];
    await _writeStoredList(
      'backgrounds.json',
      _backgroundsKey,
      updated.map((item) => item.toJson()).toList(),
    );
    _customBackgrounds = updated;
    notifyListeners();

    if (api != null) {
      try {
        if (await api!.hasToken()) {
          await api!.postJson('/scenarios/ambient-sounds', {
            'id': background.id,
            'title': background.title,
            'iconName': background.iconName,
            'audioPath': background.audioPath,
            'mediaFileId': null,
            'legacyKey': background.id,
            'isCustom': true,
          });
        }
      } catch (_) {}
    }
  }

  static Map<String, dynamic> _scenarioToServerMap(Scenario sc) => {
    'id': sc.id,
    'title': sc.title,
    'category': sc.category.name,
    'source': 'user',
    'callerName': sc.callerName,
    'initial': sc.initial,
    'estimatedSeconds': sc.estimatedSeconds,
    'defaultBackgroundId': sc.defaultBackgroundId,
    'isPro': false,
    'steps': sc.steps
        .map(
          (st) => {
            'id': st.id,
            'type': st.type.name,
            'text': st.text,
            'audioPath': st.audioPath,
            'mediaFileId': null,
            'seconds': st.seconds,
          },
        )
        .toList(),
  };
}
