import 'dart:io';

import 'package:video_player/video_player.dart';

/// Trình phát cho video lưu trong máy (`location` là đường dẫn file). Phát
/// chung với âm nền của cuộc gọi thay vì tắt các âm thanh khác.
VideoPlayerController videoControllerFor(String location) =>
    VideoPlayerController.file(
      File(location),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
