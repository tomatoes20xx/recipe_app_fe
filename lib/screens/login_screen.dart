import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

import "../api/api_client.dart";
import "../auth/auth_api.dart";
import "../auth/auth_controller.dart";
import "../localization/app_localizations.dart";
import "../services/google_auth_service.dart";
import "../utils/error_utils.dart";
import "forgot_password_screen.dart";
import "signup_screen.dart";
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
  final _googleAuthService = GoogleAuthService();
  final _storage = const FlutterSecureStorage();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Setup entrance animation
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberMe() async {
    try {
      final remembered = await _storage.read(key: 'remember_me');
      if (remembered == 'true') {
        setState(() => _rememberMe = true);
        // Attempt silent Google sign-in if remember me was enabled
        await _attemptSilentGoogleSignIn();
      }
    } catch (e) {
      // Ignore errors loading remember me preference
    }
  }

  Future<void> _saveRememberMePreference() async {
    try {
      if (_rememberMe) {
        await _storage.write(key: 'remember_me', value: 'true');
      } else {
        await _storage.delete(key: 'remember_me');
      }
    } catch (e) {
      // Ignore errors saving preference
    }
  }

  Future<void> _attemptSilentGoogleSignIn() async {
    try {
      final account = await _googleAuthService.signInSilently();
      if (account != null) {
        final idToken = await _googleAuthService.getIdToken(account);
        if (idToken != null) {
          final response = await widget.auth.loginWithGoogle(idToken);

          // Check if username selection is needed
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
          // If existing user, loginWithGoogle already handled everything
        }
      }
    } catch (e) {
      // Silent sign-in failed, user will need to sign in manually
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => error = null);

    try {
      // 1. Sign in with Google (opens account picker)
      final account = await _googleAuthService.signInWithGoogle();
      if (account == null) return; // User cancelled

      // 2. Get ID token
      final idToken = await _googleAuthService.getIdToken(account);
      if (idToken == null) {
        throw Exception("Failed to get ID token");
      }

      // 3. Send to backend
      final response = await widget.auth.loginWithGoogle(idToken);

      // 4. Check if username selection is needed
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
        // Existing user - login complete, save remember me preference
        await _saveRememberMePreference();
        // Navigation handled by AuthGate (watches authController)
      }
    } on ApiException catch (e) {
      setState(() => error = e.message);
      if (mounted) {
        ErrorUtils.showError(context, e);
      }
    } catch (e) {
      const errorMessage = "Google Sign-In failed. Please try again.";
      setState(() => error = errorMessage);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ErrorUtils.showError(context, localizations?.googleSignInFailed ?? errorMessage);
      }
    }
  }

  Future<void> _handleEmailLogin() async {
    setState(() => error = null);

    try {
      await widget.auth.login(_emailController.text.trim(), _passwordController.text);
      await _saveRememberMePreference();
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        if (!mounted) return;
        final localizations = AppLocalizations.of(context);
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(localizations?.accountPermanentlyBanned ?? "Account Permanently Suspended"),
            content: Text(localizations?.accountPermanentlyBannedMessage ?? "Your account has been permanently suspended due to repeated violations of our community guidelines."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(localizations?.ok ?? "OK"),
              ),
            ],
          ),
        );
        return;
      }
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = "Something went wrong.");
    }
  }

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
                  const SizedBox(height: 40),
                  _buildGoogleButton(theme, localizations, loading),
                  const SizedBox(height: 20),
                  _buildDivider(theme, localizations),
                  const SizedBox(height: 20),
                  _buildEmailField(theme, localizations),
                  const SizedBox(height: 16),
                  _buildPasswordField(theme, localizations),
                  const SizedBox(height: 16),
                  _buildHelperRow(theme, localizations),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildLoginButton(theme, localizations, loading),
                  const SizedBox(height: 16),
                  _buildSignUpLink(theme, localizations, loading),
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
        // App Icon
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
              'assets/icon/app_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // App Name
        Text(
          'Yummy',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        // Tagline
        Text(
          localizations?.appTagline ?? 'Your Recipe Journey',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                  'assets/images/google_logo.png',
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if Google logo not available
                    return const Icon(Icons.login, color: Colors.blue, size: 18);
                  },
                ),
              ),
        label: Text(
          localizations?.continueWithGoogle ?? 'Continue with Google',
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
            localizations?.orContinue ?? 'or continue',
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

  Widget _buildEmailField(ThemeData theme, AppLocalizations? localizations) {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(
        labelText: localizations?.email ?? 'Email',
        hintText: localizations?.emailHint ?? 'Enter your email',
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
          Icons.email_outlined,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildPasswordField(ThemeData theme, AppLocalizations? localizations) {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      autofillHints: const [AutofillHints.password],
      decoration: InputDecoration(
        labelText: localizations?.password ?? 'Password',
        hintText: localizations?.passwordHint ?? 'Enter your password',
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
          Icons.lock_outlined,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
          tooltip: _obscurePassword
              ? (localizations?.showPassword ?? 'Show password')
              : (localizations?.hidePassword ?? 'Hide password'),
        ),
      ),
    );
  }

  Widget _buildHelperRow(ThemeData theme, AppLocalizations? localizations) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Remember me checkbox
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              localizations?.rememberMe ?? 'Remember me',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        // Forgot password button
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
            localizations?.forgotPassword ?? 'Forgot password?',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(
      ThemeData theme, AppLocalizations? localizations, bool loading) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : _handleEmailLogin,
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
                localizations?.login ?? 'Login',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildSignUpLink(
      ThemeData theme, AppLocalizations? localizations, bool loading) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          localizations?.dontHaveAccount ?? "Don't have an account?",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        TextButton(
          onPressed: loading
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SignupScreen(auth: widget.auth),
                    ),
                  );
                },
          child: Text(
            localizations?.signUp ?? 'Sign up',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
