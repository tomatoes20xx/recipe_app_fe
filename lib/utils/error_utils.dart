import "package:flutter/material.dart";
import "../api/api_client.dart";
import "../localization/app_localizations.dart";

/// Utility class for handling and formatting errors in a user-friendly way
class ErrorUtils {
  /// Converts an error to a user-friendly message
  /// If context is provided, uses localized error messages
  static String getUserFriendlyMessage(dynamic error, [BuildContext? context]) {
    final localizations = context != null ? AppLocalizations.of(context) : null;
    if (error is ApiException) {
      return _formatApiException(error, context);
    }
    
    final errorString = error.toString();
    
    // Network errors
    if (errorString.contains("Connection failed") || 
        errorString.contains("Network error") ||
        errorString.contains("SocketException")) {
      return localizations?.unableToConnect ?? "Unable to connect to the server. Please check your internet connection and try again.";
    }
    
    if (errorString.contains("timeout") || errorString.contains("Timeout")) {
      return localizations?.requestTimedOut ?? "Request timed out. Please try again.";
    }
    
    if (errorString.contains("Connection closed") || 
        errorString.contains("connection reset")) {
      return localizations?.connectionInterrupted ?? "Connection was interrupted. Please try again.";
    }
    
    // Authentication errors
    if (errorString.contains("401") || errorString.contains("Unauthorized")) {
      return localizations?.needToLogIn ?? "You need to log in to perform this action.";
    }
    
    if (errorString.contains("403") || errorString.contains("Forbidden")) {
      return localizations?.noPermission ?? "You don't have permission to perform this action.";
    }
    
    if (errorString.contains("404") || errorString.contains("Not found")) {
      return localizations?.itemNotFound ?? "The requested item could not be found.";
    }
    
    // Validation errors
    if (errorString.contains("fieldErrors") || errorString.contains("formErrors")) {
      return _extractValidationError(errorString) ?? (localizations?.invalidInput ?? "Invalid input. Please check your data and try again.");
    }
    
    // Generic error - try to extract meaningful part
    if (errorString.contains(":")) {
      final parts = errorString.split(":");
      if (parts.length > 1) {
        return parts.last.trim();
      }
    }
    
    // Default fallback
    return localizations?.somethingWentWrong ?? "Something went wrong. Please try again.";
  }
  
  /// Formats API exceptions into user-friendly messages
  static String _formatApiException(ApiException e, [BuildContext? context]) {
    final localizations = context != null ? AppLocalizations.of(context) : null;
    // Handle specific status codes
    switch (e.statusCode) {
      case 400:
        return _extractValidationError(e.message) ?? (localizations?.invalidRequest ?? "Invalid request. Please check your input and try again.");
      case 401:
        return localizations?.needToLogIn ?? "You need to log in to perform this action.";
      case 403:
        return localizations?.noPermission ?? "You don't have permission to perform this action.";
      case 404:
        return localizations?.itemNotFound ?? "The requested item could not be found.";
      case 409:
        return localizations?.actionConflict ?? "This action conflicts with the current state. Please refresh and try again.";
      case 413:
        return localizations?.fileTooLarge ?? "The file is too large. Please use a smaller file.";
      case 422:
        return _extractValidationError(e.message) ?? (localizations?.invalidData ?? "Invalid data provided. Please check your input.");
      case 429:
        return localizations?.tooManyRequests ?? "Too many requests. Please wait a moment and try again.";
      case 500:
      case 502:
      case 503:
        return localizations?.serverError ?? "Server error. Please try again later.";
      case 0:
        // Network/connection error
        if (e.message.contains("Connection failed") || e.message.contains("Network error")) {
          return localizations?.unableToConnect ?? "Unable to connect to the server. Please check your internet connection.";
        }
        return e.message;
      default:
        // Try to extract meaningful message from API response
        if (e.message.isNotEmpty && e.message != "Request failed") {
          return _extractValidationError(e.message) ?? e.message;
        }
        return localizations?.errorOccurred ?? "An error occurred. Please try again.";
    }
  }
  
  /// Extracts validation errors from error messages
  static String? _extractValidationError(String errorMessage) {
    // Handle fieldErrors format: "fieldErrors: {field1: error1, field2: error2}"
    if (errorMessage.contains("fieldErrors:")) {
      try {
        final fieldErrorsMatch = RegExp(r'fieldErrors:\s*\{([^}]+)\}').firstMatch(errorMessage);
        if (fieldErrorsMatch != null) {
          final errors = fieldErrorsMatch.group(1);
          if (errors != null && errors.isNotEmpty) {
            // Extract first meaningful error
            final errorParts = errors.split(",").first.split(":");
            if (errorParts.length >= 2) {
              final field = errorParts[0].trim();
              final message = errorParts[1].trim();
              // Capitalize field name and format
              final fieldName = field[0].toUpperCase() + field.substring(1);
              return "$fieldName: $message";
            }
          }
        }
      } catch (_) {
        // Fall through to default handling
      }
    }
    
    // Handle formErrors format: "formErrors: [error1, error2]"
    if (errorMessage.contains("formErrors:")) {
      try {
        final formErrorsMatch = RegExp(r'formErrors:\s*\[([^\]]+)\]').firstMatch(errorMessage);
        if (formErrorsMatch != null) {
          final errors = formErrorsMatch.group(1);
          if (errors != null && errors.isNotEmpty) {
            return errors.split(",").first.trim();
          }
        }
      } catch (_) {
        // Fall through to default handling
      }
    }
    
    // If message already looks user-friendly, return it
    if (!errorMessage.contains("ApiException") && 
        !errorMessage.contains("Exception") &&
        errorMessage.length < 200) {
      return errorMessage;
    }
    
    return null;
  }
  
  /// Shows a success snackbar
  static void showSuccess(BuildContext context, String message) {
    final localizations = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: localizations?.dismiss ?? "Dismiss",
          textColor: Colors.white,
          onPressed: () {
            scaffoldMessenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Shows an error snackbar
  static void showError(BuildContext context, dynamic error) {
    final localizations = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(getUserFriendlyMessage(error, context))),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: localizations?.dismiss ?? "Dismiss",
          textColor: Colors.white,
          onPressed: () {
            scaffoldMessenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
