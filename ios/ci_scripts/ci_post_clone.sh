#!/bin/sh
# Xcode Cloud runs this right after cloning. A fresh clone has no Flutter SDK,
# no ios/Flutter/Generated.xcconfig, no Pods, and none of the gitignored
# Firebase configs, so set all of that up before Xcode builds the archive.
#
# Required Xcode Cloud workflow environment variables (mark both Secret):
#   GOOGLE_SERVICE_INFO_PLIST_BASE64  base64 of ios/Runner/GoogleService-Info.plist
#   FIREBASE_OPTIONS_DART_BASE64      base64 of lib/firebase_options.dart

set -e

# Keep in sync with the Flutter SDK used for local builds.
FLUTTER_VERSION="3.44.8"

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Gitignored Firebase configs.
if [ -z "$GOOGLE_SERVICE_INFO_PLIST_BASE64" ] || [ -z "$FIREBASE_OPTIONS_DART_BASE64" ]; then
  echo "error: set GOOGLE_SERVICE_INFO_PLIST_BASE64 and FIREBASE_OPTIONS_DART_BASE64 in the Xcode Cloud workflow" >&2
  exit 1
fi
printf '%s' "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > ios/Runner/GoogleService-Info.plist
printf '%s' "$FIREBASE_OPTIONS_DART_BASE64" | base64 --decode > lib/firebase_options.dart

# Flutter SDK.
git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_VERSION" "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin:$HOME/.pub-cache/bin"
flutter precache --ios
flutter pub get # also writes ios/Flutter/Generated.xcconfig

# The Crashlytics "upload symbols" build phase calls the flutterfire CLI.
dart pub global activate flutterfire_cli

# CocoaPods.
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
cd ios && pod install
