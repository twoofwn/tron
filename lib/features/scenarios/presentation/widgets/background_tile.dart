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
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: ScenarioPalette.cardDecoration(selected: selected),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                backgroundIcon(sound?.iconName ?? 'none'),
                size: 23,
                color: selected ? ScenarioPalette.yellow : Colors.white,
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
                    color: selected ? ScenarioPalette.yellow : Colors.white,
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
