import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/file_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../../backup/services/backup_service.dart';
import '../../combo/models/combo_model.dart';
import '../models/combo_package.dart';
import '../repositories/sharing_repository.dart';
import 'combo_checklist.dart';
import 'share_package_card.dart';

class ExportPanel extends ConsumerStatefulWidget {
  const ExportPanel({super.key, required this.combos, required this.onImport});
  final List<ComboModel> combos;
  final VoidCallback onImport;
  @override
  ConsumerState<ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends ConsumerState<ExportPanel> {
  final _selectedIds = <String>{};
  bool _includeAudio = false;
  bool _isBusy = false;
  ComboPackage? _package;
  String? _onlineCode;

  /// Dung lượng ước tính của gói theo lựa chọn hiện tại; `null` khi đang tính.
  int? _estimate;
  int _estimateRun = 0;

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.combos.take(2).map((combo) => combo.id));
    _refreshEstimate();
  }

  void _invalidate(VoidCallback change) {
    setState(() {
      change();
      _package = null;
      _onlineCode = null;
    });
    _refreshEstimate();
  }

  List<ComboModel> get _selectedCombos =>
      widget.combos.where((combo) => _selectedIds.contains(combo.id)).toList();

  /// Tính lại dung lượng gói để báo trước khi người dùng bấm tạo mã.
  Future<void> _refreshEstimate() async {
    final run = ++_estimateRun;
    final estimate = await ref
        .read(sharingRepositoryProvider)
        .estimateSize(_selectedCombos, includeAudio: _includeAudio);
    if (mounted && run == _estimateRun) {
      setState(() => _estimate = estimate);
    }
  }

  bool get _isTooLarge => (_estimate ?? 0) > AppConstants.maxPackageBytes;
  Future<void> _generate() async {
    setState(() => _isBusy = true);
    try {
      final selectedCombos = _selectedCombos;
      final package = await ref
          .read(sharingRepositoryProvider)
          .create(selectedCombos, includeAudio: _includeAudio);
      String? onlineCode;
      try {
        final api = ref.read(apiClientProvider);
        if (await api.hasToken()) {
          onlineCode = await ref
              .read(backupServiceProvider)
              .createOnlineShare(selectedCombos, includeAudio: _includeAudio);
        }
      } catch (_) {
        // Fallback to local offline share code if server is unreachable
      }
      if (mounted) {
        setState(() {
          _package = onlineCode == null
              ? package
              : ComboPackage(
                  id: onlineCode.replaceFirst('EH-', ''),
                  combos: package.combos,
                  audio: package.audio,
                );
          _onlineCode = onlineCode;
        });
      }
    } catch (error) {
      if (mounted) {
        showMessage(
          context,
          error is FormatException
              ? error.message
              : 'Không đọc được file âm thanh đã lưu.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _deliver({required bool share}) async {
    final package = _package;
    if (package == null || _isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      final bytes = ref.read(sharingRepositoryProvider).encode(package);
      if (share) {
        final box = context.findRenderObject() as RenderBox;
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                bytes,
                mimeType: 'application/octet-stream',
                name: 'tron_combos.ehc',
              ),
            ],
            fileNameOverrides: ['tron_combos.ehc'],
            subject: 'Combo TRỐN dành cho bạn',
            sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      } else {
        final saved = await ref.read(fileServiceProvider).savePackage(bytes);
        if (mounted && saved) {
          showMessage(context, 'Đã xuất file tron_combos.ehc');
        }
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          share
              ? 'Thiết bị chưa hỗ trợ chia sẻ file. Hãy dùng Lưu file .ehc.'
              : 'Không lưu được file. Vui lòng thử lại.',
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
    final validIds = widget.combos.map((combo) => combo.id).toSet();
    final selectedCount = _selectedIds.intersection(validIds).length;
    final package = _package;
    final code = package == null
        ? null
        : (_onlineCode ?? ref.read(sharingRepositoryProvider).code(package));
    final hasQr = code != null && code.length <= 2300;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Chọn combo để xuất',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            TextButton(
              onPressed: _isBusy || widget.combos.isEmpty
                  ? null
                  : () => _invalidate(() {
                      if (selectedCount == widget.combos.length) {
                        _selectedIds.clear();
                      } else {
                        _selectedIds.addAll(validIds);
                      }
                    }),
              child: Text(
                selectedCount == widget.combos.length &&
                        widget.combos.isNotEmpty
                    ? 'Bỏ chọn tất cả'
                    : 'Chọn tất cả',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        ComboChecklist(
          combos: widget.combos,
          selectedIds: _selectedIds,
          isEnabled: !_isBusy,
          onChanged: (id, selected) => _invalidate(() {
            if (selected) {
              _selectedIds.add(id);
            } else {
              _selectedIds.remove(id);
            }
          }),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: _includeAudio,
          onChanged: _isBusy
              ? null
              : (value) => _invalidate(() => _includeAudio = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text(
            'Kèm âm thanh và video cá nhân',
            style: TextStyle(fontSize: 12),
          ),
          subtitle: Text(
            _estimate == null
                ? 'Tối đa ${sizeLabel(AppConstants.maxPackageBytes)} mỗi gói'
                : _isTooLarge
                ? 'Gói khoảng ${sizeLabel(_estimate!)}, vượt giới hạn '
                      '${sizeLabel(AppConstants.maxPackageBytes)}. Bỏ bớt combo '
                      'hoặc bỏ kèm âm thanh và video.'
                : 'Gói khoảng ${sizeLabel(_estimate!)} · tối đa '
                      '${sizeLabel(AppConstants.maxPackageBytes)}',
            style: TextStyle(
              fontSize: 10,
              color: _isTooLarge ? AppColors.red : AppColors.muted,
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (package == null)
          AppButton(
            label: 'Tạo mã chia sẻ · $selectedCount combo',
            icon: Icons.qr_code_rounded,
            isLoading: _isBusy,
            // Gói vượt giới hạn: khoá nút, lý do hiện ngay ở dòng phía trên.
            onPressed: selectedCount == 0 || _isTooLarge ? null : _generate,
          )
        else ...[
          SharePackageCard(package: package, code: code!),
          if (hasQr)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    showMessage(context, 'Đã sao chép mã đầy đủ.');
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text(
                  'Sao chép mã đầy đủ',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Lưu file .ehc',
                  icon: Icons.file_download_outlined,
                  isSecondary: true,
                  onPressed: _isBusy ? null : () => _deliver(share: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Gửi cho bạn',
                  icon: Icons.share_outlined,
                  isLoading: _isBusy,
                  onPressed: () => _deliver(share: true),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 42),
        GlassCard(
          onTap: widget.onImport,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.move_to_inbox_outlined,
                    size: 17,
                    color: AppColors.accent,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nhận combo từ người khác?',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
              SizedBox(height: 9),
              Text(
                'Chuyển sang tab Nhập để quét QR, dán mã đầy đủ hoặc mở file .ehc. Combo sẽ được lưu trên thiết bị của bạn.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
