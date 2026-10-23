import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../shared/widgets/screen_shell.dart';

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

  @override
  Widget build(BuildContext context) => ScreenShell(
    title: 'Quét QR combo',
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Text('Đưa QR chia sẻ TRỐN vào khung hình.'),
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
                      .map((barcode) => barcode.rawValue)
                      .whereType<String>()
                      .where((value) => value.startsWith('TRON1.'))
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
