import 'package:flutter/material.dart';

/// Nút tròn của màn cuộc gọi, có nhãn bên dưới (có thể ẩn nhãn).
class CallButton extends StatelessWidget {
  const CallButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 76,
    this.iconSize,
    this.iconColor = Colors.white,
    this.labelColor = Colors.white,
    this.labelSize = 14,
    this.showLabel = true,
    this.toggled,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final double size;
  final double? iconSize;
  final Color iconColor;
  final Color labelColor;
  final double labelSize;
  final bool showLabel;

  /// Trạng thái bật / tắt cho trình đọc màn hình; `null` nếu không phải nút bật tắt.
  final bool? toggled;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    toggled: toggled,
    excludeSemantics: true,
    // Chạm vào nhãn cũng tính là bấm nút.
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap ?? () {},
              child: SizedBox.square(
                dimension: size,
                child: Icon(
                  icon,
                  size: iconSize ?? size * 0.42,
                  color: iconColor,
                ),
              ),
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 10),
            // Giới hạn bề rộng để hàng nút không tràn khi màn hẹp hoặc chữ to.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: size + 24),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(color: labelColor, fontSize: labelSize),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Avatar chữ cái đầu dùng chung cho các màn cuộc gọi.
class CallAvatar extends StatelessWidget {
  const CallAvatar({
    super.key,
    required this.initial,
    required this.color,
    required this.textColor,
    required this.size,
    required this.fontSize,
    this.fontWeight = FontWeight.w400,
  });
  final String initial;
  final Color color;
  final Color textColor;
  final double size;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Text(
      initial,
      style: TextStyle(
        color: textColor,
        fontSize: fontSize,
        fontWeight: fontWeight,
      ),
    ),
  );
}
