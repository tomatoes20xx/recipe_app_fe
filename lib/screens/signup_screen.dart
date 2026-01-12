import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";

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

    return Scaffold(
      appBar: AppBar(title: const Text("Sign up")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: displayNameCtrl,
              decoration: const InputDecoration(labelText: "Display name (optional)"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password (min 8)"),
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
                    : const Text("Create account"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
