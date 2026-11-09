import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers/app_foreground_provider.dart';
import '../../../core/services/storage_service.dart';
import '../data/sos_repository.dart';
import '../models/sos_settings.dart';
import '../services/sos_platform.dart';

final sosPlatformProvider = Provider<SosPlatform>((ref) => SosPlatform());

final sosPermissionServiceProvider = Provider<SosPermissionService>(
  (ref) => const SosPermissionService(),
);

final sosRepositoryProvider = Provider<SosRepository>(
  (ref) => SosRepository(ref.watch(storageServiceProvider)),
);

final sosPermissionsProvider =
    FutureProvider.autoDispose<Map<SosPermission, bool>>(
      (ref) => ref.watch(sosPermissionServiceProvider).statuses(),
    );

final sosSettingsProvider =
    AsyncNotifierProvider<SosSettingsNotifier, SosSettings>(
      SosSettingsNotifier.new,
    );

class SosSettingsNotifier extends AsyncNotifier<SosSettings> {
  @override
  Future<SosSettings> build() => ref.watch(sosRepositoryProvider).load();

  Future<void> modify(SosSettings Function(SosSettings current) change) async {
    final next = change(await future);
    await ref.read(sosRepositoryProvider).save(next);
    state = AsyncData(next);
    // Đang hẹn giờ thì cập nhật luôn danh sách / nội dung sẽ tự gửi.
    await ref.read(checkInProvider.notifier).syncSettings(next);
  }

  /// Trả về câu báo lỗi, hoặc null nếu đã thêm.
  Future<String?> addContact({
    required String name,
    required String phone,
  }) async {
    final number = SosContact.normalizePhone(phone);
    if (number == null) {
      return 'Số điện thoại không hợp lệ.';
    }
    final current = await future;
    if (current.contacts.length >= SosSettings.maxContacts) {
      return 'Chỉ thêm được tối đa ${SosSettings.maxContacts} người.';
    }
    if (current.contacts.any((contact) => contact.phone == number)) {
      return 'Số này đã có trong danh sách.';
    }
    final contact = SosContact(
      id: const Uuid().v4(),
      name: name.trim(),
      phone: number,
    );
    await modify(
      (value) => value.copyWith(contacts: [...value.contacts, contact]),
    );
    return null;
  }

  Future<String?> updateContact(SosContact contact) async {
    final number = SosContact.normalizePhone(contact.phone);
    if (number == null) {
      return 'Số điện thoại không hợp lệ.';
    }
    final current = await future;
    if (current.contacts.any(
      (item) => item.id != contact.id && item.phone == number,
    )) {
      return 'Số này đã có trong danh sách.';
    }
    await modify(
      (value) => value.copyWith(
        contacts: [
          for (final item in value.contacts)
            item.id == contact.id
                ? contact.copyWith(name: contact.name.trim(), phone: number)
                : item,
        ],
      ),
    );
    return null;
  }

  Future<void> removeContact(String id) => modify(
    (value) => value.copyWith(
      contacts: value.contacts.where((item) => item.id != id).toList(),
    ),
  );

  /// [newIndex] là vị trí cuối cùng của người đó (đã tính việc bỏ khỏi chỗ cũ).
  Future<void> reorder(int oldIndex, int newIndex) => modify((value) {
    final contacts = [...value.contacts];
    contacts.insert(newIndex, contacts.removeAt(oldIndex));
    return value.copyWith(contacts: contacts);
  });
}

final checkInProvider = AsyncNotifierProvider<CheckInNotifier, CheckInStatus>(
  CheckInNotifier.new,
);

