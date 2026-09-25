


import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'session_manager.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  Uri _uri(
    String path, [
    Map<String, dynamic>? query,
  ]) {
    final normalized =
        path.startsWith('/') ? path : '/$path';

    final base = Uri.parse(
      '${ApiConfig.baseUrl}$normalized',
    );

    if (query == null) {
      return base;
    }

    return base.replace(
      queryParameters: {
        for (final e in query.entries)
          if (
            e.value != null &&
            e.value.toString().isNotEmpty
          )
            e.key: e.value.toString(),
      },
    );
  }

  Future<Map<String, String>> _headers({
    bool auth = true,
    bool json = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (json) {
      headers['Content-Type'] =
          'application/json';
    }

    if (auth) {
      final token =
          await SessionManager.token();

      if (
        token != null &&
        token.isNotEmpty
      ) {
        headers['Authorization'] =
            'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    return _decode(
      await http.get(
        _uri(path, query),
        headers:
            await _headers(
          auth: auth,
        ),
      ),
    );
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    return _decode(
      await http.post(
        _uri(path),
        headers:
            await _headers(
          auth: auth,
        ),
        body:
            jsonEncode(
          body ?? {},
        ),
      ),
    );
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    return _decode(
      await http.patch(
        _uri(path),
        headers:
            await _headers(
          auth: auth,
        ),
        body:
            jsonEncode(
          body ?? {},
        ),
      ),
    );
  }

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    return _decode(
      await http.delete(
        _uri(path),
        headers:
            await _headers(
          auth: auth,
        ),
        body:
            body == null
                ? null
                : jsonEncode(body),
      ),
    );
  }

  Future<dynamic> multipart(
    String method,
    String path, {
    Map<String, String>? fields,
    Map<String, dynamic>? jsonFields,
    List<File> files = const [],
    String fileField = 'images',
    bool auth = true,
  }) async {
    final req = http.MultipartRequest(
      method,
      _uri(path),
    );

    final headers =
        await _headers(
      auth: auth,
      json: false,
    );

    req.headers.addAll(headers);

    if (fields != null) {
      req.fields.addAll(fields);
    }

    if (jsonFields != null) {
      for (
        final entry
            in jsonFields.entries
      ) {
        req.fields[entry.key] =
            jsonEncode(
          entry.value,
        );
      }
    }

    for (final file in files) {
      final mimeType =
          lookupMimeType(
            file.path,
          ) ??
          'image/jpeg';

      final mimeParts =
          mimeType.split('/');

      final type =
          mimeParts.isNotEmpty
              ? mimeParts[0]
              : 'image';

      final subtype =
          mimeParts.length > 1
              ? mimeParts[1]
              : 'jpeg';

      req.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          file.path,
          contentType:
              MediaType(
            type,
            subtype,
          ),
        ),
      );
    }

    final streamed =
        await req.send();

    final response =
        await http.Response.fromStream(
      streamed,
    );

    return _decode(response);
  }

  dynamic _decode(
    http.Response response,
  ) {
    dynamic payload;

    try {
      payload =
          response.body.isEmpty
              ? <String, dynamic>{}
              : jsonDecode(
                  response.body,
                );
    } catch (_) {
      payload = {
        'message':
            response.body,
      };
    }

    if (
      response.statusCode < 200 ||
      response.statusCode >= 300
    ) {
      final message =
          payload is Map
              ? (
                    payload['message'] ??
                    payload['error'] ??
                    'Request failed'
                  ).toString()
              : 'Request failed';

      throw ApiException(
        message,
        statusCode:
            response.statusCode,
        data: payload,
      );
    }

    if (
      payload is Map &&
      payload.containsKey('data')
    ) {
      return payload['data'];
    }

    return payload;
  }
}