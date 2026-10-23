import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/scenario.dart';

class ScenarioRepository extends ChangeNotifier {
  ScenarioRepository({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;
  List<Scenario> _bundled = const [];
  List<Scenario> _user = const [];
  List<AmbientSound> _customBackgrounds = const [];
  bool isLoaded = false;

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

  Future<Directory> get _storageDirectory async {
    final directory = await _documentsDirectory();
    final storage = Directory('${directory.path}/escapehatch');
    if (!await storage.exists()) await storage.create(recursive: true);
    return storage;
  }

  Future<void> load() async {
    final raw = await rootBundle.loadString('assets/scenarios/scenarios.json');
    final bundled = (jsonDecode(raw) as List<dynamic>)
        .map((entry) => Scenario.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
    final storage = await _storageDirectory;
    final userFile = File('${storage.path}/user_scenarios.json');
    final backgroundFile = File('${storage.path}/backgrounds.json');
    final users = await _readList(userFile);
    final customBackgrounds = await _readList(backgroundFile);
    _bundled = bundled;
    _user = users
        .map((entry) => Scenario.fromJson(entry))
        .toList(growable: false);
    _customBackgrounds = customBackgrounds
        .map((entry) => AmbientSound.fromJson(entry))
        .toList(growable: false);
    isLoaded = true;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _readList(File file) async {
    if (!await file.exists()) return const [];
    final value = jsonDecode(await file.readAsString()) as List<dynamic>;
    return value.cast<Map<String, dynamic>>();
  }

  Future<void> _writeList(File file, List<Map<String, dynamic>> values) async {
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(values), flush: true);
    await temporary.rename(file.path);
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
    final storage = await _storageDirectory;
    await _writeList(
      File('${storage.path}/user_scenarios.json'),
      updated.map((item) => item.toJson()).toList(),
    );
    _user = updated;
    notifyListeners();
  }

  Future<String> importAudio(Uint8List bytes, String originalName) async {
    final extension = originalName.split('.').last.toLowerCase();
    if (!{'mp3', 'm4a', 'wav'}.contains(extension)) {
      throw const FormatException('Chỉ hỗ trợ MP3, M4A hoặc WAV.');
    }
    if (bytes.isEmpty) throw const FormatException('File âm thanh trống.');
    final storage = await _storageDirectory;
    final audioDirectory = Directory('${storage.path}/audio');
    if (!await audioDirectory.exists()) {
      await audioDirectory.create(recursive: true);
    }
    final destination = File(
      '${audioDirectory.path}/${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await destination.writeAsBytes(bytes, flush: true);
    return destination.path;
  }

  Future<void> addBackground(AmbientSound background) async {
    final updated = [..._customBackgrounds, background];
    final storage = await _storageDirectory;
    await _writeList(
      File('${storage.path}/backgrounds.json'),
      updated.map((item) => item.toJson()).toList(),
    );
    _customBackgrounds = updated;
    notifyListeners();
  }
}
