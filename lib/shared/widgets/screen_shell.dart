import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

class ScreenShell extends StatelessWidget {
  const ScreenShell({super.key, required this.child, this.title, this.bottom});
  final Widget child;
  final String? title;
  final Widget? bottom;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Positioned(
          top: -140,
          right: -170,
          child: IgnorePointer(
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.045),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 14, 22, 14),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 19,
                            ),
                            tooltip: 'Quay lại',
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              title!,
                              style: AppTextStyles.title.copyWith(fontSize: 23),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(child: child),
                  if (bottom != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                      child: bottom!,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
