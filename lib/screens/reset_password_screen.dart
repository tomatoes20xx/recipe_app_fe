import "package:flutter/material.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../utils/error_utils.dart";

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.auth,
    required this.email,
  });

  final AuthController auth;
  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isResetting = false;
  bool _isResending = false;
  bool _codeSent = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final localizations = AppLocalizations.of(context);
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (code.isEmpty) {
      ErrorUtils.showError(
        context,
        localizations?.pleaseEnterResetCode ?? "Please enter the reset code",
      );
      return;
    }

    if (code.length != 6) {
      ErrorUtils.showError(context, "Reset code must be exactly 6 digits");
      return;
    }

    if (password.isEmpty) {
      ErrorUtils.showError(
        context,
        localizations?.pleaseEnterPassword ?? "Please enter a new password",
      );
      return;
    }

    if (password.length < 8) {
      ErrorUtils.showError(
        context,
        localizations?.passwordTooShort ?? "Password must be at least 8 characters",
      );
      return;
    }

    if (password != confirmPassword) {
      ErrorUtils.showError(
        context,
        localizations?.passwordsDoNotMatch ?? "Passwords do not match",
      );
      return;
    }

    setState(() => _isResetting = true);

    try {
      await widget.auth.resetPassword(
        email: widget.email,
        code: code,
        newPassword: password,
      );

      if (mounted) {
        // Clear any error SnackBars before showing success
        ScaffoldMessenger.of(context).clearSnackBars();

        // Show success message
        ErrorUtils.showSuccess(
          context,
          localizations?.passwordResetSuccess ?? "Password reset successfully!",
        );

        // Go back to login screen after a brief delay to show success message
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isResending = true;
      _codeSent = false;
    });

    try {
      await widget.auth.requestPasswordReset(widget.email);

      if (mounted) {
        setState(() => _codeSent = true);
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.resetPassword ?? "Reset Password"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Icon(
                Icons.lock_outline,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                localizations?.enterResetCode ?? "Enter Reset Code",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                localizations?.resetCodeMessage(widget.email) ??
                    "We've sent a 6-digit code to ${widget.email}. Enter it below along with your new password.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: localizations?.resetCode ?? "Reset Code",
                  hintText: localizations?.enterResetCode ?? "Enter 6-digit code",
                  prefixIcon: const Icon(Icons.pin_outlined),
                  border: const OutlineInputBorder(),
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
                maxLength: 6,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: localizations?.newPassword ?? "New Password",
                  hintText: localizations?.enterNewPassword ?? "Enter new password",
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: localizations?.confirmPassword ?? "Confirm Password",
                  hintText: localizations?.enterPasswordAgain ?? "Enter password again",
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword);
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _resetPassword(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isResetting ? null : _resetPassword,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isResetting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(localizations?.resetPassword ?? "Reset Password"),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isResending ? null : _resendCode,
                child: _isResending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(localizations?.resendCode ?? "Resend Code"),
              ),
              if (_codeSent)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    localizations?.resetCodeSent ?? "Reset code sent!",
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
