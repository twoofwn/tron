import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../models/sos_settings.dart';
import '../providers/sos_providers.dart';
import '../services/sos_message.dart';

/// Soạn mẫu tin nhắn SOS: chèn chỗ trống tự điền, xem trước và đếm số tin.
class SosMessageSection extends ConsumerStatefulWidget {
  const SosMessageSection({super.key, required this.settings});

  final SosSettings settings;

  @override
  ConsumerState<SosMessageSection> createState() => _SosMessageSectionState();
}

class _SosMessageSectionState extends ConsumerState<SosMessageSection> {
  late final _controller = TextEditingController(
    text: widget.settings.template,
  );
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant SosMessageSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mẫu đổi từ nơi khác (khôi phục mặc định) mà người dùng chưa sửa gì.
    if (oldWidget.settings.template != widget.settings.template &&
        _controller.text == oldWidget.settings.template) {
      _controller.text = widget.settings.template;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _changed => _controller.text.trim() != widget.settings.template;

  void _insert(SosPlaceholder placeholder) {
    final value = _controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final text = value.text.replaceRange(
      selection.start,
      selection.end,
      placeholder.token,
    );
    if (text.length > SosSettings.maxTemplateLength) {
      return;
    }
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: selection.start + placeholder.token.length,
      ),
    );
  }

  Future<void> _save(String template) async {
    if (template.trim().isEmpty) {
      showMessage(context, 'Nội dung không được để trống.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(sosSettingsProvider.notifier)
          .modify((value) => value.copyWith(template: template.trim()));
      if (mounted) {
        FocusScope.of(context).unfocus();
        showMessage(context, 'Đã lưu nội dung tin nhắn.');
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Chưa thể lưu. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _setPlain(bool on) async {
    try {
      await ref
          .read(sosSettingsProvider.notifier)
          .modify((value) => value.copyWith(plainText: on));
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Chưa thể lưu. Vui lòng thử lại.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plain = widget.settings.plainText;
    final preview = SosMessage.preview(_controller.text, plain: plain);
    final size = SosMessage.size(preview);
    final contacts = widget.settings.contacts.length;
    final isDefault = _controller.text.trim() == SosSettings.defaultTemplate;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('sos-template'),
            controller: _controller,
            minLines: 3,
            maxLines: 6,
            maxLength: SosSettings.maxTemplateLength,
            decoration: const InputDecoration(
              hintText: 'Nội dung tin nhắn SOS',
            ),
          ),
          const SizedBox(height: 4),
          const Text('Chèn tự điền:', style: AppTextStyles.caption),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final placeholder in SosPlaceholder.values)
                ActionChip(
                  label: Text(placeholder.label),
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  onPressed: () => _insert(placeholder),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Xem trước', style: AppTextStyles.cardTitle),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(preview, key: const ValueKey('sos-preview')),
          ),
          const SizedBox(height: 6),
          Text(
            '${size.parts} tin / người nhận'
            '${contacts > 1 ? ' · ${size.parts * contacts} tin cho $contacts người' : ''}'
            '${size.unicode ? ' · có dấu nên mỗi tin chỉ ~70 ký tự' : ''}',
            key: const ValueKey('sos-size'),
            style: TextStyle(
              fontSize: 12,
              color: size.parts > 2 ? AppColors.accent : AppColors.muted,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Gửi không dấu'),
            subtitle: const Text('Mỗi tin chứa ~160 ký tự, ít tin hơn'),
            value: plain,
            onChanged: _setPlain,
          ),
          // Màn hẹp hoặc chữ to: hai nút tự xuống dòng thay vì tràn.
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            overflowSpacing: 6,
            children: [
              TextButton(
                onPressed: isDefault || _saving
                    ? null
                    : () {
                        _controller.text = SosSettings.defaultTemplate;
                        _save(SosSettings.defaultTemplate);
                      },
                child: const Text('Khôi phục mặc định'),
              ),
              FilledButton(
                onPressed: _changed && !_saving
                    ? () => _save(_controller.text)
                    : null,
                child: const Text('Lưu nội dung'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
