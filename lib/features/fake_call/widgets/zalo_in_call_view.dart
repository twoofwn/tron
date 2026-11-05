import 'package:flutter/material.dart';

import '../../../shared/widgets/avatar_photo.dart';
import 'call_action_button.dart';

/// Màn đang gọi của Zalo, dựng theo ảnh chụp app thật: nền xanh, nút quay lại,
/// "Zalo" + nhãn HD, avatar viền xanh, tên, đồng hồ xanh lá và ba nút
/// Loa / Kết thúc / Mic. Vị trí tính từ mép trên / dưới vùng an toàn.
class ZaloInCallView extends StatelessWidget {
  const ZaloInCallView({
    super.key,
    required this.caller,
    required this.elapsed,
    required this.isMuted,
    required this.isSpeaker,
    required this.onToggleMute,
    required this.onToggleSpeaker,
    required this.onHangUp,
    this.onSos,
    this.statusHint,
    this.avatarPath,
    this.endedLabel,
  });
  final String caller;
  final Duration elapsed;
  final bool isMuted;
  final bool isSpeaker;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onHangUp;

  /// Giữ nút Kết thúc 2 giây: gửi SOS (không có chữ nào gợi ý).
  final VoidCallback? onSos;
  final Widget? statusHint;

  /// Ảnh đại diện người gọi (`media:...`); không có thì hiện chữ cái đầu.
  final String? avatarPath;

  /// Khác `null` khi cuộc gọi vừa kết thúc: dòng này thay đồng hồ, các nút mờ
  /// đi trong giây lát trước khi màn gọi đóng, như máy thật.
  final String? endedLabel;

  static const background = Color(0xFF1068FE);
  static const _button = Color(0xFF0353CC);
  static const _end = Color(0xFFF2655E);
  static const _timer = Color(0xFF48D59B);

  String get _time =>
      '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth;
      Widget control(double fraction, Widget child) => Positioned(
        left: width * fraction - 50,
        width: 100,
        bottom: 60,
        child: CallEndFade(ended: endedLabel != null, child: child),
      );
      return Stack(
        children: [
          Positioned.fill(
            child: ZaloCallHeader(
              caller: caller,
              avatarPath: avatarPath,
              status: Column(
                children: [
                  Text(
                    endedLabel ?? _time,
                    style: TextStyle(
                      color: endedLabel == null ? _timer : Colors.white,
                      fontSize: 14,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (statusHint != null && endedLabel == null) ...[
                    const SizedBox(height: 8),
                    statusHint!,
                  ],
                ],
              ),
            ),
          ),
          control(
            0.23,
            CallButton(
              label: 'Loa',
              icon: Icons.volume_up_rounded,
              color: isSpeaker ? Colors.white : _button,
              iconColor: isSpeaker ? background : Colors.white,
              size: 65,
              iconSize: 30,
              labelSize: 14,
              toggled: isSpeaker,
              onTap: onToggleSpeaker,
            ),
          ),
          control(
            0.5,
            CallButton(
              label: 'Kết thúc',
              icon: Icons.call_end_rounded,
              color: _end,
              size: 65,
              iconSize: 30,
              labelSize: 14,
              onTap: onHangUp,
              onHold: onSos,
            ),
          ),
          control(
            0.77,
            CallButton(
              label: 'Mic',
              icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: isMuted ? Colors.white : _button,
              iconColor: isMuted ? background : Colors.white,
              size: 65,
              iconSize: 30,
              labelSize: 14,
              toggled: isMuted,
              onTap: onToggleMute,
            ),
          ),
        ],
      );
    },
  );
}

/// Phần trên chung của màn gọi Zalo (gọi đến và đang gọi): nút quay lại,
/// "Zalo" + HD, nút video, avatar viền xanh, tên và một dòng trạng thái.
class ZaloCallHeader extends StatelessWidget {
  const ZaloCallHeader({
    super.key,
    required this.caller,
    required this.status,
    this.avatarPath,
  });
  final String caller;

  /// Ảnh đại diện người gọi (`media:...`); không có thì hiện chữ cái đầu.
  final String? avatarPath;

  /// Dưới tên: đồng hồ khi đang gọi, "Cuộc gọi thoại đến" khi gọi đến.
  final Widget status;

  static const _ring = Color(0xFF107AFE);

  /// Avatar mặc định của Zalo khi chưa có ảnh: hai chữ cái đầu trên nền chuyển màu.
  String get _initials {
    final words = caller
        .split(RegExp(r'\s+'))
        .where(
          (w) => w.isNotEmpty && RegExp(r'\p{L}', unicode: true).hasMatch(w),
        )
        .toList();
    if (words.isEmpty) {
      return '?';
    }
    final first = words.first.characters.first;
    final last = words.length > 1 ? words.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned(
        left: 17,
        right: 17,
        top: 0,
        height: 36,
        child: Row(
          children: [
            _RoundIcon(icon: Icons.arrow_back_ios_new_rounded, size: 17),
            Expanded(
              child: Text(
                'Zalo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            _RoundIcon(icon: Icons.videocam_rounded, size: 24),
          ],
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 39,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF00347E),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'HD',
              style: TextStyle(
                color: Color(0xFF7C9BC8),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 107,
        child: Center(
          child: Container(
            width: 158,
            height: 158,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: _ring,
              shape: BoxShape.circle,
            ),
            child: AvatarPhoto(
              path: avatarPath,
              size: 150,
              fallback: Container(
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF8CC2FF), Color(0xFF3D86FF)],
                  ),
                ),
                child: Text(
                  _initials,
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: 24,
        right: 24,
        top: 280,
        child: Column(
          children: [
            Text(
              caller,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 7),
            status,
          ],
        ),
      ),
    ],
  );
}

/// Nút tròn nhỏ ở thanh trên (quay lại, gọi video). Chỉ để giống app thật.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.size});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Color(0xFF0353CC),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: size, color: Colors.white),
  );
}
