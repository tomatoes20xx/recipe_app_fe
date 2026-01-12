import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "signup_screen.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  String? error;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> onLogin() async {
    setState(() => error = null);

    try {
      await widget.auth.login(emailCtrl.text.trim(), passCtrl.text);
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
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 16),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: loading ? null : onLogin,
                child: loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator())
                    : const Text("Login"),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: loading
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => SignupScreen(auth: widget.auth)),
                      );
                    },
              child: const Text("Create account"),
            )
          ],
        ),
      ),
    );
  }
}
