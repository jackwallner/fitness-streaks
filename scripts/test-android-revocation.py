#!/usr/bin/env python3
"""Verify core permission revocation clears cached health after process death."""
from __future__ import annotations

import datetime
import json
import runpy
import shlex
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    helper = runpy.run_path(str(root / 'scripts/capture-android-pro.py'))
    adb, wait_for = helper['adb'], helper['wait_for']
    package = helper['PACKAGE']
    helper['PROOF'].mkdir(parents=True, exist_ok=True)
    assert adb('emu', 'avd', 'name').decode().splitlines()[0] == 'sol-streaks'
    if not adb('shell', 'pm', 'path', package).strip():
        adb('install', '-r', '/Users/jackwallner/tmp/sol-streaks/android/app/build/outputs/apk/debug/app-debug.apk')
    adb('shell', 'am', 'force-stop', package)
    for kind in ['EXERCISE', 'HEART_RATE', 'SLEEP', 'ACTIVE_CALORIES_BURNED', 'DISTANCE', 'FLOORS_CLIMBED', 'MINDFULNESS', 'HEALTH_DATA_HISTORY', 'HEALTH_DATA_IN_BACKGROUND']:
        command = shlex.join([helper['ADB'], '-s', helper['SERIAL'], 'shell', 'pm', 'revoke', package, 'android.permission.health.READ_' + kind])
        subprocess.run(['ssh', helper['HOST'], command], capture_output=True)
    adb('shell', 'pm', 'grant', package, 'android.permission.health.READ_STEPS')
    today = datetime.date.fromisoformat(adb('shell', 'date', '+%F').decode().strip())
    history = [{'date': str(today - datetime.timedelta(days=offset)), 'values': {'steps': 0 if offset == 0 else 5000}, 'workouts': {}} for offset in reversed(range(7))]
    values = {'hasCompletedSetup': 'true', 'healthCache': json.dumps(history), 'healthGranted': json.dumps(['android.permission.health.READ_STEPS']), 'trackedStreaks': json.dumps(['steps-daily']), 'committedThresholds': json.dumps({'steps-daily': 5000}), 'appearance': '0'}
    tree = ET.Element('map')
    for key, value in values.items():
        ET.SubElement(tree, 'string', name=key).text = value
    adb('shell', 'run-as', package, 'mkdir', '-p', 'shared_prefs')
    command = shlex.join([helper['ADB'], '-s', helper['SERIAL'], 'shell', 'run-as', package, 'tee', 'shared_prefs/streaks.xml'])
    subprocess.run(['ssh', helper['HOST'], command], input=ET.tostring(tree, encoding='utf-8', xml_declaration=True), capture_output=True, check=True)
    adb('shell', 'am', 'start', '-W', '-f', '0x10008000', '-n', f'{package}/.MainActivity', '--ez', 'uiTest', 'true')
    wait_for('YOUR HERO · STEPS')
    helper['capture']('revoke-01-cached-run.png')
    adb('shell', 'pm', 'revoke', package, 'android.permission.health.READ_STEPS')
    adb('shell', 'am', 'start', '-W', '-f', '0x10008000', '-n', f'{package}/.MainActivity', '--ez', 'uiTest', 'true')
    wait_for('NO ACTIVE STREAKS')
    helper['capture']('revoke-02-cleared.png')
    prefs = ET.fromstring(adb('shell', 'run-as', package, 'cat', 'shared_prefs/streaks.xml'))
    saved = {node.get('name'): node.text for node in prefs}
    assert json.loads(saved.get('healthCache', '[]')) == []
    assert json.loads(saved.get('lastKnownStreakLengths', '{}')) == {}
    print('External READ_STEPS revocation killed the app; restart removed cached activity, derived streaks and persisted health history', flush=True)


if __name__ == '__main__':
    main()
