#!/usr/bin/env python3
"""Capture native free-tier Streak Finder screens on the owned Pro AVD."""
from __future__ import annotations

import re
import shlex
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOST = 'jackwallner@192.168.4.25'
SERIAL = 'emulator-5584'
ADB = '/Users/jackwallner/Library/Android/sdk/platform-tools/adb'
PACKAGE = 'com.jackwallner.streaks'
PROOF = ROOT / 'android/verification/final'


def adb(*arguments: str) -> bytes:
    return subprocess.run(['ssh', HOST, shlex.join([ADB, '-s', SERIAL, *arguments])], check=True, capture_output=True).stdout


def nodes() -> list:
    adb('shell', 'uiautomator', 'dump', '/sdcard/sol-streaks-capture.xml')
    return list(ET.fromstring(adb('shell', 'cat', '/sdcard/sol-streaks-capture.xml')).iter('node'))


def wait_for(text: str, exact: bool = True) -> ET.Element:
    deadline = time.monotonic() + 60
    while time.monotonic() < deadline:
        for node in nodes():
            value = node.get('text', '')
            if value == text or (not exact and text in value):
                return node
        time.sleep(1)
    raise AssertionError(f'Screen did not settle on {text}')


def click(text: str, exact: bool = True) -> None:
    node = wait_for(text, exact)
    left, top, right, bottom = map(int, re.findall(r'\d+', node.get('bounds', '')))
    adb('shell', 'input', 'tap', str((left + right) // 2), str((top + bottom) // 2))


def scroll_to(text: str, exact: bool = True) -> None:
    for _ in range(12):
        if any(node.get('text', '') == text if exact else text in node.get('text', '') for node in nodes()):
            return
        adb('shell', 'input', 'swipe', '360', '850', '360', '350', '450')
    raise AssertionError(f'Scroll target missing: {text}')


def capture(name: str) -> None:
    time.sleep(1)
    (PROOF / name).write_bytes(adb('exec-out', 'screencap', '-p'))
    print(f'Captured {name}', flush=True)


def launch(route: str | None = None, dark: bool = False) -> None:
    adb('shell', 'am', 'force-stop', PACKAGE)
    arguments = ['shell', 'am', 'start', '-W', '-f', '0x10008000', '-n', f'{PACKAGE}/.MainActivity', '--ez', 'uiTest', 'true', '--ez', 'seedScreenshotData', 'true', '--es', 'appearance', 'dark' if dark else 'light']
    if route:
        arguments += ['--es', 'route', route]
    adb(*arguments)


def main() -> None:
    assert adb('emu', 'avd', 'name').decode().splitlines()[0] == 'sol-streaks'
    PROOF.mkdir(parents=True, exist_ok=True)
    remote = '/Users/jackwallner/tmp/sol-streaks/app-debug-final.apk'
    subprocess.run(['scp', str(ROOT / 'android/app/build/outputs/apk/debug/app-debug.apk'), f'{HOST}:{remote}'], check=True)
    adb('uninstall', PACKAGE)
    adb('install', '-r', remote)
    adb('shell', 'wm', 'size', '720x1440')
    adb('shell', 'wm', 'density', '320')
    adb('shell', 'settings', 'put', 'global', 'sysui_demo_allowed', '1')
    adb('shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo', '--es', 'command', 'enter')
    adb('shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo', '--es', 'command', 'network', '--es', 'wifi', 'show', '--es', 'level', '4', '--es', 'mobile', 'hide', '--es', 'nosim', 'hide')
    for command in [('clock', 'hhmm', '0941'), ('battery', 'level', '100'), ('notifications', 'visible', 'false')]:
        adb('shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo', '--es', 'command', command[0], '--es', command[1], command[2])
    launch()
    wait_for('YOUR HERO · STEPS')
    capture('01-streaks-light.png')
    click('STATS')
    wait_for('3 ACTIVE STREAKS')
    capture('02-stats-light.png')
    launch('detail:steps-daily')
    wait_for('YOUR HERO · STEPS')
    capture('03-detail-light.png')
    launch(dark=True)
    wait_for('YOUR HERO · STEPS')
    capture('04-streaks-dark.png')
    click('SAVES')
    wait_for('AUTO-SAVE LOCKED')
    capture('05-saves-dark.png')
    click('UNLOCK STREAKS+')
    adb('shell', 'input', 'swipe', '360', '850', '360', '350', '500')
    wait_for('YEARLY', exact=False)
    capture('06-paywall-dark.png')
    for index, name in enumerate(['01-streaks-light', '02-stats-light', '03-detail-light', '04-streaks-dark'], 1):
        destination = ROOT / 'play-assets/screenshots' / f'{index:02d}-{name[3:]}.jpg'
        subprocess.run(['sips', '-s', 'format', 'jpeg', str(PROOF / f'{name}.png'), '--out', str(destination)], check=True, stdout=subprocess.DEVNULL)
    print('Captured four native 720x1440 listing images, plus saves and loaded Test Store paywall proof', flush=True)


if __name__ == '__main__':
    main()
