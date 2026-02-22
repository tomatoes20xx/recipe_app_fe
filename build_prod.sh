#!/usr/bin/env bash
# Build script for PRODUCTION environment
# Uses: recipeappbe-production-4692.up.railway.app
#
# Usage:
#   ./build_prod.sh           → Android APK (default)
#   ./build_prod.sh apk       → Android APK
#   ./build_prod.sh aab       → Android App Bundle (Play Store)
#   ./build_prod.sh ipa       → iOS IPA (App Store)

set -e

PLATFORM="${1:-apk}"
API_URL="https://recipeappbe-production-4692.up.railway.app"
DEFINES="--dart-define=API_BASE_URL=$API_URL"

echo "========================================"
echo "  PRODUCTION BUILD"
echo "  API: $API_URL"
echo "  Target: $PLATFORM"
echo "========================================"

case "$PLATFORM" in
  apk)
    flutter build apk --release $DEFINES
    echo ""
    echo "Output: build/app/outputs/flutter-apk/app-release.apk"
    ;;
  aab)
    flutter build appbundle --release $DEFINES
    echo ""
    echo "Output: build/app/outputs/bundle/release/app-release.aab"
    ;;
  ipa)
    flutter build ipa --release $DEFINES
    echo ""
    echo "Output: build/ios/ipa/"
    ;;
  *)
    echo "Unknown platform: $PLATFORM"
    echo "Use: apk | aab | ipa"
    exit 1
    ;;
esac

echo ""
echo "Done!"
