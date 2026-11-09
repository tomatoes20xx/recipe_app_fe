import "package:flutter/material.dart";

import "../analytics/analytics_service.dart";
import "../api/api_client.dart";
import "../localization/app_localizations.dart";
import "../screens/email_verification_screen.dart";
import "../screens/login_screen.dart";
import "../widgets/auth/auth_prompt_sheet.dart";
import "account_reason.dart";
import "../widgets/common/app_bottom_sheet.dart";
import "auth_controller.dart";
import "google_sign_in_flow.dart";

export "account_reason.dart";

/// Login-tier gate: returns true when the user is signed in, asking a guest to
/// sign up or log in first. Callers run their action only on true.
Future<bool> requireAccount(
  BuildContext context,
  AuthController auth,
  AccountReason reason,
) async {
  if (auth.isLoggedIn) return true;
  final navigator = Navigator.of(context);
  return _promptAndAuthenticate(context, navigator, auth, reason, needsVerification: false);
}

/// Verified-tier gate (comment, follow, create recipe): the user must be
/// signed in with a verified email. A guest goes through sign-up and the code
/// screen in one go; a signed-in unverified user only sees the verify step.
Future<bool> requireVerifiedAccount(
  BuildContext context,
  AuthController auth,
  AccountReason reason,
) async {
  final navigator = Navigator.of(context);
  final wasGuest = !auth.isLoggedIn;

  if (wasGuest) {
    final signedIn = await _promptAndAuthenticate(
      context,
      navigator,
      auth,
      reason,
      needsVerification: true,
    );
    if (!signedIn) return false;
  }

  // me not loaded yet (slow network at startup) — fetch it before deciding.
  if (auth.me == null) await auth.refreshMe();
  // Still null (offline): let the action proceed; the server enforces it.
  if (auth.me == null || auth.emailVerified) return true;

  if (!wasGuest) {
    final sheetContext = context.mounted ? context : navigator.context;
    if (!sheetContext.mounted) return false;
    final proceed = await _showVerifySheet(sheetContext, auth);
    if (!proceed) return false;
  }
  await _openVerificationScreen(navigator, auth);
  return auth.emailVerified;
}

/// Handles an auth failure from a gated API call. Returns true when [error]
/// was an auth error (the caller should stop and not show its own error).
///
/// - 401: the session expired mid-use → sign out locally and ask again.
/// - 403 EMAIL_UNVERIFIED: the server wants a verified email → verify step.
Future<bool> handleAuthError(
  BuildContext context,
  AuthController auth,
  Object error,
  AccountReason reason,
) async {
  if (error is! ApiException) return false;
  if (error.statusCode == 401) {
    final navigator = Navigator.of(context);
    await auth.logout();
    final promptContext = context.mounted ? context : navigator.context;
    if (promptContext.mounted) await requireAccount(promptContext, auth, reason);
    return true;
  }
  if (isEmailUnverifiedError(error)) {
    if (context.mounted) await requireVerifiedAccount(context, auth, reason);
    return true;
  }
  return false;
}

bool isEmailUnverifiedError(Object error) =>
    error is ApiException &&
    error.statusCode == 403 &&
    error.details is Map &&
    (error.details as Map)["code"] == "EMAIL_UNVERIFIED";

Future<bool> _promptAndAuthenticate(
  BuildContext context,
  NavigatorState navigator,
  AuthController auth,
  AccountReason reason, {
  required bool needsVerification,
}) async {
  AnalyticsService().logAuthPromptShown(reason.name);
  final choice = await showAuthPromptSheet(
    context,
    reason: reason,
    needsVerification: needsVerification,
  );
  AnalyticsService().logAuthPromptChoice(reason.name, choice?.name ?? "dismiss");
  if (choice == null || !navigator.mounted) return false;

  switch (choice) {
    case AuthPromptChoice.google:
      await signInWithGoogleFlow(navigator, auth);
    case AuthPromptChoice.emailSignUp:
      await LoginScreen.open(navigator, auth, signUp: true);
    case AuthPromptChoice.logIn:
      await LoginScreen.open(navigator, auth, signUp: false);
  }
  return auth.isLoggedIn;
}

Future<void> _openVerificationScreen(NavigatorState navigator, AuthController auth) async {
  if (!navigator.mounted) return;
  final verified = await navigator.push<bool>(
    MaterialPageRoute(
      builder: (_) => EmailVerificationScreen(
        auth: auth,
        email: auth.me?["email"]?.toString() ?? "",
        codeSent: auth.verificationEmailSent,
        autoSend: true,
      ),
    ),
  );
  if (verified == true && !auth.emailVerified) {
    await auth.refreshMe();
  }
}

/// "Verify your email first" sheet for signed-in, unverified users.
/// Returns true when they tap Verify.
Future<bool> _showVerifySheet(BuildContext context, AuthController auth) async {
  final email = auth.me?["email"]?.toString() ?? "";
  final result = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) {
      final l = AppLocalizations.of(ctx);
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: 20),
              Icon(Icons.mark_email_unread_outlined, size: 40, color: Theme.of(ctx).colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                l?.emailGateTitle ?? "Verify your email first",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l?.emailGateMessage(email) ?? "To continue, please verify your email address ($email).",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l?.emailGateButton ?? "Verify email"),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l?.notNow ?? "Not now"),
              ),
            ],
          ),
        ),
      );
    },
  );
  return result == true;
}
