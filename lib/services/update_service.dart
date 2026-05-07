import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  /// Checks for an available update and prompts the user.
  ///
  /// Android: uses the Google Play In-App Update API.
  /// iOS: hits the iTunes lookup API, compares versions, shows a dialog.
  ///
  /// Pass [context] for iOS (required to show the dialog). Silently swallows
  /// all errors so a store issue never blocks the app.
  static Future<void> checkForUpdate({
    bool forceImmediate = false,
    BuildContext? context,
  }) async {
    if (Platform.isAndroid) {
      await _checkAndroid(forceImmediate: forceImmediate);
    } else if (Platform.isIOS && context != null) {
      await _checkIOS(context);
    }
  }

  static Future<void> _checkAndroid({bool forceImmediate = false}) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      if (forceImmediate) {
        await InAppUpdate.performImmediateUpdate();
      } else {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (_) {}
  }

  static Future<void> _checkIOS(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await http
          .get(Uri.parse(
              'https://itunes.apple.com/lookup?bundleId=${packageInfo.packageName}'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return;

      final entry = results[0] as Map<String, dynamic>;
      final storeVersion = entry['version'] as String?;
      final trackId = entry['trackId'];
      if (storeVersion == null) return;
      if (!_isNewer(storeVersion, packageInfo.version)) return;
      if (!context.mounted) return;

      final storeUrl = trackId != null
          ? 'https://apps.apple.com/app/id$trackId'
          : 'https://apps.apple.com/app/${packageInfo.packageName}';

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Update Available'),
          content: Text(
              'Version $storeVersion is available. Please update the app to continue.'),
          actions: [
            TextButton(
              onPressed: () =>
                  launchUrl(Uri.parse(storeUrl), mode: LaunchMode.externalApplication),
              child: const Text('Update'),
            ),
          ],
        ),
      );
    } catch (_) {}
  }

  static bool _isNewer(String storeVersion, String currentVersion) {
    final store = storeVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final current = currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = store.length > current.length ? store.length : current.length;
    for (int i = 0; i < len; i++) {
      final s = i < store.length ? store[i] : 0;
      final c = i < current.length ? current[i] : 0;
      if (s > c) return true;
      if (s < c) return false;
    }
    return false;
  }
}
