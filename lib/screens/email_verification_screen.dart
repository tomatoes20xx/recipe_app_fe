import "package:flutter/material.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../utils/error_utils.dart";

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.auth,
    this.email,
    this.codeSent = false,
  });

  final AuthController auth;
  final String? email;

  /// Pass true when the verification email has already been sent before
  /// opening this screen (e.g. from the write-action gate). When false the
  /// screen starts on the "Send email" step.
  final bool codeSent;

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _isSending = false;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _codeSent = widget.codeSent;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String get _email =>
      widget.email ?? widget.auth.me?["email"]?.toString() ?? "your email";

  // ── Send the verification email (first time) ──────────────────────────────

  Future<void> _sendEmail() async {
    setState(() => _isSending = true);
    try {
      await widget.auth.resendVerificationEmail();
      if (mounted) setState(() => _codeSent = true);
    } catch (e) {
      if (mounted) ErrorUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Re-send (already sent once, user wants a new code) ───────────────────

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      await widget.auth.resendVerificationEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("New code sent to $_email")),
        );
      }
    } catch (e) {
      if (mounted) ErrorUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  // ── Verify the entered code ───────────────────────────────────────────────

  Future<void> _verifyEmail() async {
    final localizations = AppLocalizations.of(context);
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ErrorUtils.showError(context, localizations?.pleaseEnterVerificationCode ?? "Please enter the verification code");
      return;
    }
    if (code.length != 6) {
      ErrorUtils.showError(context, localizations?.verificationCodeMustBe6Digits ?? "Verification code must be exactly 6 digits");
      return;
    }
    setState(() => _isVerifying = true);
    try {
      await widget.auth.verifyEmail(code);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ErrorUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations?.verifyEmail ?? "Verify Email"),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _codeSent ? _buildCodeEntry(localizations) : _buildSendStep(localizations),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextButton(
              onPressed: (_isSigningOut || _isVerifying || _isSending) ? null : _signOut,
              child: _isSigningOut
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      localizations?.wrongEmailSignOut ?? "Wrong email? Sign out",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: prompt to send the email ─────────────────────────────────────

  Widget _buildSendStep(AppLocalizations? localizations) {
    return Column(
      key: const ValueKey('send'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Icon(
          Icons.mark_email_unread_outlined,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          "Verify Your Email",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "We'll send a 6-digit code to $_email.\nTap below when you're ready.",
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        FilledButton(
          onPressed: _isSending ? null : _sendEmail,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: _isSending
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text("Send verification email"),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Step 2: enter the code ────────────────────────────────────────────────

  Widget _buildCodeEntry(AppLocalizations? localizations) {
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Icon(
          Icons.mark_email_read_outlined,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          "Check Your Email",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "We sent a 6-digit code to $_email.\nEnter it below to verify your account.",
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _codeController,
          decoration: InputDecoration(
            labelText: localizations?.verificationCode ?? "Verification Code",
            hintText: localizations?.enterVerificationCode ?? "Enter the 6-digit code",
            border: const OutlineInputBorder(),
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 6, fontWeight: FontWeight.bold),
          maxLength: 6,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isVerifying ? null : _verifyEmail,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: _isVerifying
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(localizations?.verify ?? "Verify"),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _isResending ? null : _resendEmail,
          child: _isResending
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(localizations?.resendVerificationCode ?? "Resend Code"),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
