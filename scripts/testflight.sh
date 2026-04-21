#!/usr/bin/env bash
# One-shot: regenerate project, Release archive, upload to TestFlight (local Xcode account).
#
#   ./scripts/testflight.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> xcodegen"
command -v xcodegen >/dev/null && xcodegen generate || { echo "Install xcodegen: brew install xcodegen" >&2; exit 1; }

ARCHIVE="$ROOT/build/FitnessStreaks.xcarchive"
rm -rf "$ARCHIVE"

echo "==> Archive (Release)"
xcodebuild -project FitnessStreaks.xcodeproj \
  -scheme FitnessStreaks \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  archive

exec "$ROOT/scripts/upload-testflight.sh" "$ARCHIVE"
