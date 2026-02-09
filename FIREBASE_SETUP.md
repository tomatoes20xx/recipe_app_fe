# Firebase Setup Guide

This guide will help you complete the Firebase setup for crashlytics and push notifications.

## Prerequisites

1. A Firebase project (create one at https://console.firebase.google.com)
2. FlutterFire CLI installed globally

## Step 1: Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

## Step 2: Configure Firebase

Run this command in your project directory:

```bash
flutterfire configure
```

This will:
- Connect to your Firebase project (or create a new one)
- Register your Android and iOS apps
- Download configuration files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS)
- Generate `lib/firebase_options.dart` with your project configuration

## Step 3: Enable Firebase Services

In the Firebase Console (https://console.firebase.google.com):

### 3.1 Enable Crashlytics
1. Go to **Crashlytics** in the left sidebar
2. Click **Enable Crashlytics**
3. Follow the setup instructions

### 3.2 Enable Cloud Messaging (Push Notifications)
1. Go to **Cloud Messaging** in the left sidebar
2. No additional setup needed - it's enabled by default

### 3.3 Get Server Key (for backend)
1. Go to **Project Settings** (gear icon) > **Cloud Messaging**
2. Under **Cloud Messaging API (Legacy)**, copy the **Server Key**
3. You'll need this in your backend to send push notifications

## Step 4: Update Android Configuration

1. The `google-services.json` file should be automatically placed in `android/app/`
2. If not, download it from Firebase Console and place it there

Add this to `android/build.gradle` (if not already present):

```gradle
buildscript {
    dependencies {
        // Add this line
        classpath 'com.google.gms:google-services:4.4.2'
    }
}
```

Add this to `android/app/build.gradle`:

```gradle
apply plugin: 'com.google.gms.google-services'
```

## Step 5: Update iOS Configuration

1. The `GoogleService-Info.plist` should be placed in `ios/Runner/`
2. Open `ios/Runner.xcworkspace` in Xcode
3. Right-click on `Runner` folder and select "Add Files to Runner"
4. Select `GoogleService-Info.plist`
5. Make sure "Copy items if needed" is checked

## Step 6: Test the Setup

### Test Crashlytics
Add this test code temporarily in your app:

```dart
// Force a crash to test
FirebaseCrashlytics.instance.crash();
```

Check the Firebase Console > Crashlytics after a few minutes.

### Test Push Notifications

1. Get your FCM token by checking the debug console when the app starts
2. Use Firebase Console > Cloud Messaging to send a test notification:
   - Click "Send your first message"
   - Enter a notification title and text
   - Click "Send test message"
   - Paste your FCM token
   - Click "Test"

## Step 7: Backend Integration

### Send FCM Token to Backend
When a user logs in, send their FCM token to your backend:

```dart
final token = NotificationService().fcmToken;
// Send to your API
await apiClient.post('/api/users/register-fcm-token', body: {'fcmToken': token});
```

### Backend: Send Push Notifications

Use the Firebase Admin SDK or HTTP API to send notifications from your backend:

```javascript
// Node.js example with Firebase Admin SDK
const admin = require('firebase-admin');

await admin.messaging().send({
  token: userFcmToken,
  notification: {
    title: 'New Recipe!',
    body: 'Someone shared a new recipe',
  },
  data: {
    route: 'recipe',
    recipe_id: '12345',
  },
});
```

## Notification Types

The app is configured to handle these notification types:

- **Recipe notifications**: Include `recipe_id` in data payload
- **User notifications**: Include `user_id` in data payload
- **Custom routes**: Include `route` in data payload

Example payload:
```json
{
  "notification": {
    "title": "New Comment",
    "body": "Someone commented on your recipe"
  },
  "data": {
    "route": "recipe",
    "recipe_id": "12345"
  }
}
```

## Troubleshooting

### Android: Push notifications not received
- Ensure Google Play Services is installed on the device
- Check that the app has notification permissions
- Verify `google-services.json` is in the correct location

### iOS: Push notifications not received
- Ensure you have an Apple Developer account
- Configure APNs in Firebase Console (Project Settings > Cloud Messaging > iOS app)
- Upload your APNs authentication key or certificate

### Crashlytics not showing crashes
- Wait a few minutes (can take 5-10 minutes for first crash to appear)
- Ensure you've built a release build at least once
- Check that Crashlytics is enabled in Firebase Console

## Additional Resources

- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Crashlytics Docs](https://firebase.google.com/docs/crashlytics)
- [Firebase Cloud Messaging Docs](https://firebase.google.com/docs/cloud-messaging)
