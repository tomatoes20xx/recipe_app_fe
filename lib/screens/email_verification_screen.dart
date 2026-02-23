import "package:flutter/material.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../utils/error_utils.dart";

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.auth,
    this.email,
  });

  final AuthController auth;
  final String? email;

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _tokenController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  bool _isSigningOut = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    final localizations = AppLocalizations.of(context);
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ErrorUtils.showError(context, localizations?.pleaseEnterVerificationCode ?? "Please enter the verification code");
      return;
    }

    // Backend requires exactly 6 digits
    if (token.length != 6) {
      ErrorUtils.showError(context, "Verification code must be exactly 6 digits");
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      await widget.auth.verifyEmail(token);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations?.wrongEmailSignOutConfirmTitle ?? "Sign out?"),
        content: Text(
          localizations?.wrongEmailSignOutConfirmMessage ??
              "You'll be signed out and can register again with the correct email.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.cancel ?? "Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations?.logout ?? "Sign out"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isSigningOut = true);
      try {
        await widget.auth.logout();
        if (mounted) {
          // Pop all pushed routes back to AuthGate (Route 0), which now
          // renders LoginScreen because isLoggedIn is false.
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSigningOut = false);
          ErrorUtils.showError(context, e);
        }
      }
    }
  }

  Future<void> _resendEmail() async {
    setState(() {
      _isResending = true;
      _emailSent = false;
    });

    try {
      await widget.auth.resendVerificationEmail();
      if (mounted) {
        setState(() {
          _emailSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final email = widget.email ?? widget.auth.me?["email"]?.toString() ?? "your email";

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.verifyEmail ?? "Verify Email"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Icon(
              Icons.email_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              localizations?.verifyEmailTitle ?? "Verify Your Email",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              localizations?.verifyEmailMessage(email) ?? "We've sent a verification code to $email. Please enter it below to verify your email address.",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: localizations?.verificationCode ?? "Verification Code",
                hintText: localizations?.enterVerificationCode ?? "Enter the code from your email",
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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isVerifying ? null : _verifyEmail,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isVerifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(localizations?.verify ?? "Verify"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isResending ? null : _resendEmail,
              child: _isResending
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(localizations?.resendVerificationCode ?? "Resend Code"),
            ),
            if (_emailSent)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  localizations?.verificationEmailSent ?? "Verification email sent!",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const Spacer(),
            TextButton(
              onPressed: (_isSigningOut || _isVerifying) ? null : _signOut,
              child: _isSigningOut
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      localizations?.wrongEmailSignOut ?? "Wrong email? Sign out",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
