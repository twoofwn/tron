import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tron/features/fake_call/services/call_device_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tron/call');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('Sends key and speaker commands to Android', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    final service = CallDeviceService();
    addTearDown(service.dispose);

    await service.setSilenceKeys(true);
    await service.startCallAudio(speaker: false);
    await service.setSpeaker(true);
    await service.endCallAudio();

    expect(
      [for (final call in calls) '${call.method}:${call.arguments}'],
      [
        'setSilenceKeys:true',
        'startCallAudio:false',
        'setSpeaker:true',
        'endCallAudio:null',
      ],
    );
  });

  test('Reports volume key presses from Android', () async {
    final service = CallDeviceService();
    addTearDown(service.dispose);
    final presses = <void>[];
    service.volumeKeyPresses.listen(presses.add);

    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('volumeKey')),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(presses, hasLength(1));
  });

  test('Ignores platforms without call support', () async {
    final service = CallDeviceService();
    addTearDown(service.dispose);
    // Không có code nền tảng: không được ném lỗi làm hỏng cuộc gọi.
    await service.setSpeaker(true);
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'call_audio_failed');
    });
    await service.endCallAudio();
  });
}
