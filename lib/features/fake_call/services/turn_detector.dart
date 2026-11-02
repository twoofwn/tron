import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

/// Các ngưỡng để biết người dùng đã nói xong.
class TurnRules {
  const TurnRules({
    this.minSpeech = const Duration(milliseconds: 200),
    this.endSilence = const Duration(milliseconds: 900),
    this.noReply = const Duration(seconds: 5),
    this.maxReply = const Duration(seconds: 20),
    this.settle = const Duration(milliseconds: 250),
    this.startMargin = 12,
    this.keepMargin = 7,
    this.minSpeechLevel = -50,
    this.floorWindow = const Duration(milliseconds: 1500),
  });

  /// Ồn nền là mức thấp nhất trong khoảng thời gian gần đây này.
  final Duration floorWindow;

  /// Tiếng to liên tục ít nhất chừng này mới tính là nói (bỏ qua tiếng ho, cạch).
  final Duration minSpeech;

  /// Im liên tục chừng này thì coi là đã nói xong.
  final Duration endSilence;

  /// Không nói gì trong khoảng này thì người gọi nói tiếp.
  final Duration noReply;

  /// Nói (hoặc ồn) liên tục quá khoảng này thì người gọi cũng nói tiếp.
  final Duration maxReply;

  /// Bỏ qua phần đầu lượt chờ: đuôi câu người gọi vừa nói còn vọng vào micro.
  final Duration settle;

  /// Cao hơn tiếng ồn nền bao nhiêu dB thì bắt đầu tính là đang nói.
  final double startMargin;

  /// Đang nói mà còn cao hơn tiếng ồn nền bao nhiêu dB thì vẫn tính là nói.
  final double keepMargin;

  /// Dưới mức này (dBFS) không bao giờ tính là giọng nói, kể cả phòng rất yên.
  final double minSpeechLevel;
}

enum ReplyOutcome {
  /// Người dùng nói rồi im đủ lâu.
  finished,

  /// Người dùng không nói gì.
  noReply,

  /// Nói hoặc ồn quá lâu.
  tooLong,

  /// Cuộc gọi kết thúc giữa chừng.
  cancelled,
}

/// Theo dõi độ lớn âm thanh từ micro (dBFS, từng khung ngắn) và báo khi tới
/// lượt người gọi nói. Không phụ thuộc micro thật nên kiểm thử được.
class TurnDetector {
  TurnDetector({this.rules = const TurnRules(), double noiseFloor = -60})
    : _floor = noiseFloor;

  final TurnRules rules;
  double _floor;
  final _recent = ListQueue<(double, Duration)>();
  Duration _recentSpan = Duration.zero;
  Duration _elapsed = Duration.zero;
  Duration _candidate = Duration.zero;
  Duration _silence = Duration.zero;
  Duration? _speechStart;

  /// Tiếng ồn nền ước tính, giữ qua các lượt chờ trong cùng cuộc gọi.
  double get noiseFloor => _floor;

  /// Lượt chờ này đã nghe thấy người dùng nói.
  bool get heardSpeech => _speechStart != null;

  /// Bắt đầu một lượt chờ mới.
  void reset() {
    _elapsed = Duration.zero;
    _candidate = Duration.zero;
    _silence = Duration.zero;
    _speechStart = null;
  }

  /// Thêm một khung âm thanh. Trả về kết quả khi lượt chờ kết thúc.
  ReplyOutcome? addLevel(double level, Duration frame) {
    _elapsed += frame;
    if (_elapsed <= rules.settle) {
      return null;
    }
    _trackFloor(level, frame);
    final speechStart = _speechStart;
    if (speechStart == null) {
      final startLevel = math.max(
        _floor + rules.startMargin,
        rules.minSpeechLevel,
      );
      if (level >= startLevel) {
        _candidate += frame;
        if (_candidate >= rules.minSpeech) {
          _speechStart = _elapsed - _candidate;
          _silence = Duration.zero;
        }
        return null;
      }
      _candidate = Duration.zero;
      return _elapsed >= rules.noReply ? ReplyOutcome.noReply : null;
    }
    final keepLevel = math.max(
      _floor + rules.keepMargin,
      rules.minSpeechLevel - 5,
    );
    _silence = level >= keepLevel ? Duration.zero : _silence + frame;
    if (_silence >= rules.endSilence) {
      return ReplyOutcome.finished;
    }
    if (_elapsed - speechStart >= rules.maxReply) {
      return ReplyOutcome.tooLong;
    }
    return null;
  }

  /// Ồn nền là mức thấp nhất trong khoảng gần đây: lời nói luôn có chỗ ngắt
  /// giữa các từ, còn tiếng ồn đều (quạt, quán đông) thì không, nên ồn đều
  /// được học thành nền và không bị tính là giọng nói.
  void _trackFloor(double level, Duration frame) {
    _recent.add((level, frame));
    _recentSpan += frame;
    while (_recentSpan > rules.floorWindow && _recent.length > 1) {
      _recentSpan -= _recent.removeFirst().$2;
    }
    var lowest = level;
    for (final (value, _) in _recent) {
      lowest = math.min(lowest, value);
    }
    _floor = lowest.clamp(-75.0, -35.0);
  }
}

/// Cắt luồng PCM 16 bit mono thành từng khung ngắn và đo độ lớn (dBFS).
class PcmLevelMeter {
  PcmLevelMeter({this.sampleRate = 16000, this.frameLength = defaultFrame})
    : _frameBytes = sampleRate * frameLength.inMicroseconds ~/ 1000000 * 2;

  static const defaultFrame = Duration(milliseconds: 30);

  final int sampleRate;
  final Duration frameLength;
  final int _frameBytes;
  final _pending = BytesBuilder(copy: true);

  /// Mức của khung im tuyệt đối.
  static const silence = -96.0;

  /// Nhận một đoạn dữ liệu bất kỳ, trả về mức của các khung đã đủ dữ liệu.
  List<double> add(Uint8List chunk) {
    _pending.add(chunk);
    if (_pending.length < _frameBytes) {
      return const [];
    }
    final bytes = _pending.takeBytes();
    final data = ByteData.sublistView(bytes);
    final levels = <double>[];
    var offset = 0;
    while (offset + _frameBytes <= bytes.length) {
      levels.add(_level(data, offset));
      offset += _frameBytes;
    }
    if (offset < bytes.length) {
      _pending.add(Uint8List.sublistView(bytes, offset));
    }
    return levels;
  }

  void reset() => _pending.clear();

  double _level(ByteData data, int offset) {
    var sum = 0.0;
    final samples = _frameBytes ~/ 2;
    for (var i = 0; i < samples; i++) {
      final sample = data.getInt16(offset + i * 2, Endian.little);
      sum += sample * sample;
    }
    final rms = math.sqrt(sum / samples);
    if (rms < 1) {
      return silence;
    }
    return math.max(silence, 20 * math.log(rms / 32768) / math.ln10);
  }
}
