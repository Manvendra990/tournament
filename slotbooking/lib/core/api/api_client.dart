import 'dart:convert';
import 'dart:io';
import 'session_manager.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  // Use a device-safe default for Android emulator, and override it for a
  // physical phone with your computer's LAN IP, e.g.:
  // flutter run --dart-define=API_BASE_URL=http://192.168.1.25:3000/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000/api/v1',
  );
  //
  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$cleanPath');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: query.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
    );
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    if (auth && SessionManager.token != null) {
      headers[HttpHeaders.authorizationHeader] =
          'Bearer ${SessionManager.token}';
    }
    return headers;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) => _request('GET', path, query: query, auth: auth);

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) => _request('POST', path, body: body, auth: auth);

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) => _request('PATCH', path, body: body, auth: auth);

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) => _request('DELETE', path, body: body, auth: auth);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, _uri(path, query));
      final headers = await _headers(auth: auth);
      headers.forEach(request.headers.set);
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      dynamic decoded;
      if (text.isNotEmpty) {
        try {
          decoded = jsonDecode(text);
        } catch (_) {
          decoded = text;
        }
      }
      return _decode(response.statusCode, decoded);
    } on SocketException catch (e) {
      throw ApiException('Cannot connect to API: ${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  dynamic _decode(int statusCode, dynamic payload) {
    if (statusCode >= 200 && statusCode < 300) {
      if (payload is Map && payload.containsKey('data')) return payload['data'];
      return payload;
    }
    String message = 'Request failed ($statusCode)';
    if (payload is Map && payload['message'] != null) {
      message = payload['message'].toString();
    } else if (payload is String && payload.isNotEmpty) {
      message = payload;
    }
    throw ApiException(message, statusCode);
  }

  Future<dynamic> multipartPatch(
    String path, {
    Map<String, String> fields = const {},
    File? file,
    String fileField = 'photo',
    bool auth = true,
  }) async {
    final client = HttpClient();
    final boundary = '----kinetic${DateTime.now().microsecondsSinceEpoch}';
    try {
      final request = await client.patchUrl(_uri(path));
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (auth && SessionManager.token != null) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${SessionManager.token}',
        );
      }

      for (final entry in fields.entries) {
        request.write('--$boundary\r\n');
        request.write(
          'Content-Disposition: form-data; name="${entry.key}"\r\n\r\n',
        );
        request.write('${entry.value}\r\n');
      }

      if (file != null) {
        final filename = file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : 'photo.jpg';
        final ext = filename.toLowerCase().split('.').last;
        final mime = switch (ext) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          'gif' => 'image/gif',
          _ => 'image/jpeg',
        };
        request.write('--$boundary\r\n');
        request.write(
          'Content-Disposition: form-data; name="$fileField"; filename="$filename"\r\n',
        );
        request.write('Content-Type: $mime\r\n\r\n');
        await request.addStream(file.openRead());
        request.write('\r\n');
      }

      request.write('--$boundary--\r\n');
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      dynamic decoded;
      if (text.isNotEmpty) decoded = jsonDecode(text);
      return _decode(response.statusCode, decoded);
    } finally {
      client.close(force: true);
    }
  }
}
