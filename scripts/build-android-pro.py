#!/usr/bin/env python3
"""Compile on Pro, sign with the Air's private upload key, verify on Pro."""
from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOST = 'jackwallner@192.168.4.25'
REMOTE = '/Users/jackwallner/tmp/sol-streaks'


def run(*args: str, **kwargs) -> None:
    subprocess.run(args, check=True, **kwargs)


def remote_python(source: str, public_key: str) -> None:
    run('ssh', HOST, 'python3 -c ' + shlex.quote(source), input=public_key.encode())


def main() -> None:
    properties = dict(line.split('=', 1) for line in (ROOT / 'android/local.properties').read_text().splitlines() if '=' in line)
    play_key = properties['REVENUECAT_PLAY_KEY']
    assert play_key.startswith('goog_')
    print('Syncing sources, excluding signing assets and local configuration', flush=True)
    run('rsync', '-az', '--delete', '--exclude=build', '--exclude=.gradle', '--exclude=.kotlin', '--exclude=local.properties', '--exclude=verification', '--exclude=captures', '--exclude=*.p12', '--exclude=*.jks', '--exclude=*.keystore', str(ROOT / 'android') + '/', f'{HOST}:{REMOTE}/android/')
    run('ssh', HOST, f'mkdir -p {REMOTE}/scripts')
    run('scp', str(ROOT / 'scripts/verify-android-release.py'), f'{HOST}:{REMOTE}/scripts/')
    print('Building release APK/AAB, optimized QA and lint on Pro', flush=True)
    remote_python(f'''
import os, subprocess, sys
from pathlib import Path
env = os.environ.copy()
env['JAVA_HOME'] = str(Path.home()/'.jdk/jdk-21.0.12.1+1/Contents/Home')
env['PATH'] = env['JAVA_HOME']+'/bin:'+env['PATH']
env['REVENUECAT_PLAY_KEY'] = sys.stdin.read()
subprocess.run(['./gradlew','assembleRelease','bundleRelease','assembleQa','lintRelease','-PexternalSigning=true','--no-daemon','--max-workers=1','-Dorg.gradle.jvmargs=-Xmx1536m'], cwd='{REMOTE}/android', env=env, check=True)
''', play_key)
    outputs = ROOT / 'android/app/build/outputs'
    for kind, variant, filename in [('apk', 'release', 'app-release-unsigned.apk'), ('bundle', 'release', 'app-release.aab'), ('apk', 'qa', 'app-qa.apk')]:
        destination = outputs / kind / variant
        destination.mkdir(parents=True, exist_ok=True)
        run('scp', f'{HOST}:{REMOTE}/android/app/build/outputs/{kind}/{variant}/{filename}', str(destination / filename))
    print('Signing only on Air; private upload key never leaves this machine', flush=True)
    environment = os.environ.copy()
    environment['SOL_STORE_PASSWORD'] = properties['PLAY_UPLOAD_STORE_PASSWORD']
    environment['SOL_KEY_PASSWORD'] = properties.get('PLAY_UPLOAD_KEY_PASSWORD', environment['SOL_STORE_PASSWORD'])
    environment['JAVA_HOME'] = '/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home'
    tools = Path(properties['sdk.dir']) / 'build-tools/36.0.0'
    apk = outputs / 'apk/release/app-release.apk'
    bundle = outputs / 'bundle/release/app-release.aab'
    run(str(tools / 'apksigner'), 'sign', '--ks', properties['PLAY_UPLOAD_KEYSTORE'], '--ks-key-alias', properties['PLAY_UPLOAD_KEY_ALIAS'], '--ks-pass', 'env:SOL_STORE_PASSWORD', '--key-pass', 'env:SOL_KEY_PASSWORD', '--out', str(apk), str(outputs / 'apk/release/app-release-unsigned.apk'), env=environment)
    run(environment['JAVA_HOME'] + '/bin/jarsigner', '-keystore', properties['PLAY_UPLOAD_KEYSTORE'], '-storepass:env', 'SOL_STORE_PASSWORD', '-keypass:env', 'SOL_KEY_PASSWORD', str(bundle), properties['PLAY_UPLOAD_KEY_ALIAS'], env=environment)
    print('Verifying signatures, manifests, production hooks and 16 KB alignment on Pro', flush=True)
    for path in [apk, bundle]:
        run('scp', str(path), f'{HOST}:{REMOTE}/android/app/build/outputs/{path.relative_to(outputs)}')
    remote_python(f'''
import os, subprocess, sys
from pathlib import Path
env = os.environ.copy()
env['JAVA_HOME'] = str(Path.home()/'.jdk/jdk-21.0.12.1+1/Contents/Home')
env['PATH'] = env['JAVA_HOME']+'/bin:'+env['PATH']
env['REVENUECAT_PLAY_KEY'] = sys.stdin.read()
subprocess.run(['python3','{REMOTE}/scripts/verify-android-release.py','--bundletool','{REMOTE}/bundletool.jar'], env=env, check=True)
''', play_key)
    run('scp', f'{HOST}:{REMOTE}/android/app/build/release-verification.json', str(ROOT / 'android/app/build/release-verification.json'))
    report = json.loads((ROOT / 'android/app/build/release-verification.json').read_text())
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    main()
