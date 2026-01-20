import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";

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

      if (mounted) Navigator.of(context).pop(); // go back to login gate -> becomes logged in
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
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: loading ? null : onSignup,
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
