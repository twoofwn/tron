import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../services/storage_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(storage: ref.watch(storageServiceProvider));
});

class ApiException implements Exception {
  const ApiException(this.errorCode, this.message, {this.statusCode = 400});
  final String errorCode;
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.storage, http.Client? httpClient, String? baseUrl})
    : _http = httpClient ?? http.Client(),
      _baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).replaceAll(
        RegExp(r'/+$'),
        '',
      );

  final StorageService storage;
  final http.Client _http;
  final String _baseUrl;

  static const _accessTokenKey = AppConfig.accessTokenKey;
  static const _refreshTokenKey = AppConfig.refreshTokenKey;

  String get baseUrl => _baseUrl;

  Future<bool> hasToken() async {
    final token = await storage.read(_accessTokenKey);
    return token != null && token.isNotEmpty;
  }

  Uri _uri(String path) =>
      Uri.parse('$_baseUrl${AppConfig.apiVersionPrefix}$path');

  Future<Map<String, String>> _headers({bool authenticated = true}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (authenticated) {
      final token = await storage.read(_accessTokenKey);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) async {
    final response = await _sendWithRefresh(
      () async => _http.post(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(body),
      ),
      authenticated: authenticated,
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) async {
    final response = await _sendWithRefresh(
      () async => _http.put(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(body),
      ),
      authenticated: authenticated,
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _sendWithRefresh(
      () async => _http.get(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
      ),
      authenticated: authenticated,
    );
    return _decodeObject(response);
  }

  Future<List<Map<String, dynamic>>> getList(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _sendWithRefresh(
      () async => _http.get(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
      ),
      authenticated: authenticated,
    );
    _ensureSuccess(response);
    if (response.bodyBytes.isEmpty) return const [];
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> delete(String path, {bool authenticated = true}) async {
    final response = await _sendWithRefresh(
      () async => _http.delete(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
      ),
      authenticated: authenticated,
    );
    _ensureSuccess(response);
  }

  Future<Uint8List> getBytes(String path, {bool authenticated = true}) async {
    final response = await _sendWithRefresh(
      () async => _http.get(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
      ),
      authenticated: authenticated,
    );
    _ensureSuccess(response);
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> uploadMultipart(
    String path, {
    required String fileName,
    required Uint8List bytes,
    required String kind,
  }) async {
    Future<http.Response> sendOnce() async {
      final request = http.MultipartRequest('POST', _uri(path));
      final token = await storage.read(_accessTokenKey);
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.fields['kind'] = kind;
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );
      final streamed = await _http.send(request);
      return http.Response.fromStream(streamed);
    }

    final response = await _sendWithRefresh(sendOnce, authenticated: true);
    return _decodeObject(response);
  }

  Future<http.Response> _sendWithRefresh(
    Future<http.Response> Function() requestFn, {
    required bool authenticated,
  }) async {
    try {
      var response = await requestFn().timeout(AppConfig.apiTimeout);
      if (authenticated && response.statusCode == 401) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          response = await requestFn().timeout(AppConfig.apiTimeout);
        }
      }
      return response;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'NETWORK_ERROR',
        'Không thể kết nối tới máy chủ TRỐN. Kiểm tra mạng hoặc địa chỉ server.',
        statusCode: 503,
      );
    }
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await storage.read(_refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await _http.post(
        _uri('/auth/refresh'),
        headers: await _headers(authenticated: false),
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
        await storage.write(_accessTokenKey, data['accessToken'] as String);
        await storage.write(_refreshTokenKey, data['refreshToken'] as String);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    _ensureSuccess(response);
    if (response.bodyBytes.isEmpty) return const {};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return Map<String, dynamic>.from(decoded as Map);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    var code = 'SERVER_ERROR';
    var detail = 'Yêu cầu không thành công (${response.statusCode}).';
    if (response.bodyBytes.isNotEmpty) {
      try {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json is Map) {
          code = (json['errorCode'] ?? json['title'] ?? code).toString();
          detail = (json['detail'] ?? detail).toString();
        }
      } catch (_) {}
    }
    throw ApiException(code, detail, statusCode: response.statusCode);
  }
}
