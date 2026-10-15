import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/backend_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'ApiException [$statusCode]: $message';
}

class ApiClient {
  final http.Client _httpClient;
  final String? baseUrlOverride;

  ApiClient({
    http.Client? httpClient,
    this.baseUrlOverride,
  }) : _httpClient = httpClient ?? http.Client();

  String get baseUrl => baseUrlOverride ?? BackendConfig.baseUrl;

  /// Retrieves the current Supabase JWT token if available.
  String? get _authToken {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && !session.isExpired && session.accessToken.isNotEmpty) {
        return session.accessToken;
      }
    } catch (_) {
      // Supabase not initialized or no active session
    }
    return null;
  }

  Map<String, String> _buildHeaders({Map<String, String>? extraHeaders}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = _authToken;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$baseUrl$cleanPath';
    final baseUri = Uri.parse(fullUrl);

    if (queryParameters != null && queryParameters.isNotEmpty) {
      final stringParams = queryParameters.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      return baseUri.replace(queryParameters: stringParams);
    }

    return baseUri;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    try {
      final response = await _httpClient
          .get(uri, headers: _buildHeaders(extraHeaders: headers))
          .timeout(BackendConfig.timeout);

      return _handleResponse(response);
    } on SocketException catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Cannot reach backend server. Please check your network connection.',
        details: e.toString(),
      );
    } on TimeoutException {
      throw const ApiException(
        statusCode: 408,
        message: 'Request timed out waiting for backend server response.',
      );
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    try {
      final response = await _httpClient
          .post(
            uri,
            headers: _buildHeaders(extraHeaders: headers),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(BackendConfig.timeout);

      return _handleResponse(response);
    } on SocketException catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Cannot reach backend server. Please check your network connection.',
        details: e.toString(),
      );
    } on TimeoutException {
      throw const ApiException(
        statusCode: 408,
        message: 'Request timed out waiting for backend server response.',
      );
    }
  }

  Future<dynamic> patch(
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path);
    try {
      final response = await _httpClient
          .patch(
            uri,
            headers: _buildHeaders(extraHeaders: headers),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(BackendConfig.timeout);

      return _handleResponse(response);
    } on SocketException catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Cannot reach backend server.',
        details: e.toString(),
      );
    } on TimeoutException {
      throw const ApiException(
        statusCode: 408,
        message: 'Request timed out.',
      );
    }
  }

  dynamic _handleResponse(http.Response response) {
    dynamic jsonBody;
    try {
      jsonBody = jsonDecode(response.body);
    } catch (_) {
      jsonBody = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonBody;
    }

    final message = jsonBody is Map
        ? (jsonBody['message'] as String? ?? 'Request failed with status ${response.statusCode}')
        : 'Request failed with status ${response.statusCode}';

    final errors = jsonBody is Map ? jsonBody['errors'] : null;

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
      details: errors,
    );
  }
}
