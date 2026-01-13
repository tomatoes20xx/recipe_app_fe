import "dart:convert";
import "package:http/http.dart" as http;

import "../config.dart";
import "../auth/token_storage.dart";

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  ApiException(this.statusCode, this.message, {this.details});

  @override
  String toString() => "ApiException($statusCode): $message";
}

class ApiClient {
  ApiClient({required this.tokenStorage, http.Client? client})
      : _client = client ?? http.Client();

  final TokenStorage tokenStorage;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse("${Config.apiBaseUrl}$path").replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({bool auth = false, bool hasBody = false}) async {
  final h = <String, String>{
    "Accept": "application/json",
  };

  if (hasBody) {
    h["Content-Type"] = "application/json";
  }

  if (auth) {
    final token = await tokenStorage.readToken();
    if (token != null && token.isNotEmpty) {
      h["Authorization"] = "Bearer $token";
    }
  }

  return h;
}

  Future<dynamic> get(String path, {Map<String, String>? query, bool auth = false}) async {
  try {
    final res = await _client.get(_uri(path, query), headers: await _headers(auth: auth));
    return _handle(res);
  } on http.ClientException catch (e) {
    throw ApiException(0, "Connection failed: ${e.message}. Make sure your backend is running and your phone is on the same network.");
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException(0, "Network error: $e");
  }
}

  Future<dynamic> post(String path, {Object? body, bool auth = false}) async {
  try {
    final res = await _client.post(
      _uri(path),
      headers: await _headers(auth: auth, hasBody: body != null),
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(res);
  } on http.ClientException catch (e) {
    throw ApiException(0, "Connection failed: ${e.message}. Make sure your backend is running and your phone is on the same network.");
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException(0, "Network error: $e");
  }
}

  Future<dynamic> patch(String path, {Object? body, bool auth = false}) async {
  final res = await _client.patch(
    _uri(path),
    headers: await _headers(auth: auth, hasBody: body != null),
    body: body == null ? null : jsonEncode(body),
  );
  return _handle(res);
}

 Future<dynamic> put(String path, {Object? body, bool auth = false}) async {
  final res = await _client.put(
    _uri(path),
    headers: await _headers(auth: auth, hasBody: body != null),
    body: body == null ? null : jsonEncode(body),
  );
  return _handle(res);
}

Future<dynamic> delete(String path, {Object? body, bool auth = false}) async {
  final res = await _client.delete(
    _uri(path),
    headers: await _headers(auth: auth, hasBody: body != null),
    body: body == null ? null : jsonEncode(body),
  );
  return _handle(res);
}

Future<dynamic> postMultipart(
  String path, {
  required Map<String, String> fields,
  required List<http.MultipartFile> files,
  bool auth = false,
}) async {
  final request = http.MultipartRequest('POST', _uri(path));
  
  // Add fields
  request.fields.addAll(fields);
  
  // Add files
  request.files.addAll(files);
  
  // Add auth header
  if (auth) {
    final token = await tokenStorage.readToken();
    if (token != null && token.isNotEmpty) {
      request.headers["Authorization"] = "Bearer $token";
    }
  }
  
  request.headers["Accept"] = "application/json";
  
  final streamedResponse = await _client.send(request);
  final res = await http.Response.fromStream(streamedResponse);
  return _handle(res);
}


  dynamic _handle(http.Response res) {
    final isJson = (res.headers["content-type"] ?? "").contains("application/json");
    final data = isJson && res.body.isNotEmpty ? jsonDecode(res.body) : res.body;

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    // Fastify often returns { error, message } or { error, details }
    String msg = "Request failed";
    if (isJson) {
      if (data is Map) {
        msg = data["error"]?.toString() ?? 
              data["message"]?.toString() ?? 
              data["details"]?.toString() ??
              "Request failed";
        // If there's a validation error, try to get more details
        if (data["details"] != null && data["details"] is Map) {
          final details = data["details"] as Map;
          if (details.containsKey("message")) {
            msg = details["message"].toString();
          } else if (details.isNotEmpty) {
            // Format validation errors
            final errors = details.entries.map((e) => "${e.key}: ${e.value}").join(", ");
            if (errors.isNotEmpty) {
              msg = errors;
            }
          }
        }
        
        // Check for formErrors and fieldErrors (common in validation)
        if (data.containsKey("formErrors") || data.containsKey("fieldErrors")) {
          final formErrors = data["formErrors"];
          final fieldErrors = data["fieldErrors"];
          
          if (fieldErrors is Map && fieldErrors.isNotEmpty) {
            final fieldErrorList = fieldErrors.entries
                .map((e) => "${e.key}: ${e.value}")
                .join(", ");
            msg = "fieldErrors: {$fieldErrorList}";
          } else if (formErrors is List && formErrors.isNotEmpty) {
            msg = "formErrors: ${formErrors.join(", ")}";
          }
        }
      }
    }

    throw ApiException(res.statusCode, msg, details: data);
  }
}
