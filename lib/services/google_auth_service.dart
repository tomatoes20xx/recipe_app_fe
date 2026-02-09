import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service class to handle Google Sign-In authentication using v7.x API
class GoogleAuthService {
  // Use the singleton instance
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  StreamSubscription<GoogleSignInAuthenticationEvent>? _authEventsSubscription;
  Completer<GoogleSignInAccount?>? _signInCompleter;

  /// Initialize the Google Sign-In instance
  /// Should be called once at app startup
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? hostedDomain,
  }) async {
    try {
      await _googleSignIn.initialize(
        clientId: clientId,
        serverClientId: serverClientId,
        hostedDomain: hostedDomain,
      );

      // Listen to authentication events
      _authEventsSubscription = _googleSignIn.authenticationEvents.listen(
        _handleAuthenticationEvent,
        onError: _handleAuthenticationError,
      );
    } catch (error) {
      // Ignore initialization errors (may already be initialized)
    }
  }

  void _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    if (_signInCompleter != null && !_signInCompleter!.isCompleted) {
      switch (event) {
        case GoogleSignInAuthenticationEventSignIn():
          _signInCompleter!.complete(event.user);
          break;
        case GoogleSignInAuthenticationEventSignOut():
          _signInCompleter!.complete(null);
          break;
      }
    }
  }

  void _handleAuthenticationError(dynamic error) {
    if (_signInCompleter != null && !_signInCompleter!.isCompleted) {
      _signInCompleter!.completeError(error);
    }
  }

  /// Signs in the user with Google
  /// Returns the GoogleSignInAccount if successful, null if cancelled
  Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      // Check if authenticate is supported on this platform
      if (!_googleSignIn.supportsAuthenticate()) {
        // Fallback: Try lightweight authentication which might show UI
        return await _googleSignIn.attemptLightweightAuthentication();
      }

      // Setup event listener if not already done
      if (_authEventsSubscription == null) {
        _authEventsSubscription = _googleSignIn.authenticationEvents.listen(
          _handleAuthenticationEvent,
          onError: _handleAuthenticationError,
        );
      }

      _signInCompleter = Completer<GoogleSignInAccount?>();

      // Trigger authentication flow with email and profile scopes
      await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      // Wait for the authentication event (with timeout)
      final result = await _signInCompleter!.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => null,
      );

      return result;
    } catch (error) {
      return null;
    } finally {
      _signInCompleter = null;
    }
  }

  /// Gets the ID token from a GoogleSignInAccount
  /// This token is sent to the backend for verification
  Future<String?> getIdToken(GoogleSignInAccount account) async {
    try {
      final auth = account.authentication;
      return auth.idToken;
    } catch (error) {
      return null;
    }
  }

  /// Attempts to sign in silently (without user interaction)
  /// Used for "Remember me" functionality
  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      _signInCompleter = Completer<GoogleSignInAccount?>();

      // Attempt lightweight authentication
      await _googleSignIn.attemptLightweightAuthentication();

      // Wait for the authentication event (with timeout)
      return await _signInCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
    } catch (error) {
      return null;
    } finally {
      _signInCompleter = null;
    }
  }

  /// Signs out the user from Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (error) {
      // Ignore sign out errors
    }
  }

  /// Disconnects the user's Google account
  /// This revokes access permissions (more thorough than signOut)
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } catch (error) {
      // Ignore disconnect errors
    }
  }

  /// Clean up resources
  void dispose() {
    _authEventsSubscription?.cancel();
    _authEventsSubscription = null;
  }
}
