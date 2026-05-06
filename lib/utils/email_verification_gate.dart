import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../screens/email_verification_screen.dart';

/// Returns true if the user's email is verified (or no gate is needed).
/// Returns false if the gate blocked the action.
///
/// Always shows a bottom sheet prompt first, then opens EmailVerificationScreen
/// at step 1 (Send email) regardless of prior session state.
Future<bool> checkEmailVerified(BuildContext context, AuthController auth) async {
  // Not logged in — login guards handle this separately.
  if (!auth.isLoggedIn) return true;

  // me not loaded yet (slow network at startup) — fetch it now before deciding.
  if (auth.me == null) {
    await auth.refreshMe();
  }

  // Still null (offline) or already verified — let the action proceed.
  if (auth.me == null || auth.emailVerified) return true;

  final email = auth.me?['email']?.toString() ?? 'your email';
  bool openVerification = false;

  if (!context.mounted) return false;
  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text('📧', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            'Verify your email first',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'To continue, please verify your email address ($email).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                openVerification = true;
                Navigator.of(ctx).pop();
              },
              child: const Text('Verify email'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Not now'),
          ),
        ],
      ),
    ),
  );

  if (openVerification && context.mounted) {
    await _openVerificationScreen(context, auth, codeSent: auth.verificationEmailSent);
  }
  return auth.emailVerified;
}

Future<void> _openVerificationScreen(
  BuildContext context,
  AuthController auth, {
  bool codeSent = false,
}) async {
  final verified = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => EmailVerificationScreen(
        auth: auth,
        email: auth.me?['email']?.toString() ?? '',
        codeSent: codeSent,
      ),
    ),
  );
  if (verified == true) {
    await auth.refreshMe();
  }
}
