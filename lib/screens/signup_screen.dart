import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../services/google_auth_service.dart";
import "../utils/error_utils.dart";
import "terms_and_privacy_screen.dart";
import "email_verification_screen.dart";

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final displayNameCtrl = TextEditingController();
  final _googleAuthService = GoogleAuthService();
  String? error;
  bool _termsAccepted = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    usernameCtrl.dispose();
    displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => error = null);

    try {
      // 1. Sign in with Google (opens account picker)
      final account = await _googleAuthService.signInWithGoogle();
      if (account == null) return; // User cancelled

      // 2. Get ID token
      final idToken = await _googleAuthService.getIdToken(account);
      if (idToken == null) {
        throw Exception("Failed to get ID token");
      }

      // 3. Send to backend (backend creates user if doesn't exist)
      await widget.auth.loginWithGoogle(idToken);

      // Navigation handled by AuthGate (watches authController)
    } on ApiException catch (e) {
      setState(() => error = e.message);
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    } catch (e) {
      const errorMessage = "Google Sign-In failed. Please try again.";
      setState(() => error = errorMessage);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ErrorUtils.showError(context, localizations?.googleSignInFailed ?? errorMessage);
      }
    }
  }

  Future<void> onSignup() async {
    setState(() => error = null);

    try {
      await widget.auth.signup(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
        username: usernameCtrl.text.trim(),
        displayName: displayNameCtrl.text.trim().isEmpty ? null : displayNameCtrl.text.trim(),
      );

      // Navigate to email verification screen
      if (mounted) {
        final verified = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(
              auth: widget.auth,
              email: emailCtrl.text.trim(),
            ),
          ),
        );

        // If email was verified, go back to login (user will be logged in)
        if (verified == true && mounted) {
          Navigator.of(context).pop();
        }
      }
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = "Something went wrong.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = widget.auth.isLoading;
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations?.signUp ?? "Sign up")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 8),
            // Google Sign-In Button
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: loading ? null : _handleGoogleSignIn,
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'assets/images/google_logo.png',
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback if Google logo not available
                            return const Icon(Icons.login, color: Colors.blue, size: 18);
                          },
                        ),
                      ),
                label: Text(
                  localizations?.continueWithGoogle ?? 'Continue with Google',
                  style: const TextStyle(fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 1,
                  shadowColor: Colors.black26,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Divider
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    thickness: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    localizations?.orContinue ?? 'or continue',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: theme.dividerColor.withValues(alpha: 0.5),
                    thickness: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Form Fields
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: localizations?.email ?? "Email"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: usernameCtrl,
              decoration: InputDecoration(labelText: localizations?.username ?? "Username"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: displayNameCtrl,
              decoration: InputDecoration(labelText: localizations?.displayName ?? "Display name (optional)"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: InputDecoration(labelText: localizations?.passwordMin ?? "Password (min 8)"),
            ),
            const SizedBox(height: 16),
            if (error != null)
              Text(error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),

            // Link to Terms and Privacy
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TermsAndPrivacyScreen(),
                    ),
                  );
                },
                child: Text(
                  localizations?.viewFullTerms ?? "View Terms & Privacy Policy",
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Acceptance Checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _termsAccepted,
                  onChanged: (value) {
                    setState(() {
                      _termsAccepted = value ?? false;
                    });
                  },
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _termsAccepted = !_termsAccepted;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        localizations?.acceptTermsFull ?? "I have read and accept the Terms & Privacy Policy",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Signup Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (loading || !_termsAccepted) ? null : onSignup,
                child: loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator())
                    : Text(localizations?.createAccount ?? "Create account"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
