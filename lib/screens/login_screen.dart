import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

import "../api/api_client.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../services/google_auth_service.dart";
import "../utils/error_utils.dart";
import "email_verification_screen.dart";
import "forgot_password_screen.dart";
import "terms_and_privacy_screen.dart";
import "username_selection_screen.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthController auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _googleAuthService = GoogleAuthService();
  final _storage = const FlutterSecureStorage();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _termsAccepted = false;
  String? error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool get _isSignUpFormValid {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    return email.isNotEmpty &&
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) &&
        username.isNotEmpty &&
        password.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();

    _emailController.addListener(_onFieldChanged);
    _usernameController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
    _loadRememberMe();
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _emailController.removeListener(_onFieldChanged);
    _usernameController.removeListener(_onFieldChanged);
    _passwordController.removeListener(_onFieldChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      error = null;
    });
  }

  // ── Remember Me ──

  Future<void> _loadRememberMe() async {
    try {
      final remembered = await _storage.read(key: "remember_me");
      if (remembered == "true") {
        setState(() => _rememberMe = true);
        await _attemptSilentGoogleSignIn();
      }
    } catch (e) {
      // Ignore errors loading remember me preference
    }
  }

  Future<void> _saveRememberMePreference() async {
    try {
      if (_rememberMe) {
        await _storage.write(key: "remember_me", value: "true");
      } else {
        await _storage.delete(key: "remember_me");
      }
    } catch (e) {
      // Ignore errors saving preference
    }
  }

  // ── Google Sign-In ──

  Future<void> _attemptSilentGoogleSignIn() async {
    try {
      final account = await _googleAuthService.signInSilently();
      if (account != null) {
        final idToken = await _googleAuthService.getIdToken(account);
        if (idToken != null) {
          final response = await widget.auth.loginWithGoogle(idToken);

          if (response.needsUsername && response.tempToken != null) {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UsernameSelectionScreen(
                    tempToken: response.tempToken!,
                    suggestedDisplayName: response.suggestedDisplayName,
                    authApi: widget.auth.authApi,
                    authController: widget.auth,
                    avatarUrl: response.avatarUrl,
                    email: response.email,
                  ),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      // Silent sign-in failed
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final localizations = AppLocalizations.of(context);
    setState(() => error = null);

    try {
      final account = await _googleAuthService.signInWithGoogle();
      if (account == null) return;

      final idToken = await _googleAuthService.getIdToken(account);
      if (idToken == null) {
        throw Exception("Failed to get ID token");
      }

      final response = await widget.auth.loginWithGoogle(idToken);

      if (response.needsUsername && response.tempToken != null) {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UsernameSelectionScreen(
                tempToken: response.tempToken!,
                suggestedDisplayName: response.suggestedDisplayName,
                authApi: widget.auth.authApi,
                authController: widget.auth,
                avatarUrl: response.avatarUrl,
                email: response.email,
              ),
            ),
          );
        }
      } else {
        await _saveRememberMePreference();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        if (!mounted) return;
        _showBannedDialog(localizations);
        return;
      }
      setState(() => error = e.message);
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    } catch (e) {
      const errorMessage = "Google Sign-In failed. Please try again.";
      setState(() => error = errorMessage);
      if (mounted) {
        ErrorUtils.showError(context, localizations?.googleSignInFailed ?? errorMessage);
      }
    }
  }

  // ── Email Login ──

  Future<void> _handleEmailLogin() async {
    final localizations = AppLocalizations.of(context);
    setState(() => error = null);

    try {
      await widget.auth.login(
        _emailController.text.trim(),
        _passwordController.text,
        rememberMe: _rememberMe,
      );
      await _saveRememberMePreference();
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        if (!mounted) return;
        _showBannedDialog(localizations);
        return;
      }
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = "Something went wrong.");
    }
  }

  // ── Email Signup ──

  String? _validatePassword(String password) {
    final localizations = AppLocalizations.of(context);
    if (password.length < 8) {
      return localizations?.passwordTooShort ?? "Password must be at least 8 characters";
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return localizations?.passwordNeedsUppercase ?? "Password must contain at least one uppercase letter (A-Z)";
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return localizations?.passwordNeedsLowercase ?? "Password must contain at least one lowercase letter (a-z)";
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return localizations?.passwordNeedsNumber ?? "Password must contain at least one number (0-9)";
    }
    return null;
  }

  Future<void> _handleEmailSignup() async {
    setState(() => error = null);
    final localizations = AppLocalizations.of(context);

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      final msg = localizations?.pleaseEnterEmail ?? "Please enter your email address";
      setState(() => error = msg);
      ErrorUtils.showError(context, msg);
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      final msg = localizations?.invalidEmail ?? "Please enter a valid email address";
      setState(() => error = msg);
      ErrorUtils.showError(context, msg);
      return;
    }

    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      final msg = localizations?.usernameRequired ?? "Username is required";
      setState(() => error = msg);
      ErrorUtils.showError(context, msg);
      return;
    }

    final passwordError = _validatePassword(_passwordController.text);
    if (passwordError != null) {
      setState(() => error = passwordError);
      ErrorUtils.showError(context, passwordError);
      return;
    }

    try {
      await widget.auth.signup(
        email: email,
        password: _passwordController.text,
        username: username,
        displayName: _displayNameController.text.trim().isEmpty
            ? null
            : _displayNameController.text.trim(),
      );

      if (mounted) {
        final verified = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(
              auth: widget.auth,
              email: email,
            ),
          ),
        );

        if (verified == true && mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          setState(() {
            _isSignUp = false;
            error = null;
          });
        }
      }
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = "Something went wrong.");
    }
  }

  // ── Helpers ──

  Future<void> _showBannedDialog(AppLocalizations? localizations) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(localizations?.accountPermanentlyBanned ?? "Account Permanently Suspended"),
        content: Text(localizations?.accountPermanentlyBannedMessage ??
            "Your account has been permanently suspended due to repeated violations of our community guidelines."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(localizations?.ok ?? "OK"),
          ),
        ],
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final loading = widget.auth.isLoading;
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  _buildHeroSection(theme, localizations),
                  const SizedBox(height: 32),
                  _buildGoogleButton(theme, localizations, loading),
                  const SizedBox(height: 20),
                  _buildDivider(theme, localizations),
                  const SizedBox(height: 20),
                  _buildEmailField(theme, localizations),
                  // Signup-only fields
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _isSignUp
                        ? Column(
                            children: [
                              const SizedBox(height: 14),
                              _buildUsernameField(theme, localizations),
                              const SizedBox(height: 14),
                              _buildDisplayNameField(theme, localizations),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),
                  _buildPasswordField(theme, localizations),
                  const SizedBox(height: 14),
                  // Login: remember me + forgot password; Signup: terms
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: _isSignUp
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: _buildHelperRow(theme, localizations),
                    secondChild: _buildTermsSection(theme, localizations),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildActionButton(theme, localizations, loading),
                  const SizedBox(height: 16),
                  _buildToggleLink(theme, localizations, loading),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(ThemeData theme, AppLocalizations? localizations) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              "assets/icon/app_icon.png",
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Yummy",
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _isSignUp
                ? (localizations?.createYourAccount ?? "Create your account")
                : (localizations?.appTagline ?? "Your Recipe Journey"),
            key: ValueKey(_isSignUp),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(
      ThemeData theme, AppLocalizations? localizations, bool loading) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: loading ? null : _handleGoogleSignIn,
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Container(
                width: 24,
                height: 24,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  "assets/images/google_logo.png",
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.login, color: Colors.blue, size: 18);
                  },
                ),
              ),
        label: Text(
          localizations?.continueWithGoogle ?? "Continue with Google",
          style: const TextStyle(fontSize: 16),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 1,
          shadowColor: Colors.black26,
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme, AppLocalizations? localizations) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: theme.dividerColor.withValues(alpha: 0.5),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            localizations?.orContinue ?? "or continue",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: theme.dividerColor.withValues(alpha: 0.5),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(ThemeData theme, {
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: theme.colorScheme.primary,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIcon: Icon(
        icon,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildEmailField(ThemeData theme, AppLocalizations? localizations) {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.next,
      decoration: _fieldDecoration(
        theme,
        label: localizations?.email ?? "Email",
        hint: localizations?.emailHint ?? "Enter your email",
        icon: Icons.email_outlined,
      ),
    );
  }

  Widget _buildUsernameField(ThemeData theme, AppLocalizations? localizations) {
    return TextField(
      controller: _usernameController,
      autofillHints: const [AutofillHints.username],
      textInputAction: TextInputAction.next,
      decoration: _fieldDecoration(
        theme,
        label: localizations?.username ?? "Username",
        icon: Icons.alternate_email,
      ),
    );
  }

  Widget _buildDisplayNameField(ThemeData theme, AppLocalizations? localizations) {
    return TextField(
      controller: _displayNameController,
      autofillHints: const [AutofillHints.name],
      textInputAction: TextInputAction.next,
      decoration: _fieldDecoration(
        theme,
        label: localizations?.displayName ?? "Display name (optional)",
        icon: Icons.person_outlined,
      ),
    );
  }

  Widget _buildPasswordField(ThemeData theme, AppLocalizations? localizations) {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      autofillHints: [_isSignUp ? AutofillHints.newPassword : AutofillHints.password],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) {
        if (!widget.auth.isLoading) {
          if (_isSignUp) {
            if (_isSignUpFormValid && _termsAccepted) _handleEmailSignup();
          } else {
            _handleEmailLogin();
          }
        }
      },
      decoration: _fieldDecoration(
        theme,
        label: localizations?.password ?? "Password",
        hint: localizations?.passwordHint ?? "Enter your password",
        icon: Icons.lock_outlined,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          tooltip: _obscurePassword
              ? (localizations?.showPassword ?? "Show password")
              : (localizations?.hidePassword ?? "Hide password"),
        ),
      ),
    );
  }

  Widget _buildHelperRow(ThemeData theme, AppLocalizations? localizations) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() => _rememberMe = value ?? false);
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              localizations?.rememberMe ?? "Remember me",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ForgotPasswordScreen(auth: widget.auth),
              ),
            );
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            localizations?.forgotPassword ?? "Forgot password?",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsSection(ThemeData theme, AppLocalizations? localizations) {
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
    );
    final linkStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w500,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _termsAccepted,
            onChanged: (value) {
              setState(() => _termsAccepted = value ?? false);
            },
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _termsAccepted = !_termsAccepted);
            },
            child: Text.rich(
              TextSpan(
                style: textStyle,
                children: [
                  TextSpan(
                    text: localizations?.acceptTermsText ?? "I accept the ",
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TermsAndPrivacyScreen(),
                          ),
                        );
                      },
                      child: Text(
                        localizations?.termsAndPrivacy ?? "Terms & Privacy",
                        style: linkStyle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
      ThemeData theme, AppLocalizations? localizations, bool loading) {
    final bool isDisabled;
    final VoidCallback? onPressed;

    if (_isSignUp) {
      isDisabled = loading || !_termsAccepted || !_isSignUpFormValid;
      onPressed = isDisabled ? null : _handleEmailSignup;
    } else {
      isDisabled = loading;
      onPressed = isDisabled ? null : _handleEmailLogin;
    }

    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                _isSignUp
                    ? (localizations?.createAccount ?? "Create account")
                    : (localizations?.login ?? "Login"),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildToggleLink(
      ThemeData theme, AppLocalizations? localizations, bool loading) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isSignUp
              ? (localizations?.alreadyHaveAccount ?? "Already have an account?")
              : (localizations?.dontHaveAccount ?? "Don't have an account?"),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        TextButton(
          onPressed: loading ? null : _toggleMode,
          child: Text(
            _isSignUp
                ? (localizations?.login ?? "Login")
                : (localizations?.signUp ?? "Sign up"),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
