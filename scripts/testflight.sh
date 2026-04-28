#!/usr/bin/env bash
# One-shot: regenerate project, Release archive, upload to TestFlight (local Xcode account).
#
#   ./scripts/testflight.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Bump build version"
OLD_VERSION=$(grep 'CURRENT_PROJECT_VERSION:' project.yml | sed 's/.*: //')
NEW_VERSION=$((OLD_VERSION + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION: ${OLD_VERSION}/CURRENT_PROJECT_VERSION: ${NEW_VERSION}/" project.yml
echo "   ${OLD_VERSION} -> ${NEW_VERSION}"

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
