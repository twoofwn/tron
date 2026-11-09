import 'package:flutter/foundation.dart';

/// Một người nhận SOS. Người đầu danh sách là người được gọi trước.
@immutable
class SosContact {
  const SosContact({required this.id, required this.name, required this.phone});

  factory SosContact.fromJson(Map<String, dynamic> json) => SosContact(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String,
  );

  final String id;
  final String name;
  final String phone;

  /// Tên để hiển thị; chưa đặt tên thì dùng số.
  String get label => name.trim().isEmpty ? phone : name.trim();

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone};

  SosContact copyWith({String? name, String? phone}) =>
      SosContact(id: id, name: name ?? this.name, phone: phone ?? this.phone);

  @override
  bool operator ==(Object other) =>
      other is SosContact &&
      other.id == id &&
      other.name == name &&
      other.phone == phone;

  @override
  int get hashCode => Object.hash(id, name, phone);

  /// Bỏ khoảng trắng, ngoặc, gạch nối. Trả về null nếu không phải số hợp lệ.
  static String? normalizePhone(String raw) {
    final number = raw.trim().replaceAll(RegExp(r'[\s().-]'), '');
    return RegExp(r'^\+?[0-9]{3,15}$').hasMatch(number) ? number : null;
  }
}

@immutable
class SosSettings {
  const SosSettings({
    this.contacts = const [],
    this.template = defaultTemplate,
    this.autoCall = true,
    this.countdownSeconds = 5,
    this.plainText = false,
  });

  factory SosSettings.fromJson(Map<String, dynamic> json) {
    final countdown = json['countdownSeconds'];
    return SosSettings(
      contacts: [
        for (final item in json['contacts'] as List? ?? const [])
          SosContact.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
      template: _migrateTemplate(json['template'] as String?),
      autoCall: json['autoCall'] as bool? ?? true,
      countdownSeconds: countdownOptions.contains(countdown)
          ? countdown as int
          : 5,
      plainText: json['plainText'] as bool? ?? false,
    );
  }

  static const defaultTemplate =
      'SOS! Mình đang gặp nguy hiểm.\n'
      '- Vị trí cuối cùng: {vitri}\n'
      '- Lúc: {thoigian}\n'
      'Vui lòng tìm cách liên lạc hoặc hỗ trợ khẩn cấp!';

  /// Mẫu mặc định trước đây. Máy còn giữ đúng mẫu này (chưa tự sửa) thì
  /// chuyển sang mẫu mới.
  static const previousDefaultTemplates = [
    '[SOS] Mình đang gặp nguy hiểm, cần giúp đỡ gấp! '
        'Vị trí của mình: {vitri} (lúc {thoigian}). '
        'Hãy gọi lại cho mình ngay.',
  ];

  static String _migrateTemplate(String? saved) {
    if (saved == null ||
        saved.trim().isEmpty ||
        previousDefaultTemplates.contains(saved.trim())) {
      return defaultTemplate;
    }
    return saved;
  }

  /// Mỗi lần SOS gửi tin cho tất cả, nên giới hạn để không tốn quá nhiều tin.
  static const maxContacts = 5;
  static const maxTemplateLength = 300;
  static const countdownOptions = [0, 3, 5, 10];

  final List<SosContact> contacts;
  final String template;

  /// Gửi tin xong thì tự gọi người đầu danh sách.
  final bool autoCall;
  final int countdownSeconds;

  /// Gửi tiếng Việt không dấu: mỗi tin chứa được nhiều chữ hơn, đỡ tốn tiền.
  final bool plainText;

  bool get isReady => contacts.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'contacts': [for (final contact in contacts) contact.toJson()],
    'template': template,
    'autoCall': autoCall,
    'countdownSeconds': countdownSeconds,
    'plainText': plainText,
  };

  SosSettings copyWith({
    List<SosContact>? contacts,
    String? template,
    bool? autoCall,
    int? countdownSeconds,
    bool? plainText,
  }) => SosSettings(
    contacts: contacts ?? this.contacts,
    template: template ?? this.template,
    autoCall: autoCall ?? this.autoCall,
    countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    plainText: plainText ?? this.plainText,
  );
}
