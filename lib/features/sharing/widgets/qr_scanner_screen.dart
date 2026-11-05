import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../shared/widgets/screen_shell.dart';
import '../../backup/services/backup_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _hasScanned = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static bool _isSupportedShareValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return false;
    final upper = trimmed.toUpperCase();
    if (upper.startsWith('TRON1.') ||
        upper.contains('TRON1.') ||
        upper.startsWith('EH-') ||
        upper.startsWith('MKT-')) {
      return true;
    }
    return BackupService.normalizeOnlineCode(trimmed) != null;
  }

  @override
  Widget build(BuildContext context) => ScreenShell(
    title: 'Quét QR chia sẻ',
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Text('Đưa QR chia sẻ kịch bản / combo TRỐN vào khung hình.'),
          const SizedBox(height: 24),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: MobileScanner(
                controller: _controller,
                errorBuilder: (context, error) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Không mở được camera. Hãy cấp quyền camera trong cài đặt hoặc nhập bằng mã / file.',
                    ),
                  ),
                ),
                onDetect: (capture) {
                  if (_hasScanned) {
                    return;
                  }
                  final value = capture.barcodes
                      .map((barcode) => barcode.rawValue?.trim())
                      .whereType<String>()
                      .where(_isSupportedShareValue)
                      .firstOrNull;
                  if (value == null) {
                    return;
                  }
                  _hasScanned = true;
                  Navigator.pop(context, value);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'QR được xử lý trực tiếp trên thiết bị.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
