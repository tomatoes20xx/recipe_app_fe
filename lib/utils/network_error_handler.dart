import "dart:async";
import "dart:io";
import "package:flutter/material.dart";

/// Global network error handler that shows a banner when network is unavailable
class NetworkErrorHandler {
  static final NetworkErrorHandler _instance = NetworkErrorHandler._internal();
  factory NetworkErrorHandler() => _instance;
  NetworkErrorHandler._internal();

  OverlayEntry? _overlayEntry;
  Timer? _checkTimer;
  bool _isShowingBanner = false;

  /// Show network error banner
  void showNetworkError(BuildContext context) {
    if (_isShowingBanner) return;

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Container(
            color: Colors.red.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_off,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "No internet connection",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final hasConnection = await checkConnection();
                      if (hasConnection && context.mounted) {
                        hideNetworkError();
                      }
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
    _isShowingBanner = true;

    // Start periodic connection checks
    _startConnectionChecks();
  }

  /// Hide network error banner
  void hideNetworkError() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowingBanner = false;
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Start periodic connection checks
  void _startConnectionChecks() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final hasConnection = await checkConnection();
      if (hasConnection) {
        hideNetworkError();
      }
    });
  }

  /// Check if device has internet connection
  static Future<bool> checkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check for connection and show/hide banner accordingly
  static Future<void> checkAndShowError(BuildContext context) async {
    final hasConnection = await checkConnection();
    if (!hasConnection && context.mounted) {
      NetworkErrorHandler().showNetworkError(context);
    }
  }
}
