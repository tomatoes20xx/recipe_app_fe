import "dart:convert";
import "dart:io";
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
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw ApiException(0, "Request timeout. The server took too long to respond.");
      },
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
  return _multipartRequest('POST', path, fields: fields, files: files, auth: auth);
}

Future<dynamic> putMultipart(
  String path, {
  required Map<String, String> fields,
  required List<http.MultipartFile> files,
  bool auth = false,
}) async {
  return _multipartRequest('PUT', path, fields: fields, files: files, auth: auth);
}

Future<dynamic> _multipartRequest(
  String method,
  String path, {
  required Map<String, String> fields,
  required List<http.MultipartFile> files,
  bool auth = false,
}) async {
  try {
    final request = http.MultipartRequest(method, _uri(path));
    
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
    
    // Increase timeout for large file uploads (2 minutes for large images)
    final streamedResponse = await _client.send(request).timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        throw ApiException(0, "Request timeout. The server took too long to respond. Try using smaller images.");
      },
    );
    final res = await http.Response.fromStream(streamedResponse);
    return _handle(res);
  } on http.ClientException catch (e) {
    // Handle connection reset/aborted errors (ECONNRESET, EPIPE)
    final message = e.message.toLowerCase();
    if (message.contains("connection closed") || 
        message.contains("connection reset") ||
        message.contains("aborted") ||
        message.contains("broken pipe")) {
      throw ApiException(499, "Upload was cancelled or connection was reset. Please try again.");
    }
    throw ApiException(0, "Connection failed: ${e.message}. Make sure your backend is running and your phone is on the same network.");
  } on SocketException catch (e) {
    throw ApiException(0, "Network error: ${e.message}. Check your internet connection.");
  } catch (e) {
    if (e is ApiException) rethrow;
    throw ApiException(0, "Network error: $e");
  }
}


  dynamic _handle(http.Response res) {
    final isJson = (res.headers["content-type"] ?? "").contains("application/json");
    final data = isJson && res.body.isNotEmpty ? jsonDecode(res.body) : res.body;

    // Handle 499 (Client Closed Request) - connection was reset/aborted
    if (res.statusCode == 499) {
      throw ApiException(499, "Upload was cancelled or connection was reset. Please try again.");
    }

    // Handle 204 No Content (common for DELETE requests)
    if (res.statusCode == 204) return null;
    
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
          } else if (details.containsKey("fieldErrors")) {
            // Handle nested fieldErrors in details: { error: "...", details: { fieldErrors: {...} } }
            final fieldErrors = details["fieldErrors"];
            if (fieldErrors is Map && fieldErrors.isNotEmpty) {
              final fieldErrorList = fieldErrors.entries
                  .map((e) {
                    final field = e.key.toString();
                    final value = e.value;
                    // Handle array of error messages: ["error1", "error2"]
                    if (value is List && value.isNotEmpty) {
                      return "$field: ${value.first}";
                    }
                    return "$field: $value";
                  })
                  .join(", ");
              msg = "fieldErrors: {$fieldErrorList}";
            }
          } else if (details.containsKey("formErrors")) {
            // Handle nested formErrors in details
            final formErrors = details["formErrors"];
            if (formErrors is List && formErrors.isNotEmpty) {
              msg = "formErrors: ${formErrors.join(", ")}";
            }
          } else if (details.isNotEmpty) {
            // Format validation errors
            final errors = details.entries.map((e) => "${e.key}: ${e.value}").join(", ");
            if (errors.isNotEmpty) {
              msg = errors;
            }
          }
        }
        
        // Check for formErrors and fieldErrors at root level (common in validation)
        if (data.containsKey("formErrors") || data.containsKey("fieldErrors")) {
          final formErrors = data["formErrors"];
          final fieldErrors = data["fieldErrors"];
          
          if (fieldErrors is Map && fieldErrors.isNotEmpty) {
            final fieldErrorList = fieldErrors.entries
                .map((e) {
                  final field = e.key.toString();
                  final value = e.value;
                  // Handle array of error messages: ["error1", "error2"]
                  if (value is List && value.isNotEmpty) {
                    return "$field: ${value.first}";
                  }
                  return "$field: $value";
                })
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
