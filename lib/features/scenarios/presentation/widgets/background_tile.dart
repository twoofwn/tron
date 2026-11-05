import 'package:flutter/material.dart';

import '../../models/scenario.dart';
import '../scenario_palette.dart';

IconData backgroundIcon(String name) => switch (name) {
  'car' => Icons.directions_car_outlined,
  'tv' => Icons.tv_outlined,
  'office' => Icons.apartment_outlined,
  'rain' => Icons.water_drop_outlined,
  'dog' => Icons.pets_outlined,
  'cafe' => Icons.local_cafe_outlined,
  'none' => Icons.volume_off_outlined,
  _ => Icons.music_note_outlined,
};

/// Ô "Thêm" cuối lưới âm nền: icon trên, chữ dưới như các ô khác, nên không
/// bị xuống dòng trên màn hình hẹp.
class AddBackgroundTile extends StatelessWidget {
  const AddBackgroundTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ScenarioPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.outline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 23, color: palette.muted),
                const SizedBox(height: 5),
                Text(
                  'Thêm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BackgroundTile extends StatelessWidget {
  const BackgroundTile({
    super.key,
    required this.sound,
    required this.selected,
    required this.onTap,
  });

  final AmbientSound? sound;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ScenarioPalette.of(context);
    final color = selected ? palette.yellowText : palette.text;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: palette.cardDecoration(selected: selected),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  backgroundIcon(sound?.iconName ?? 'none'),
                  size: 23,
                  color: color,
                ),
                const SizedBox(height: 5),
                Flexible(
                  child: Text(
                    sound?.title ?? 'Không có',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
