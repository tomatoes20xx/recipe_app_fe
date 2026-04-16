#!/usr/bin/env bash
# Run app against PRODUCTION environment
# Uses: recipeappbe-production-4692.up.railway.app

set -e

API_URL="https://recipeappbe-production-4692.up.railway.app"

echo "========================================"
echo "  PRODUCTION RUN"
echo "  API: $API_URL"
echo "========================================"

flutter run --dart-define=API_BASE_URL=$API_URL
