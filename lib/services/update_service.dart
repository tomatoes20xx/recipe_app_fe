import 'dart:io' show Platform;

import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  /// Checks Google Play for an available update and starts the flow.
  ///
  /// Uses **immediate** mode when [forceImmediate] is true (blocks the UI
  /// until the update is installed — useful for breaking releases).
  /// Otherwise uses **flexible** mode (download in background, prompt to
  /// install when ready).
  ///
  /// Silently swallows all errors so a Play Store issue never blocks the app.
  static Future<void> checkForUpdate({bool forceImmediate = false}) async {
    if (!Platform.isAndroid) return;

    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      if (forceImmediate) {
        await InAppUpdate.performImmediateUpdate();
      } else {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (_) {
      // Ignore — Play Store may be unavailable (side-loaded APK, emulator, etc.)
    }
  }
}
