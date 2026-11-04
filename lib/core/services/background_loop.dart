import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../constants/asset_paths.dart';
import 'file_service.dart';

/// Giọng và âm nền của người gọi: kiểu âm thanh cuộc gọi, ra loa trong hoặc
/// loa ngoài theo màn gọi. Âm nền không dùng kiểu "tín hiệu cuộc gọi": máy
/// giới hạn âm lượng kiểu đó nên âm nền gần như không nghe được.
const androidCallAudioAttributes = AndroidAudioAttributes(
  usage: AndroidAudioUsage.voiceCommunication,
  contentType: AndroidAudioContentType.speech,
);

/// Một âm nền phát lặp tới khi [dispose].
abstract class BackgroundLoop {
  /// [source] là khoá âm nền có sẵn (`traffic`, `rain`…) hoặc file riêng
  /// (`media:...`, đường dẫn tài nguyên).
  Future<void> start(String source, double volume);

  Future<void> setVolume(double volume);

  Future<void> dispose();
}

class JustAudioBackgroundLoop implements BackgroundLoop {
  /// [inCall]: phát kiểu âm thanh cuộc gọi (đi theo loa trong/loa ngoài).
  /// Không thì phát như nhạc thường, dùng cho nghe thử.
  JustAudioBackgroundLoop(this.files, {required this.inCall});

  final FileService files;
  final bool inCall;

  // Không tự tạm dừng khi giọng đọc hay app khác giành quyền phát: player
  // của just_audio dừng hẳn khi mất quyền lâu dài và không phát lại, làm âm
  // nền lúc có lúc không. Màn gọi và màn nghe thử tự dừng âm nền.
  late final AudioPlayer _player = AudioPlayer(
    handleInterruptions: false,
    androidApplyAudioAttributes: false,
  );

  @override
  Future<void> start(String source, double volume) async {
    if (inCall) {
      await _player.setAndroidAudioAttributes(androidCallAudioAttributes);
    }
    final asset = AssetPaths.backgrounds[source];
    if (asset != null) {
      await _player.setAsset(asset);
    } else if (source.startsWith('media:')) {
      await _player.setUrl(await files.audioUri(source));
    } else {
      await _player.setAsset(
        source.startsWith('assets/') ? source : 'assets/$source',
      );
    }
    await _player.setVolume(volume);
    await _player.setLoopMode(LoopMode.one);
    // play() chỉ xong khi dừng phát, nên không chờ.
    _player.play().catchError((Object _) {});
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() => _player.dispose();
}

/// Các âm nền của một combo: khoá âm nền có sẵn rồi tới file riêng.
List<String> backgroundSources(
  Iterable<String> keys,
  String? customBackgroundPath,
) => [...keys, ?customBackgroundPath];
