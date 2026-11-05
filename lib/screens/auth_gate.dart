import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/language_controller.dart";
import "../services/update_service.dart";
import "../shopping/shopping_list_controller.dart";
import "../theme/theme_controller.dart";
import "feed_shell_screen.dart";

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.apiClient,
    required this.themeController,
    required this.languageController,
    required this.shoppingListController,
  });

  final AuthController auth;
  final ApiClient apiClient;
  final ThemeController themeController;
  final LanguageController languageController;
  final ShoppingListController shoppingListController;

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
          // If bootstrap takes too long, just continue as a guest
          // User can still log in from any account prompt
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
      // Check for updates after first frame so dialogs have a valid context.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) UpdateService.checkForUpdate(context: context);
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

    // Guests get the full app too: sign-in is asked for only when an action
    // needs an account (see auth/require_account.dart). The shell stays
    // mounted across sign-in/out and reacts to auth changes itself.
    return FeedShellScreen(
      auth: widget.auth,
      apiClient: widget.apiClient,
      themeController: widget.themeController,
      languageController: widget.languageController,
      shoppingListController: widget.shoppingListController,
    );
  }
}
