import 'dart:io';
import 'package:flutter/material.dart';
import '../../localization/app_localizations.dart';
import '../../notifications/notification_api.dart';
import '../../services/notification_service.dart';

Future<void> showPushPermissionPromptSheet(
  BuildContext context,
  NotificationApi notificationApi,
) async {
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _PushPermissionPromptSheet(notificationApi: notificationApi),
  );
}

class _PushPermissionPromptSheet extends StatelessWidget {
  const _PushPermissionPromptSheet({required this.notificationApi});

  final NotificationApi notificationApi;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('🔔', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              l?.pushPromptTitle ?? 'New Georgian Recipes',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l?.pushPromptDescription ?? 'Enable notifications and never miss new Georgian dishes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await NotificationService().requestPermission();
                  final token = NotificationService().fcmToken;
                  if (token != null) {
                    final platform = Platform.isAndroid ? 'android' : 'ios';
                    notificationApi
                        .registerFcmToken(token, platform)
                        .catchError((_) {});
                  }
                },
                child: Text(l?.pushPromptAllow ?? 'Enable Notifications'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l?.attPermissionSkip ?? 'No thanks'),
            ),
          ],
        ),
      ),
    );
  }
}
