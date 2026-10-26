import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
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
      audioPath: 'audio/ambient/car.wav',
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
      audioPath: 'audio/ambient/office.wav',
    ),
    AmbientSound(
      id: 'rain',
      title: 'Trời mưa',
      iconName: 'rain',
      audioPath: 'audio/ambient/rain.wav',
    ),
    AmbientSound(
      id: 'dog',
      title: 'Chó sủa',
      iconName: 'dog',
      audioPath: 'audio/ambient/dog.wav',
    ),
    AmbientSound(
      id: 'cafe',
      title: 'Nhạc cà phê',
      iconName: 'cafe',
      audioPath: 'audio/ambient/cafe.wav',
    ),
  ];

  List<Scenario> get scenarios => List.unmodifiable([..._bundled, ..._user]);
  List<AmbientSound> get backgrounds =>
      List.unmodifiable([...bundledBackgrounds, ..._customBackgrounds]);

  Scenario? findScenario(String id) {
    for (final scenario in scenarios) {
      if (scenario.id == id) return scenario;
    }
    return null;
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

  Future<String> importAudio(Uint8List bytes, String originalName) async {
    final extension = originalName.split('.').last.toLowerCase();
    if (!{'mp3', 'm4a', 'wav'}.contains(extension)) {
      throw const FormatException('Chỉ hỗ trợ MP3, M4A hoặc WAV.');
    }
    if (bytes.isEmpty) throw const FormatException('File âm thanh trống.');

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
