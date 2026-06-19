#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Building iOS release (no codesign)..."
flutter pub get
flutter build ipa --release --no-codesign

echo ""
echo "Open ios/Runner.xcworkspace in Xcode to archive and upload to App Store Connect."
