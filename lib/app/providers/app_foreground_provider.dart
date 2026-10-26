import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App đang hiện trên màn hình. Khi chuông đổ lúc app ở nền, thông báo báo thức
/// phải được giữ lại để người dùng thấy màn gọi.
final appForegroundProvider = NotifierProvider<AppForegroundNotifier, bool>(
  AppForegroundNotifier.new,
);

class AppForegroundNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setForeground(bool foreground) => state = foreground;
}
