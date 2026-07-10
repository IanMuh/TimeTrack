import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LanSyncException implements Exception {
  const LanSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LanSyncJsonProtocol {
  const LanSyncJsonProtocol({
    this.timeout = const Duration(seconds: 8),
  });

  final Duration timeout;

  Future<Map<String, Object?>> readRequest(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    if (body.trim().isEmpty) {
      return <String, Object?>{};
    }
    final decoded = jsonDecode(body);
    return requireLanJsonObject(decoded, 'request');
  }

  Future<void> writeResponse(
    HttpRequest request,
    Map<String, Object?> body, {
    int statusCode = HttpStatus.ok,
  }) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  Future<Map<String, Object?>> postJson(
    Uri uri,
    Map<String, Object?> body, {
    String? token,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(uri).timeout(timeout);
      request.headers.contentType = ContentType.json;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      request.write(jsonEncode(body));

      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decoder.bind(response).join();
      final decoded =
          responseBody.isEmpty ? <String, Object?>{} : jsonDecode(responseBody);
      final responseMap = requireLanJsonObject(decoded, 'response');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw LanSyncException(
          (responseMap['error'] as String?) ?? '局域网同步请求失败。',
        );
      }
      return responseMap;
    } on LanSyncException {
      rethrow;
    } on SocketException {
      throw const LanSyncException(
        '无法连接局域网主机，请确认两台设备在同一 Wi-Fi，并允许 Windows 防火墙访问专用网络。',
      );
    } on TimeoutException {
      throw const LanSyncException('局域网同步请求超时，请检查主机地址和网络连接。');
    } on FormatException catch (error) {
      throw LanSyncException('局域网同步响应格式不正确：$error');
    } finally {
      client.close(force: true);
    }
  }
}

Map<String, Object?> requireLanJsonObject(Object? value, String label) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  throw FormatException('Missing or invalid object field: $label.');
}
