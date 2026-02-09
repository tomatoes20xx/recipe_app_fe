import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/language_controller.dart";
import "../theme/theme_controller.dart";
import "email_verification_screen.dart";
import "feed_shell_screen.dart";
import "login_screen.dart";

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.apiClient,
    required this.themeController,
    required this.languageController,
  });

  final AuthController auth;
  final ApiClient apiClient;
  final ThemeController themeController;
  final LanguageController languageController;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool bootstrapped = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      // Add overall timeout to prevent infinite hanging
      await widget.auth.bootstrap().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // If bootstrap takes too long, just continue without auth
          // User can still login manually
        },
      );
    } catch (e) {
      // If bootstrap fails, still show the app (user can try to login)
      // Don't block the app from starting
    }

    // Check mounted and update state after try-catch, not in finally
    if (mounted) {
      setState(() {
        bootstrapped = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!bootstrapped) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // This makes AuthGate rebuild automatically on login/logout
    return AnimatedBuilder(
      animation: widget.auth,
      builder: (context, _) {
        if (widget.auth.isLoggedIn) {
          // Check if email is verified
          final emailVerified = widget.auth.me?['emailVerified'] == true;

          if (!emailVerified) {
            // User logged in but email not verified - show verification screen
            return EmailVerificationScreen(
              auth: widget.auth,
              email: widget.auth.me?['email'] ?? '',
            );
          }

          // Email verified - show main app
          return FeedShellScreen(
            auth: widget.auth,
            apiClient: widget.apiClient,
            themeController: widget.themeController,
            languageController: widget.languageController,
          );
        }

        return LoginScreen(auth: widget.auth);
      },
    );
  }
}
