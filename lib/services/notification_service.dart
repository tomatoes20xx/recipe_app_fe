import "dart:async";
import "dart:convert";
import "dart:io";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "../analytics/analytics_service.dart";

/// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message here
}

/// Service for handling Firebase Cloud Messaging and local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Callback when notification is tapped. Receives the full FCM data map.
  Function(Map<String, String?>)? onNotificationTap;

  /// Stored when a notification is tapped before the handler is registered
  /// (e.g. app launched cold from a notification).
  Map<String, String?>? _pendingTap;
  Map<String, String?>? get pendingTap => _pendingTap;
  void clearPendingTap() => _pendingTap = null;

  /// Callback when a badge-count data message arrives (foreground)
  Function(int)? onBadgeCountUpdate;

  /// Initialize notification service
  Future<void> initialize() async {
    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token (may be null on iOS before permissions are granted)
    try {
      _fcmToken = await _firebaseMessaging.getToken();
    } catch (_) {}
    debugPrint('FCM TOKEN: $_fcmToken');

    // Keep local token in sync on refresh
    _firebaseMessaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      debugPrint('FCM TOKEN (refresh): $token');
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Request notification permissions (iOS and Android 13+) and refresh FCM token.
  /// Call this from the soft-prompt sheet when the user taps "Allow".
  Future<void> requestPermission() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    // On iOS the APNS token is registered asynchronously after permission is
    // granted. Poll briefly so getToken() doesn't throw apns-token-not-set.
    if (Platform.isIOS) {
      String? apnsToken;
      for (int i = 0; i < 10 && apnsToken == null; i++) {
        if (i > 0) await Future.delayed(const Duration(milliseconds: 500));
        apnsToken = await _firebaseMessaging.getAPNSToken();
      }
    }
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('FCM TOKEN (after permission): $_fcmToken');
    } catch (_) {
      // APNS token still not ready; onTokenRefresh will update _fcmToken when it arrives.
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload == null) return;
        try {
          final data = (jsonDecode(details.payload!) as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, v?.toString()));
          if (onNotificationTap != null) {
            onNotificationTap!.call(data);
          } else {
            _pendingTap = data;
          }
        } catch (_) {}
      },
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'yummy_notifications', // id
        'Yummy Notifications', // name
        description: 'Notifications for recipe updates, likes, comments, and more',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    AnalyticsService().logPushReceived(
      channel: data['channel']?.toString(),
      type: data['type']?.toString(),
    );

    // Data-only message — update badge count silently, no OS notification
    if (notification == null) {
      if (data['type'] == 'notification_badge') {
        final count = int.tryParse(data['count'] ?? '') ?? 0;
        onBadgeCountUpdate?.call(count);
      }
      return;
    }

    // Show local notification when app is in foreground
    await _showLocalNotification(
      title: notification.title ?? 'Yummy',
      body: notification.body ?? '',
      payload: jsonEncode(data),
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    final rawData = message.data;

    AnalyticsService().logPushOpened(
      channel: rawData['channel']?.toString(),
      type: rawData['type']?.toString(),
    );

    final data = rawData.map((k, v) => MapEntry(k, v.toString()));

    if (onNotificationTap != null) {
      onNotificationTap!.call(data);
    } else {
      _pendingTap = data;
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'yummy_notifications',
      'Yummy Notifications',
      channelDescription: 'Notifications for recipe updates, likes, comments, and more',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }
}
