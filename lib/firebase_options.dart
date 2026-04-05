// This file is a placeholder. You need to generate it using FlutterFire CLI.
// Run the following commands:
// 1. Install FlutterFire CLI: dart pub global activate flutterfire_cli
// 2. Configure Firebase: flutterfire configure
//
// The flutterfire configure command will:
// - Create/select a Firebase project
// - Register your app with Firebase
// - Download google-services.json (Android) and GoogleService-Info.plist (iOS)
// - Generate this file with the correct configuration

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDDPC_VugrePkb_M3tRFTlX7yGE4P-Gri4',
    appId: '1:31640311657:android:5f74d28cb1aa41b7f38ff8',
    messagingSenderId: '31640311657',
    projectId: 'yummy-edd7e',
    storageBucket: 'yummy-edd7e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBJIB3U3FgI5yhNbRj19k1KIJ5uSI3AyWw',
    appId: '1:31640311657:ios:00339219cb94f822f38ff8',
    messagingSenderId: '31640311657',
    projectId: 'yummy-edd7e',
    storageBucket: 'yummy-edd7e.firebasestorage.app',
    androidClientId: '31640311657-m13kjin2bkgkv93rldgg0ns2titln22f.apps.googleusercontent.com',
    iosClientId: '31640311657-m9hij53r5o802ipotb3edkcd7kqqsjt2.apps.googleusercontent.com',
    iosBundleId: 'com.tomakatcheishvili.yummy',
  );

}