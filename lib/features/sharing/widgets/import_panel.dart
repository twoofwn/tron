import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/file_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../backup/services/backup_service.dart';
import '../../combo/models/combo_model.dart';
import '../models/combo_package.dart';
import '../providers/sharing_provider.dart';
import '../repositories/sharing_repository.dart';
import 'import_preview.dart';
import 'qr_scanner_screen.dart';

class ImportPanel extends ConsumerStatefulWidget {
  const ImportPanel({super.key, required this.existingCombos});
  final List<ComboModel> existingCombos;
  @override
  ConsumerState<ImportPanel> createState() => _ImportPanelState();
}

class _ImportPanelState extends ConsumerState<ImportPanel> {
  final _codeController = TextEditingController();
  final _selectedIds = <String>{};
  ComboPackage? _package;
  bool _copyDuplicates = false;
  bool _isBusy = false;
  String? _error;
  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _preview(ComboPackage package) => setState(() {
    _package = package;
    _error = null;
    _selectedIds.clear();
    _selectedIds.addAll(package.combos.map((combo) => combo.id));
  });
  Future<void> _readFile() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final bytes = await ref.read(fileServiceProvider).pickPackage();
      if (bytes != null && mounted) {
        _preview(ref.read(sharingRepositoryProvider).decode(bytes));
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Không thể mở file .ehc.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _readCode() async {
    final text = _codeController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mã chia sẻ để tiếp tục.');
      return;
    }

    if (text.toUpperCase().startsWith('EH-')) {
      setState(() {
        _isBusy = true;
        _error = null;
      });
      try {
        final pkg = await ref
            .read(backupServiceProvider)
            .fetchOnlineSharePackage(text);
        if (mounted) {
          _preview(pkg);
        }
      } catch (error) {
        if (mounted) {
          setState(
            () => _error = error is ApiException ? error.message : 'Không tải được mã chia sẻ trực tuyến. Vui lòng kiểm tra lại.',
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isBusy = false);
        }
      }
      return;
    }

    try {
      _preview(ref.read(sharingRepositoryProvider).decodeCode(text));
    } catch (error) {
      setState(
        () => _error = error is FormatException
            ? error.message
            : 'Mã chia sẻ không đúng định dạng. Hãy kiểm tra lại và nhập lại.',
      );
    }
  }

  Future<void> _scan() async {
    final result = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerScreen()));
    if (result != null && mounted) {
      _codeController.text = result;
      await _readCode();
    }
  }

  Future<void> _confirm() async {
    if (_package == null || _selectedIds.isEmpty || _isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      final count = await ref.read(sharingActionsProvider).importPackage(
        _package!,
        {..._selectedIds},
        copyDuplicates: _copyDuplicates,
      );
      if (mounted) {
        showMessage(
          context,
          count == 0
              ? 'Đã bỏ qua các combo trùng lặp.'
              : 'Đã nhập $count combo vào thiết bị.',
        );
        setState(() {
          _package = null;
          _selectedIds.clear();
          _codeController.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể lưu combo hoặc âm thanh. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final package = _package;
    final existingIds = widget.existingCombos.map((combo) => combo.id).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mang một lối thoát mới về máy',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nhận combo từ bạn bè. Không tài khoản, không cần server.',
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.6),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Mở file .ehc',
                icon: Icons.folder_open_outlined,
                isSecondary: true,
                onPressed: _isBusy ? null : _readFile,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Quét QR',
                icon: Icons.qr_code_scanner_rounded,
                onPressed: _isBusy ? null : _scan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Hoặc nhập bằng mã chia sẻ',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        AppTextField(
          controller: _codeController,
          hint: 'Nhập mã EH-XXXXXX trực tuyến hoặc dán mã TRON1.…',
          maxLines: 3,
          maxLength: 40000,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Xem trước combo',
                icon: Icons.preview_outlined,
                isSecondary: true,
                onPressed: _isBusy ? null : _readCode,
              ),
            ),
            if (_codeController.text.isNotEmpty || _error != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Xóa mã để nhập lại',
                icon: const Icon(Icons.clear_rounded, size: 20),
                onPressed: () {
                  setState(() {
                    _codeController.clear();
                    _error = null;
                  });
                },
              ),
            ],
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppColors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_isBusy)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: LinearProgressIndicator(),
          ),
        if (package != null)
          ImportPreview(
            package: package,
            selectedIds: _selectedIds,
            existingIds: existingIds,
            copyDuplicates: _copyDuplicates,
            isBusy: _isBusy,
            onSelectionChanged: (id, selected) => setState(() {
              if (selected) {
                _selectedIds.add(id);
              } else {
                _selectedIds.remove(id);
              }
            }),
            onCopyDuplicatesChanged: (value) =>
                setState(() => _copyDuplicates = value),
            onConfirm: _confirm,
          ),
        const SizedBox(height: 28),
        const Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.muted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bạn được xem và chọn combo trước khi lưu.',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
