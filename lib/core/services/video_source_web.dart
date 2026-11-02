import 'package:video_player/video_player.dart';

/// Trên web, video được lưu dạng data URI nên phát như một địa chỉ mạng.
VideoPlayerController videoControllerFor(String location) =>
    VideoPlayerController.networkUrl(
      Uri.parse(location),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
