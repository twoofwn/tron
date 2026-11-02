import 'package:flutter_test/flutter_test.dart';
import 'package:tron/features/sos/models/sos_settings.dart';
import 'package:tron/features/sos/services/sos_message.dart';

void main() {
  final now = DateTime(2026, 11, 2, 7, 5);

  test('Placeholders are filled with the map link, time and battery', () {
    final text = SosMessage.render(
      'Cứu! {vitri} lúc {thoigian}, pin {pin}',
      location: const SosLocation(latitude: 21.0285, longitude: 105.8048),
      now: now,
      battery: 42,
    );
    expect(
      text,
      'Cứu! https://maps.google.com/?q=21.028500,105.804800 '
      'lúc 07:05 02/11, pin 42%',
    );
  });

  test('A missing location or battery is said plainly', () {
    final text = SosMessage.render('{vitri} {pin}', location: null, now: now);
    expect(text, '${SosMessage.noLocation} ?');
  });

  test('Plain mode removes every Vietnamese diacritic', () {
    expect(
      SosMessage.stripDiacritics('Đường Ước Mơ: ắ ổ ự ỹ đ Ê'),
      'Duong Uoc Mo: a o u y d E',
    );
    final text = SosMessage.render(
      'Mình đang gặp nguy hiểm',
      location: null,
      now: now,
      plain: true,
    );
    expect(text, 'Minh dang gap nguy hiem');
  });

  test('SMS count follows carrier rules for accented and plain text', () {
    expect(SosMessage.size('a' * 160).parts, 1);
    expect(SosMessage.size('a' * 161).parts, 2);
    expect(SosMessage.size('ă' * 70).parts, 1);
    expect(SosMessage.size('ă' * 71).parts, 2);
    // Ký tự mở rộng như { } tính là 2.
    expect(SosMessage.size('{' * 80).characters, 160);

    final accented = SosMessage.size(
      SosMessage.preview(SosSettings.defaultTemplate, now: now),
    );
    final plain = SosMessage.size(
      SosMessage.preview(SosSettings.defaultTemplate, plain: true, now: now),
    );
    expect(accented.unicode, isTrue);
    expect(plain.unicode, isFalse);
    expect(plain.parts, lessThan(accented.parts));
  });

  test('Phone numbers are cleaned and validated', () {
    expect(SosContact.normalizePhone(' 090 123-4567 '), '0901234567');
    expect(SosContact.normalizePhone('+84 (90) 123 4567'), '+84901234567');
    expect(SosContact.normalizePhone('12'), isNull);
    expect(SosContact.normalizePhone('abc'), isNull);
  });
}
