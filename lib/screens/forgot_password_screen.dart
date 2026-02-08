import "package:flutter/material.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../utils/error_utils.dart";
import "reset_password_screen.dart";

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    final localizations = AppLocalizations.of(context);
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ErrorUtils.showError(
        context,
        localizations?.pleaseEnterEmail ?? "Please enter your email address",
      );
      return;
    }

    // Basic email validation
    if (!email.contains("@") || !email.contains(".")) {
      ErrorUtils.showError(
        context,
        localizations?.invalidEmail ?? "Please enter a valid email address",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.auth.requestPasswordReset(email);

      if (mounted) {
        // Clear any error SnackBars before navigating
        ScaffoldMessenger.of(context).clearSnackBars();
        // Navigate to reset password screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(
              auth: widget.auth,
              email: email,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.forgotPassword ?? "Forgot Password"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Icon(
                Icons.lock_reset,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                localizations?.resetPasswordTitle ?? "Reset Your Password",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                localizations?.resetPasswordMessage ??
                    "Enter your email address and we'll send you a code to reset your password.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: localizations?.email ?? "Email",
                  hintText: localizations?.enterEmail ?? "Enter your email",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendResetCode(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _sendResetCode,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(localizations?.sendResetCode ?? "Send Reset Code"),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(localizations?.backToLogin ?? "Back to Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
