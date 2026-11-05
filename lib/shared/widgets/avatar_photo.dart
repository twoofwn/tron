import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/file_service.dart';

/// Nội dung ảnh đại diện (`media:UUID.jpg`) đọc từ file của app; lỗi thì `null`.
final avatarBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, path) async {
      try {
        return await ref.read(fileServiceProvider).readMedia(path);
      } catch (_) {
        return null;
      }
    });

/// Ảnh đại diện người gọi, cắt tròn. Chưa có ảnh, đang đọc hoặc ảnh lỗi thì
/// hiện [fallback] (thường là vòng tròn chữ cái đầu).
class AvatarPhoto extends ConsumerWidget {
  const AvatarPhoto({
    super.key,
    required this.path,
    required this.size,
    required this.fallback,
  });

  final String? path;
  final double size;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = this.path;
    if (path == null) {
      return fallback;
    }
    final bytes = ref.watch(avatarBytesProvider(path)).value;
    if (bytes == null) {
      return fallback;
    }
    return ClipOval(
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
