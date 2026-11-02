import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../shared/widgets/screen_shell.dart';
import '../models/sos_settings.dart';
import '../providers/sos_providers.dart';

/// Danh sách người nhận SOS: thêm từ danh bạ / nhập tay, sửa, xóa, kéo để đổi thứ tự.
class SosContactsSection extends ConsumerWidget {
  const SosContactsSection({super.key, required this.settings});

  final SosSettings settings;

  Future<void> _report(BuildContext context, Future<String?> action) async {
    String? error;
    try {
      error = await action;
    } catch (_) {
      error = 'Chưa thể lưu. Vui lòng thử lại.';
    }
    if (error != null && context.mounted) {
      showMessage(context, error);
    }
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final picked = await ref.read(sosPlatformProvider).pickContact();
    if (picked == null || !context.mounted) {
      return;
    }
    await _report(
      context,
      ref
          .read(sosSettingsProvider.notifier)
          .addContact(name: picked.name, phone: picked.phone),
    );
  }

  Future<void> _enter(BuildContext context, WidgetRef ref) async {
    final entered = await showDialog<SosContact>(
      context: context,
      builder: (_) => const _ContactDialog(),
    );
    if (entered == null || !context.mounted) {
      return;
    }
    await _report(
      context,
      ref
          .read(sosSettingsProvider.notifier)
          .addContact(name: entered.name, phone: entered.phone),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    SosContact contact,
  ) async {
    final edited = await showDialog<SosContact>(
      context: context,
      builder: (_) => _ContactDialog(initial: contact),
    );
    if (edited == null || !context.mounted) {
      return;
    }
    await _report(
      context,
      ref.read(sosSettingsProvider.notifier).updateContact(edited),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = settings.contacts;
    final isFull = contacts.length >= SosSettings.maxContacts;
    final canPick = ref.watch(sosPlatformProvider).isSupported;
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Text(
                'Chưa có ai. Thêm ít nhất một người để dùng SOS.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: contacts.length,
              onReorderItem: (oldIndex, newIndex) => ref
                  .read(sosSettingsProvider.notifier)
                  .reorder(oldIndex, newIndex),
              itemBuilder: (context, index) {
                final contact = contacts[index];
                return ListTile(
                  key: ValueKey(contact.id),
                  contentPadding: const EdgeInsets.only(left: 8, right: 4),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_indicator_rounded),
                    ),
                  ),
                  title: Text(
                    contact.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    index == 0 && settings.autoCall
                        ? '${contact.phone} · gọi trước'
                        : contact.phone,
                  ),
                  onTap: () => _edit(context, ref, contact),
                  trailing: IconButton(
                    tooltip: 'Xóa ${contact.label}',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => ref
                        .read(sosSettingsProvider.notifier)
                        .removeContact(contact.id),
                  ),
                );
              },
            ),
          const Divider(height: 1),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              if (canPick)
                TextButton.icon(
                  onPressed: isFull ? null : () => _pick(context, ref),
                  icon: const Icon(Icons.contacts_outlined),
                  label: const Text('Chọn từ danh bạ'),
                ),
              TextButton.icon(
                onPressed: isFull ? null : () => _enter(context, ref),
                icon: const Icon(Icons.dialpad_rounded),
                label: const Text('Nhập số'),
              ),
            ],
          ),
          if (isFull)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Tối đa ${SosSettings.maxContacts} người.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({this.initial});
  final SosContact? initial;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _submit() {
    if (SosContact.normalizePhone(_phone.text) == null) {
      setState(() => _error = 'Nhập số điện thoại hợp lệ.');
      return;
    }
    final initial = widget.initial;
    Navigator.pop(
      context,
      initial == null
          ? SosContact(id: '', name: _name.text, phone: _phone.text)
          : initial.copyWith(name: _name.text, phone: _phone.text),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null ? 'Thêm người liên hệ' : 'Sửa người liên hệ',
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Tên (không bắt buộc)',
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          maxLength: 20,
          autofocus: widget.initial == null,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Số điện thoại',
            counterText: '',
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Lưu')),
    ],
  );
}
