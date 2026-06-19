#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Building Android App Bundle for Play Store..."
flutter pub get
flutter build appbundle --release

echo ""
echo "Done. Upload this file to Google Play Console:"
echo "  build/app/outputs/bundle/release/app-release.aab"
