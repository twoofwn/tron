import 'package:tron/features/sos/services/sos_message.dart';
import 'package:tron/features/sos/services/sos_platform.dart';

/// Android giả: ghi lại lệnh, không gửi SMS hay gọi thật.
class FakeSosPlatform extends SosPlatform {
  FakeSosPlatform({
    this.location = const SosLocation(
      latitude: 10.5,
      longitude: 106.25,
      accuracy: 12,
    ),
    Set<String>? failingPhones,
  }) : failingPhones = failingPhones ?? {};

  SosLocation? location;
  final Set<String> failingPhones;
  final sms = <(String, String)>[];
  final calls = <String>[];
  final dials = <String>[];
  final checkIns = <(DateTime, String)>[];
  int cancelledCheckIns = 0;
  CheckInStatus status = const CheckInStatus();

  @override
  bool get isSupported => true;

  @override
  Future<SosLocation?> locate({
    Duration timeout = const Duration(seconds: 8),
  }) async => location;

  @override
  Future<int?> battery() async => 64;

  @override
  Future<String?> sendSms(String phone, String text) async {
    sms.add((phone, text));
    return failingPhones.contains(phone) ? 'send_failed_1' : null;
  }

  @override
  Future<bool> call(String phone) async {
    calls.add(phone);
    return true;
  }

  @override
  Future<void> dial(String phone) async => dials.add(phone);

  @override
  Future<bool> startCheckIn(DateTime deadline, String payload) async {
    checkIns.add((deadline, payload));
    status = CheckInStatus(deadline: deadline);
    return true;
  }

  @override
  Future<void> cancelCheckIn() async {
    cancelledCheckIns += 1;
    status = const CheckInStatus();
  }

  @override
  Future<CheckInStatus> checkInStatus() async => status;

  @override
  Future<void> clearCheckInResult() async {
    status = CheckInStatus(deadline: status.deadline);
  }
}

/// Quyền giả: [granted] là các quyền đã cấp; xin quyền thì cấp nếu [grantOnRequest].
class FakeSosPermissions extends SosPermissionService {
  FakeSosPermissions({Set<SosPermission>? granted, this.grantOnRequest = true})
    : granted = granted ?? SosPermission.values.toSet();

  final Set<SosPermission> granted;
  final bool grantOnRequest;
  final requested = <SosPermission>[];

  @override
  Future<bool> isGranted(SosPermission permission) async =>
      granted.contains(permission);

  @override
  Future<bool> request(SosPermission permission) async {
    requested.add(permission);
    if (grantOnRequest) {
      granted.add(permission);
    }
    return granted.contains(permission);
  }
}
