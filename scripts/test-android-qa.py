#!/usr/bin/env python3
"""Check the optimized release path without a production billing key."""
from __future__ import annotations

import runpy
import subprocess
import time
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    helper = runpy.run_path(str(root / 'scripts/capture-android-pro.py'))
    adb, wait_for, click, capture = [helper[key] for key in ['adb', 'wait_for', 'click', 'capture']]
    assert adb('emu', 'avd', 'name').decode().splitlines()[0] == 'sol-streaks'
    helper['PROOF'].mkdir(parents=True, exist_ok=True)
    remote = '/Users/jackwallner/tmp/sol-streaks/app-qa.apk'
    subprocess.run(['scp', str(root / 'android/app/build/outputs/apk/qa/app-qa.apk'), f'{helper["HOST"]}:{remote}'], check=True)
    adb('uninstall', helper['PACKAGE'])
    adb('install', '-r', remote)
    adb('shell', 'am', 'start', '-W', '-f', '0x10008000', '-n', f'{helper["PACKAGE"]}/.MainActivity', '--ez', 'forcePro', 'true', '--ez', 'skipOnboarding', 'true', '--ez', 'seedScreenshotData', 'true', '--es', 'route', 'detail:steps-daily')
    wait_for("YOU'RE ALREADY\nON A STREAK.")
    capture('qa-01-debug-hooks-ignored.png')
    click('▶ GET STARTED')
    helper['scroll_to']('CONTINUE WITHOUT HEALTH')
    click('CONTINUE WITHOUT HEALTH')
    click('▶ CONTINUE')
    wait_for('NO ACTIVE STREAKS')
    capture('qa-02-empty-dashboard.png')
    click('SAVES')
    wait_for('AUTO-SAVE LOCKED')
    capture('qa-03-free-saves.png')
    click('UNLOCK STREAKS+')
    helper['scroll_to']("PRICES DIDN'T LOAD")
    wait_for('PRICES DIDN\'T LOAD')
    capture('qa-04-billing-unavailable.png')
    click('CONTINUE WITH FREE')
    wait_for('AUTO-SAVE LOCKED')
    adb('shell', 'am', 'force-stop', helper['PACKAGE'])
    adb('shell', 'am', 'start', '-W', '-n', f'{helper["PACKAGE"]}/.MainActivity')
    wait_for('NO ACTIVE STREAKS')
    errors = adb('logcat', '-d', '-t', '250', '-s', 'AndroidRuntime:E').decode()
    assert f'Process: {helper["PACKAGE"]}' not in errors, errors
    print('Optimized QA: debug hooks ignored, no fabricated data, free boundary, offline paywall exit and cold-start persistence passed', flush=True)


if __name__ == '__main__':
    main()
