#!/usr/bin/env python3
"""Compile the original Swift engine and export Android reference cases."""
import os
import subprocess
import tempfile
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='streaks-parity-') as temporary:
        directory = Path(temporary)
        settings = (root / 'Shared/Services/StreakSettings.swift').read_text()
        prefix = settings[:settings.index('@MainActor')].replace('import WidgetKit', '').replace('import SwiftUI', '')
        prefix = prefix[:prefix.index('enum AppAppearance:')] + prefix[prefix.index('struct StreakSnapshot:'):]
        metric = (root / 'Shared/Models/StreakMetric.swift').read_text().replace('import SwiftUI', '')
        metric = metric[:metric.index('    var accent: Color')] + metric[metric.index('    /// Weight for ranking'):]
        (directory / 'Metric.swift').write_text(metric)
        grace = settings[settings.index('struct GracePreservation:'):settings.index('enum SnapshotStore')]
        shim = '''enum StreakSettings {
        static func streakKey(metric: StreakMetric, cadence: StreakCadence, window: HourWindow? = nil) -> String {
            if let w = window { return "\\(metric.rawValue)-\\(cadence.rawValue)-h\\(w.startHour)" }
            return "\\(metric.rawValue)-\\(cadence.rawValue)"
        }}'''
        (directory / 'Settings.swift').write_text(prefix + grace + shim)
        (directory / 'main.swift').write_text((root / 'scripts/export-android-parity.swift').read_text())
        sources = ['Shared/Utilities/DateHelpers.swift', 'Shared/Models/WorkoutType.swift', 'Shared/Models/Streak.swift', 'Shared/Services/StreakEngine.swift']
        binary = directory / 'parity'
        subprocess.run(['swiftc', *[str(root / name) for name in sources], str(directory / 'Settings.swift'), str(directory / 'Metric.swift'), str(directory / 'main.swift'), '-o', str(binary)], check=True)
        subprocess.run([str(binary), str(root / 'android/app/src/test/resources/swift-parity.json'), str(root / 'android/app/src/main/resources/catalog.json')], check=True, env={**os.environ, 'TZ': 'America/Los_Angeles'})


if __name__ == '__main__':
    main()
