#!/usr/bin/env bash
# Build script for TEST environment
# Uses: recipeappbe-testing.up.railway.app
#
# Usage:
#   ./build_test.sh           → Android APK (default)
#   ./build_test.sh apk       → Android APK
#   ./build_test.sh aab       → Android App Bundle
#   ./build_test.sh ipa       → iOS IPA
#   ./build_test.sh run       → Run on connected device

set -e

PLATFORM="${1:-apk}"
API_URL="https://recipeappbe-testing.up.railway.app"
DEFINES="--dart-define=API_BASE_URL=$API_URL"

echo "========================================"
echo "  TEST BUILD"
echo "  API: $API_URL"
echo "  Target: $PLATFORM"
echo "========================================"

case "$PLATFORM" in
  apk)
    flutter build apk --debug $DEFINES
    echo ""
    echo "Output: build/app/outputs/flutter-apk/app-debug.apk"
    ;;
  aab)
    flutter build appbundle $DEFINES
    echo ""
    echo "Output: build/app/outputs/bundle/debug/"
    ;;
  ipa)
    flutter build ipa $DEFINES
    echo ""
    echo "Output: build/ios/ipa/"
    ;;
  run)
    flutter run $DEFINES
    ;;
  *)
    echo "Unknown platform: $PLATFORM"
    echo "Use: apk | aab | ipa | run"
    exit 1
    ;;
esac

echo ""
echo "Done!"
