#!/usr/bin/env python3
"""Validate Google Play listing copy under android/play-assets/metadata/android.

Checks every locale folder for Play's limits (title 30, short 80, full 4000),
the house rules (no em dashes, no prices, no Apple wording, no promo words in
the title) and the required closing lines. Exit 1 on any failure.

Usage: scripts/validate-play-listing.py
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "play-assets/metadata/android"
EXPECTED_LOCALES = 50
# Closing line each non-English listing must end with: the app itself is in English.
ENGLISH_NOTE = {
    "de-DE": "Die App selbst ist auf Englisch.",
    "fr-FR": "L'application elle-même est en anglais.",
    "es-ES": "La app está en inglés.",
    "es-419": "La app está en inglés.",
    "pt-BR": "O app em si está em inglês.",
    "pt-PT": "A própria aplicação está em inglês.",
    "it-IT": "L'app è in inglese.",
    "nl-NL": "De app zelf is in het Engels.",
    "sv-SE": "Själva appen är på engelska.",
    "no-NO": "Selve appen er på engelsk.",
    "da-DK": "Selve appen er på engelsk.",
    "fi-FI": "Itse sovellus on englanniksi.",
    "pl-PL": "Sama aplikacja jest po angielsku.",
    "cs-CZ": "Samotná aplikace je v angličtině.",
    "sk": "Samotná aplikácia je v angličtine.",
    "sl": "Sama aplikacija je v angleščini.",
    "hr": "Sama aplikacija je na engleskom.",
    "hu-HU": "Maga az alkalmazás angol nyelvű.",
    "ro": "Aplicația în sine este în engleză.",
    "ca": "L'aplicació està en anglès.",
    "tr-TR": "Uygulamanın kendisi İngilizcedir.",
    "id": "Aplikasinya sendiri berbahasa Inggris.",
    "ms": "Aplikasi itu sendiri dalam bahasa Inggeris.",
    "vi": "Bản thân ứng dụng bằng tiếng Anh.",
    "ru-RU": "Само приложение на английском языке.",
    "uk": "Сам застосунок англійською мовою.",
    "el-GR": "Η ίδια η εφαρμογή είναι στα αγγλικά.",
    "ar": "التطبيق نفسه باللغة الإنجليزية.",
    "iw-IL": "האפליקציה עצמה באנגלית.",
    "hi-IN": "ऐप खुद अंग्रेज़ी में है।",
    "bn-BD": "অ্যাপটি নিজে ইংরেজিতে।",
    "mr-IN": "अ‍ॅप स्वतः इंग्रजीत आहे.",
    "ta-IN": "செயலி ஆங்கிலத்தில் உள்ளது.",
    "te-IN": "యాప్ ఇంగ్లీష్‌లో ఉంది.",
    "kn-IN": "ಆ್ಯಪ್ ಇಂಗ್ಲಿಷ್‌ನಲ್ಲಿದೆ.",
    "ml-IN": "ആപ്പ് ഇംഗ്ലീഷിലാണ്.",
    "th": "ตัวแอปเป็นภาษาอังกฤษ",
    "ja-JP": "アプリ自体は英語です。",
    "ko-KR": "앱 자체는 영어로 제공됩니다.",
    "zh-CN": "应用本身为英文界面。",
    "zh-TW": "應用程式本身為英文介面。",
    "fr-CA": "L'application elle-même est en anglais.",
    "es-US": "La app está en inglés.",
    "ms-MY": "Aplikasi itu sendiri dalam bahasa Inggeris.",
    "zh-HK": "應用程式本身為英文介面。",
}
LIMITS = {"title.txt": 30, "short_description.txt": 80, "full_description.txt": 4000}
# Play language codes accepted by the Publishing API (fastlane supply list).
PLAY_LANGS = set(
    "af am ar az-AZ be bg bn-BD ca cs-CZ da-DK de-DE el-GR en-AU en-CA en-GB en-IN "
    "en-SG en-US en-ZA es-419 es-ES es-US et eu-ES fa fi-FI fil fr-CA fr-FR gl-ES "
    "hi-IN hr hu-HU hy-AM id is-IS it-IT iw-IL ja-JP ka-GE km-KH kn-IN ko-KR ky-KG "
    "lo-LA lt lv mk-MK ml-IN mn-MN mr-IN ms ms-MY my-MM ne-NP nl-NL no-NO pl-PL "
    "pt-BR pt-PT rm ro ru-RU si-LK sk sl sr sv-SE sw ta-IN te-IN th tr-TR uk vi "
    "zh-CN zh-HK zh-TW zu".split()
)
TITLE_BANNED = re.compile(r"\b(free|best|top|#1|new|sale)\b", re.I)
PRICE = re.compile(r"[$€£¥₹]\s?\d|\d[.,]\d\d\s?(?:€|zł|kr|lei|Kč|₺|₽|₴)")
APPLE = re.compile(r"Apple|App Store|iPhone|iCloud|Apple Watch", re.I)
URL_OK = re.compile(r"https://jackwallner\.github\.io/\S+")


def check(locale_dir: Path) -> list[str]:
    errs: list[str] = []
    loc = locale_dir.name
    if loc not in PLAY_LANGS:
        errs.append(f"unknown Play language code {loc}")
    for name, limit in LIMITS.items():
        p = locale_dir / name
        if not p.exists():
            errs.append(f"missing {name}")
            continue
        text = p.read_text(encoding="utf-8").strip()
        n = len(text)
        if n == 0 or n > limit:
            errs.append(f"{name} {n}/{limit}")
        if "\u2014" in text:
            errs.append(f"{name} has an em dash")
        if re.search("[\u00ad\u200b\ufeff]", text):
            errs.append(f"{name} has an invisible character")
        if PRICE.search(text):
            errs.append(f"{name} looks like it has a price: {PRICE.search(text).group(0)!r}")
        if APPLE.search(URL_OK.sub("", text)):
            errs.append(f"{name} mentions Apple wording: {APPLE.search(text).group(0)!r}")
        if name != "full_description.txt" and "\n" in text:
            errs.append(f"{name} spans lines")
    title = (locale_dir / "title.txt").read_text(encoding="utf-8") if (locale_dir / "title.txt").exists() else ""
    if TITLE_BANNED.search(title):
        errs.append(f"title has a promo word: {title.strip()!r}")
    full = (locale_dir / "full_description.txt").read_text(encoding="utf-8") if (locale_dir / "full_description.txt").exists() else ""
    if "Google Play" not in full:
        errs.append("full description lacks the Google Play billing paragraph")
    if not loc.startswith("en"):
        last = full.strip().split("\n\n")[-1].strip()
        if last != ENGLISH_NOTE.get(loc):
            errs.append("full description does not end with the app-is-in-English line")
    for word in ("Health Connect", "Streaks+"):
        if word not in full:
            errs.append(f"full description lacks {word!r}")
    if re.search(r"\b(cure|treat|diagnos)", full, re.I) and loc.startswith("en"):
        errs.append("full description has a medical claim word")
    return errs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=ROOT)
    args = ap.parse_args()
    bad = 0
    dirs = sorted(d for d in args.root.iterdir() if d.is_dir())
    for d in dirs:
        errs = check(d)
        t = (d / "title.txt").read_text(encoding="utf-8").strip() if (d / "title.txt").exists() else ""
        s = (d / "short_description.txt").read_text(encoding="utf-8").strip() if (d / "short_description.txt").exists() else ""
        f = (d / "full_description.txt").read_text(encoding="utf-8").strip() if (d / "full_description.txt").exists() else ""
        status = "OK " if not errs else "BAD"
        print(f"{status} {d.name:6} t{len(t):>3} s{len(s):>3} f{len(f):>5}  {t}")
        for e in errs:
            print(f"      - {e}")
        bad += bool(errs)
    missing = (set(PLAY_LANGS) & set(ENGLISH_NOTE)) | {"en-US", "en-GB", "en-AU", "en-CA", "en-IN"}
    absent = sorted(missing - {d.name for d in dirs})
    if absent or len(dirs) != EXPECTED_LOCALES:
        print(f"expected {EXPECTED_LOCALES} locales, found {len(dirs)}; missing {absent}")
        bad += 1
    print(f"\n{len(dirs)} locales, {bad} with problems")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
