import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tron/core/config/app_config.dart';
import 'package:tron/features/sos/models/sos_settings.dart';
import 'package:tron/features/sos/providers/sos_providers.dart';

import 'sos_fakes.dart';

void main() {
  late FakeSosPlatform platform;

  ProviderContainer container() {
    final value = ProviderContainer(
      overrides: [sosPlatformProvider.overrideWithValue(platform)],
    );
    addTearDown(value.dispose);
    return value;
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    platform = FakeSosPlatform();
  });

  test('The old single trusted number becomes the first contact', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.${AppConfig.emergencyKey}': '0901 234 567',
    });
    final settings = await container().read(sosSettingsProvider.future);
    expect(settings.contacts.single.phone, '0901234567');
    expect(settings.template, SosSettings.defaultTemplate);
  });

  test('Damaged saved data falls back to defaults', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.${AppConfig.sosKey}': '{not json',
    });
    final settings = await container().read(sosSettingsProvider.future);
    expect(settings.contacts, isEmpty);
    expect(settings.countdownSeconds, 5);
  });

  test('Contacts, message and options survive a restart', () async {
    final first = container();
    final notifier = first.read(sosSettingsProvider.notifier);
    await first.read(sosSettingsProvider.future);
    expect(await notifier.addContact(name: 'Mẹ', phone: '0901234567'), isNull);
    expect(await notifier.addContact(name: 'Anh', phone: '0912345678'), isNull);
    await notifier.reorder(1, 0);
    await notifier.modify(
      (value) => value.copyWith(
        template: 'Giúp mình {vitri}',
        autoCall: false,
        countdownSeconds: 10,
        plainText: true,
      ),
    );

    final restored = await container().read(sosSettingsProvider.future);
    expect(restored.contacts.map((item) => item.label), ['Anh', 'Mẹ']);
    expect(restored.template, 'Giúp mình {vitri}');
    expect(restored.autoCall, isFalse);
    expect(restored.countdownSeconds, 10);
    expect(restored.plainText, isTrue);
  });

  test('Invalid, duplicate and extra contacts are refused', () async {
    final value = container();
    final notifier = value.read(sosSettingsProvider.notifier);
    await value.read(sosSettingsProvider.future);
    expect(
      await notifier.addContact(name: '', phone: '12'),
      'Số điện thoại không hợp lệ.',
    );
    expect(await notifier.addContact(name: '', phone: '0900000000'), isNull);
    expect(
      await notifier.addContact(name: '', phone: '090 000 0000'),
      'Số này đã có trong danh sách.',
    );
    for (var i = 1; i < SosSettings.maxContacts; i++) {
      expect(await notifier.addContact(name: '', phone: '090000000$i'), isNull);
    }
    expect(
      await notifier.addContact(name: '', phone: '0911111111'),
      'Chỉ thêm được tối đa ${SosSettings.maxContacts} người.',
    );
    expect(
      (await value.read(sosSettingsProvider.future)).contacts,
      hasLength(SosSettings.maxContacts),
    );
  });

  test('Check-in sends the current contacts and message to Android', () async {
    final value = container();
    final notifier = value.read(sosSettingsProvider.notifier);
    await value.read(sosSettingsProvider.future);
    await value.read(checkInProvider.future);
    await notifier.addContact(name: 'Mẹ', phone: '0901234567');

    final before = DateTime.now();
    expect(
      await value
          .read(checkInProvider.notifier)
          .start(const Duration(minutes: 30)),
      isTrue,
    );
    final (deadline, payload) = platform.checkIns.single;
    expect(deadline.difference(before).inMinutes, inInclusiveRange(29, 30));
    final json = jsonDecode(payload) as Map<String, dynamic>;
    expect(json['contacts'], [
      {'name': 'Mẹ', 'phone': '0901234567'},
    ]);
    expect(json['template'], SosSettings.defaultTemplate);
    expect(value.read(checkInProvider).value?.isActive, isTrue);

    // Đổi nội dung khi đang hẹn giờ: Android nhận nội dung mới, giữ nguyên hạn.
    await notifier.modify((current) => current.copyWith(template: 'Mới'));
    expect(platform.checkIns, hasLength(2));
    expect(platform.checkIns.last.$1, deadline);
    expect(jsonDecode(platform.checkIns.last.$2)['template'], 'Mới');

    await value.read(checkInProvider.notifier).extend();
    expect(
      platform.checkIns.last.$1.difference(deadline),
      const Duration(minutes: 15),
    );

    await value.read(checkInProvider.notifier).cancel();
    expect(platform.cancelledCheckIns, 1);
    expect(value.read(checkInProvider).value?.isActive, isFalse);
  });

  test('Removing the last contact stops a running check-in', () async {
    final value = container();
    final notifier = value.read(sosSettingsProvider.notifier);
    await value.read(sosSettingsProvider.future);
    await value.read(checkInProvider.future);
    await notifier.addContact(name: 'Mẹ', phone: '0901234567');
    await value.read(checkInProvider.notifier).start(const Duration(hours: 1));

    final id = (await value.read(sosSettingsProvider.future))
        .contacts
        .single
        .id;
    await notifier.removeContact(id);
    expect(platform.cancelledCheckIns, 1);
  });
}
