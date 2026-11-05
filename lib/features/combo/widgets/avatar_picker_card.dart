import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/avatar_photo.dart';

/// Cách lấy ảnh đại diện người dùng chọn trong bảng chọn.
enum AvatarSource { gallery, camera, remove }

/// Ảnh đại diện người gọi trong form combo: chạm để chọn ảnh từ thư viện, chụp
/// ảnh mới hoặc xoá ảnh. Chưa có ảnh thì hiện chữ cái đầu như ở màn Home.
class AvatarPickerCard extends StatelessWidget {
  const AvatarPickerCard({
    super.key,
    required this.avatarPath,
    required this.initial,
    required this.onSelected,
    this.enabled = true,
  });

  final String? avatarPath;

  /// Chữ cái đầu hiện khi chưa có ảnh.
  final String initial;
  final ValueChanged<AvatarSource> onSelected;
  final bool enabled;

  Future<void> _openSheet(BuildContext context) async {
    final source = await showModalBottomSheet<AvatarSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện ảnh'),
              onTap: () => Navigator.pop(context, AvatarSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh mới'),
              onTap: () => Navigator.pop(context, AvatarSource.camera),
            ),
            if (avatarPath != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.red,
                ),
                title: const Text(
                  'Xoá ảnh, dùng chữ cái đầu',
                  style: TextStyle(color: AppColors.red),
                ),
                onTap: () => Navigator.pop(context, AvatarSource.remove),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (source != null) {
      onSelected(source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = avatarPath != null;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      onTap: enabled ? () => _openSheet(context) : null,
      child: Row(
        children: [
          Semantics(
            image: true,
            label: hasPhoto ? 'Ảnh đại diện người gọi' : 'Chưa có ảnh đại diện',
            child: AvatarPhoto(
              path: avatarPath,
              size: 48,
              fallback: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPhoto ? 'Ảnh đại diện người gọi' : 'Thêm ảnh đại diện',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Hiện ở danh sách combo và trên màn cuộc gọi.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: enabled ? () => _openSheet(context) : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent.withValues(alpha: 0.7)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(hasPhoto ? 'Đổi ảnh' : 'Chọn ảnh'),
          ),
        ],
      ),
    );
  }
}
