import 'package:flutter/material.dart';

import '../../../core/widgets/app_button.dart';

/// Giải thích trước khi hỏi quyền thông báo, để người dùng hiểu vì sao cần.
/// Trả về true nếu người dùng đồng ý cho hỏi quyền hệ thống.
class NotificationPermissionSheet extends StatelessWidget {
  const NotificationPermissionSheet({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cho phép thông báo để đổ chuông đúng giờ',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          const Text(
            'TRỐN dùng thông báo để cuộc gọi đổ đúng giờ kể cả khi máy đang khóa. '
            'Nếu không cho phép, cuộc gọi chỉ đổ khi app đang mở.',
          ),
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
