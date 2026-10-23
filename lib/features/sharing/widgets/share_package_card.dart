import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../models/combo_package.dart';

class SharePackageCard extends StatelessWidget {
  const SharePackageCard({
    super.key,
    required this.package,
    required this.code,
  });
  final ComboPackage package;
  final String code;
  @override
  Widget build(BuildContext context) {
    final hasQr = code.length <= 2300;
    return GlassCard(
      onTap: hasQr
          ? () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: 320,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Quét để nhận combo',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        AspectRatio(
                          aspectRatio: 1,
                          child: QrImageView(
                            data: code,
                            errorCorrectionLevel: QrErrorCorrectLevel.L,
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Mở TRỐN → Nhập → Quét QR',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Đóng',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (hasQr)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: code,
                size: 102,
                padding: EdgeInsets.zero,
                errorCorrectionLevel: QrErrorCorrectLevel.L,
              ),
            )
          else
            Container(
              width: 78,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.audio_file_outlined,
                size: 36,
                color: AppColors.accent,
              ),
            ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gói chia sẻ',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'EH-${package.id.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasQr
                      ? 'Chạm để phóng to QR hoặc sao chép mã đầy đủ. Không cần tài khoản.'
                      : 'Gói lớn: gửi file .ehc cho bạn bè để giữ đủ âm thanh.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    height: 1.5,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
