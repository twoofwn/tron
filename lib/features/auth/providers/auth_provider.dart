import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../models/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(apiClientProvider),
    storage: ref.watch(storageServiceProvider),
  );
});

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthUser?>(
  AuthNotifier.new,
);

class AuthRepository {
  AuthRepository({required this.api, required this.storage});
  final ApiClient api;
  final StorageService storage;

  static const _accessTokenKey = AppConfig.accessTokenKey;
  static const _refreshTokenKey = AppConfig.refreshTokenKey;
  static const _userKey = AppConfig.userKey;

  Future<AuthUser?> loadSession() async {
    final rawUser = await storage.read(_userKey);
    final refreshToken = await storage.read(_refreshTokenKey);
    if (rawUser == null || refreshToken == null || refreshToken.isEmpty) {
      return null;
    }
    try {
      final cached = AuthUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(rawUser) as Map),
      );
      return cached;
    } catch (_) {
      return null;
    }
  }

  Future<AuthUser> refreshProfileFromServer() async {
    final json = await api.getJson('/me');
    final user = AuthUser.fromJson(json);
    await storage.write(_userKey, jsonEncode(user.toJson()));
    return user;
  }

  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final json = await api.postJson('/auth/register', {
      'email': email.trim(),
      'password': password,
      'displayName': displayName.trim(),
      'deviceName': 'TRỐN Flutter App',
    }, authenticated: false);
    return _saveAuthResponse(json);
  }

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final json = await api.postJson('/auth/login', {
      'email': email.trim(),
      'password': password,
      'deviceName': 'TRỐN Flutter App',
    }, authenticated: false);
    return _saveAuthResponse(json);
  }

  Future<AuthUser> updateProfile(String displayName) async {
    final json = await api.putJson('/me', {'displayName': displayName.trim()});
    final user = AuthUser.fromJson(json);
    await storage.write(_userKey, jsonEncode(user.toJson()));
    return user;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await api.putJson('/me/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<void> logout({required bool clearLocalUserData}) async {
    final refresh = await storage.read(_refreshTokenKey);
    try {
      await api.postJson('/auth/logout', {'refreshToken': refresh});
    } catch (_) {
      // Offline logout still clears local credentials
    }
    await _clearSession(clearLocalUserData: clearLocalUserData);
  }

  Future<void> deleteAccount() async {
    await api.delete('/me');
    await _clearSession(clearLocalUserData: true);
  }

  Future<AuthUser> _saveAuthResponse(Map<String, dynamic> json) async {
    await storage.write(_accessTokenKey, json['accessToken'] as String);
    await storage.write(_refreshTokenKey, json['refreshToken'] as String);
    final user = AuthUser.fromJson(
      Map<String, dynamic>.from(json['user'] as Map),
    );
    await storage.write(_userKey, jsonEncode(user.toJson()));
    return user;
  }

  Future<void> _clearSession({required bool clearLocalUserData}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
    if (clearLocalUserData) {
      await prefs.remove(AppConfig.combosKey);
      await prefs.remove(AppConfig.emergencyKey);
      await prefs.remove(AppConfig.sosKey);
    }
  }
}

class AuthNotifier extends AsyncNotifier<AuthUser?> {
  @override
  Future<AuthUser?> build() => ref.watch(authRepositoryProvider).loadSession();

  Future<void> login(String email, String password) async {
    final user = await ref
        .read(authRepositoryProvider)
        .login(email: email, password: password);
    state = AsyncData(user);
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final user = await ref
        .read(authRepositoryProvider)
        .register(email: email, password: password, displayName: displayName);
    state = AsyncData(user);
  }

  Future<void> refreshProfile() async {
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .refreshProfileFromServer();
      state = AsyncData(user);
    } catch (_) {}
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = await ref
        .read(authRepositoryProvider)
        .updateProfile(displayName);
    state = AsyncData(user);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await ref
        .read(authRepositoryProvider)
        .changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
  }

  Future<void> logout({bool clearLocalUserData = true}) async {
    await ref
        .read(authRepositoryProvider)
        .logout(clearLocalUserData: clearLocalUserData);
    state = const AsyncData(null);
  }

  Future<void> deleteAccount() async {
    await ref.read(authRepositoryProvider).deleteAccount();
    state = const AsyncData(null);
  }
}
