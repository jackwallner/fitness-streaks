#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRO_HOST=jackwallner@192.168.4.25
rsync -az --delete --exclude build --exclude .gradle --exclude .kotlin --exclude local.properties --exclude verification --exclude captures --exclude '*.p12' --exclude '*.jks' --exclude '*.keystore' "$REPO_DIR/android/" "$PRO_HOST:tmp/sol-streaks/android/"
python3 - "$REPO_DIR/android/local.properties" <<'PY' | ssh "$PRO_HOST" 'umask 077; cat > "$HOME/tmp/sol-streaks/android/local.properties"'
from pathlib import Path
import sys
properties=dict(line.split('=',1)for line in Path(sys.argv[1]).read_text().splitlines()if'='in line)
print('sdk.dir=/Users/jackwallner/Library/Android/sdk')
print('REVENUECAT_TEST_KEY='+properties['REVENUECAT_TEST_KEY'])
PY
ssh "$PRO_HOST" 'bash -s' <<'REMOTE'
set -euo pipefail
export JAVA_HOME="$HOME/.jdk/jdk-21.0.12.1+1/Contents/Home"
export PATH="$JAVA_HOME/bin:$HOME/Library/Android/sdk/platform-tools:$PATH"
export ANDROID_SERIAL=emulator-5584
AVD_NAME=$(adb -s "$ANDROID_SERIAL" emu avd name </dev/null | tr -d '\r' | head -1)
test "$AVD_NAME" = sol-streaks
test "$(adb -s "$ANDROID_SERIAL" shell -n getprop sys.boot_completed | tr -d '\r')" = 1
cd "$HOME/tmp/sol-streaks/android"
./gradlew testDebugUnitTest connectedDebugAndroidTest --no-daemon --max-workers=1 -Dorg.gradle.jvmargs=-Xmx1536m
python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET
for folder,minimum in [('app/build/test-results/testDebugUnitTest',1207),('app/build/outputs/androidTest-results/connected/debug',20)]:
 files=list(Path(folder).rglob('TEST-*.xml'))
 suites=[ET.parse(file).getroot()for file in files]
 count=sum(int(s.attrib.get('tests',0))for s in suites)
 failures=sum(int(s.attrib.get(k,0))for s in suites for k in ['failures','errors','skipped'])
 assert count>=minimum and failures==0,(folder,count,failures)
 print(f'{folder}: {count} tests passed, zero skipped')
PY
REMOTE
mkdir -p "$REPO_DIR/android/verification"
rsync -az "$PRO_HOST:tmp/sol-streaks/android/app/build/outputs/androidTest-results/" "$REPO_DIR/android/verification/device-results/"
rsync -az "$PRO_HOST:tmp/sol-streaks/android/app/build/test-results/" "$REPO_DIR/android/verification/jvm-results/"
