import "package:flutter/gestures.dart";
import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
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

    return Scaffold(
      appBar: AppBar(title: Text(localizations?.signUp ?? "Sign up")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
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
              Text(error!, style: const TextStyle(color: Colors.red)),
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