/// Hẹn giờ "Báo an toàn". Android giữ trạng thái thật; đây chỉ đọc lại và ra lệnh.
class CheckInNotifier extends AsyncNotifier<CheckInStatus> {
  /// Các nấc của thanh trượt hẹn giờ, từ 30 giây tới 3 giờ. Nấc dày ở đầu để
  /// chọn được mốc ngắn: dưới 5 phút cách 30 giây, tới 30 phút cách 1 phút,
  /// sau đó cách 5 phút.
  static final List<Duration> durations = [
    for (var s = 30; s <= 300; s += 30) Duration(seconds: s),
    for (var m = 6; m <= 30; m++) Duration(minutes: m),
    for (var m = 35; m <= 180; m += 5) Duration(minutes: m),
  ];
  static const defaultDuration = Duration(minutes: 30);
  static const extension = Duration(minutes: 15);

  /// Sau khi hết giờ, hỏi lại Android theo nhịp này tới khi gửi xong.
  static const pollInterval = Duration(seconds: 1);

  Timer? _expiry;

  SosPlatform get _platform => ref.read(sosPlatformProvider);

  @override
  Future<CheckInStatus> build() async {
    // Người dùng có thể đã bấm "Tôi an toàn" trên thông báo, hoặc app vừa tự gửi.
    ref.listen(appForegroundProvider, (previous, next) {
      if (next && previous == false) {
        refresh();
      }
    });
    ref.onDispose(() => _expiry?.cancel());
    final status = await ref.read(sosPlatformProvider).checkInStatus();
    _watchExpiry(status);
    return status;
  }

  /// App đang mở lúc hết giờ: đọc lại đúng lúc hết giờ để đổi sang "Đang gửi",
  /// rồi đọc lại mỗi giây tới khi Android gửi xong.
  void _watchExpiry(CheckInStatus status) {
    _expiry?.cancel();
    final now = DateTime.now();
    if (status.isOverdue(now) || status.isSending(now)) {
      _expiry = Timer(pollInterval, _poll);
      return;
    }
    final deadline = status.deadline;
    if (deadline != null) {
      _expiry = Timer(
        deadline.difference(now) + const Duration(milliseconds: 50),
        _poll,
      );
    }
  }

  /// Lần đọc lại tự động: lỗi thì thử lại theo lịch cũ thay vì dừng hẳn.
  Future<void> _poll() async {
    try {
      await refresh();
    } catch (_) {
      final last = state.value;
      if (ref.mounted && last != null) {
        _watchExpiry(last);
      }
    }
  }

  Future<void> refresh() async {
    final status = await _platform.checkInStatus();
    if (ref.mounted) {
      _watchExpiry(status);
      state = AsyncData(status);
    }
  }

  static String payloadFor(SosSettings settings) => jsonEncode({
    'contacts': [
      for (final contact in settings.contacts)
        {'name': contact.label, 'phone': contact.phone},
    ],
    'template': settings.template,
    'plain': settings.plainText,
    'autoCall': settings.autoCall,
  });

  /// Trả về false nếu chỉ đặt được báo thức không chính xác.
  Future<bool> start(Duration duration) async {
    final settings = await ref.read(sosSettingsProvider.future);
    final exact = await _platform.startCheckIn(
      DateTime.now().add(duration),
      payloadFor(settings),
    );
    await refresh();
    return exact;
  }

  Future<void> extend([Duration by = extension]) async {
    final current = (await future).deadline;
    final now = DateTime.now();
    final base = current == null || current.isBefore(now) ? now : current;
    final settings = await ref.read(sosSettingsProvider.future);
    await _platform.startCheckIn(base.add(by), payloadFor(settings));
    await refresh();
  }

  Future<void> cancel() async {
    await _platform.cancelCheckIn();
    await refresh();
  }

  Future<void> clearResult() async {
    await _platform.clearCheckInResult();
    await refresh();
  }

  Future<void> syncSettings(SosSettings settings) async {
    final deadline = state.value?.deadline;
    if (deadline == null) {
      return;
    }
    if (!settings.isReady) {
      // Không còn ai để gửi: hẹn giờ không còn ý nghĩa.
      await cancel();
      return;
    }
    await _platform.startCheckIn(deadline, payloadFor(settings));
  }
}
