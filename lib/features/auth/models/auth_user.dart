import '../../../core/config/app_config.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.role = 'User',
    this.lastBackupAt,
    this.backupComboCount = 0,
    this.backupScenarioCount = 0,
    this.usedMediaBytes = 0,
    this.quotaMediaBytes = AppConfig.defaultQuotaMediaBytes,
  });

  final String id;
  final String email;
  final String displayName;
  final String role;
  final DateTime? lastBackupAt;
  final int backupComboCount;
  final int backupScenarioCount;
  final int usedMediaBytes;
  final int quotaMediaBytes;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    role: json['role'] as String? ?? 'User',
    lastBackupAt: json['lastBackupAt'] != null
        ? DateTime.tryParse(json['lastBackupAt'] as String)
        : null,
    backupComboCount: (json['backupComboCount'] as num?)?.toInt() ?? 0,
    backupScenarioCount: (json['backupScenarioCount'] as num?)?.toInt() ?? 0,
    usedMediaBytes: (json['usedMediaBytes'] as num?)?.toInt() ?? 0,
    quotaMediaBytes:
        (json['quotaMediaBytes'] as num?)?.toInt() ??
        AppConfig.defaultQuotaMediaBytes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'role': role,
    if (lastBackupAt != null) 'lastBackupAt': lastBackupAt!.toIso8601String(),
    'backupComboCount': backupComboCount,
    'backupScenarioCount': backupScenarioCount,
    'usedMediaBytes': usedMediaBytes,
    'quotaMediaBytes': quotaMediaBytes,
  };
}
