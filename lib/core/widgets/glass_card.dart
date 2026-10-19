import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.tint,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? tint;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (tint ?? scheme.surface).withValues(alpha: 0.95),
                  (tint ?? scheme.surface).withValues(alpha: 0.78),
                ],
              ),
              border: Border.all(
                color: isSelected ? AppColors.accent : scheme.outlineVariant,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(22),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
