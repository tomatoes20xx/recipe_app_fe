import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../localization/app_localizations.dart";
import "../screens/username_selection_screen.dart";
import "../services/google_auth_service.dart";
import "../utils/error_utils.dart";
import "auth_controller.dart";

/// Runs the full Google sign-in: account picker → backend login → username
/// step for new accounts. Shared by [LoginScreen] and the account prompt sheet.
///
/// UI (dialogs, errors, the username screen) goes through [navigator], so the
/// flow keeps working even if the widget that started it is gone.
/// Returns true when the user ends up signed in.
Future<bool> signInWithGoogleFlow(NavigatorState navigator, AuthController auth) async {
  final googleAuthService = GoogleAuthService();
  try {
    final account = await googleAuthService.signInWithGoogle();
    if (account == null) return false;

    final idToken = await googleAuthService.getIdToken(account);
    if (idToken == null) {
      throw Exception("Failed to get ID token");
    }

    final response = await auth.loginWithGoogle(idToken);

    if (response.needsUsername && response.tempToken != null) {
      if (!navigator.mounted) return auth.isLoggedIn;
      await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => UsernameSelectionScreen(
            tempToken: response.tempToken!,
            suggestedDisplayName: response.suggestedDisplayName,
            authApi: auth.authApi,
            authController: auth,
            avatarUrl: response.avatarUrl,
            email: response.email,
          ),
        ),
      );
    }
    return auth.isLoggedIn;
  } on ApiException catch (e) {
    if (!navigator.mounted) return false;
    if (e.statusCode == 403) {
      await showBannedDialog(navigator.context);
    } else {
      ErrorUtils.showError(navigator.context, e);
    }
    return false;
  } catch (_) {
    if (navigator.mounted) {
      final localizations = AppLocalizations.of(navigator.context);
      ErrorUtils.showError(
        navigator.context,
        localizations?.googleSignInFailed ?? "Google Sign-In failed. Please try again.",
      );
    }
    return false;
  }
}

/// Shown when the backend answers a login with 403 (permanently banned).
Future<void> showBannedDialog(BuildContext context) async {
  final localizations = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(localizations?.accountPermanentlyBanned ?? "Account Permanently Suspended"),
      content: Text(localizations?.accountPermanentlyBannedMessage ??
          "Your account has been permanently suspended due to repeated violations of our community guidelines."),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(localizations?.ok ?? "OK"),
        ),
      ],
    ),
  );
}
