import 'package:flutter/material.dart';

import '../../../core/widgets/app_button.dart';

/// Giải thích trước khi hỏi quyền hệ thống, để người dùng hiểu vì sao cần.
/// Trả về true nếu người dùng đồng ý để app hỏi quyền.
class PermissionRequestSheet extends StatelessWidget {
  const PermissionRequestSheet({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(message),
          const SizedBox(height: 18),
          AppButton(
            label: 'Cho phép',
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Để sau',
            isSecondary: true,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    ),
  );
}
