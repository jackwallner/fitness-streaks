"""Native locale helpers for Astro sync / prune / tier-1 (Streak Finder)."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"
STORES_JSON = Path(__file__).parent / "astro-stores-2026.json"

LOCALE_TO_STORE: dict[str, str] = {
    "ar-SA": "sa",
    "ca": "es",
    "cs": "cz",
    "da": "dk",
    "de-DE": "de",
    "el": "gr",
    "en-AU": "au",
    "en-CA": "ca",
    "en-GB": "gb",
    "en-US": "us",
    "es-ES": "es",
    "es-MX": "mx",
    "fi": "fi",
    "fr-CA": "ca",
    "fr-FR": "fr",
    "he": "il",
    "hi": "in",
    "hr": "hr",
    "hu": "hu",
    "id": "id",
    "it": "it",
    "ja": "jp",
    "ko": "kr",
    "ms": "my",
    "nl-NL": "nl",
    "no": "no",
    "pl": "pl",
    "pt-BR": "br",
    "pt-PT": "pt",
    "ro": "ro",
    "ru": "ru",
    "sk": "sk",
    "sv": "se",
    "th": "th",
    "tr": "tr",
    "uk": "ua",
    "vi": "vn",
    "zh-Hans": "cn",
    "zh-Hant": "tw",
}

# Astro stores where English metadata is primary
ENGLISH_ASTRO_STORES = frozenset(
    {"us", "gb", "au", "ie", "nz", "sg", "ph", "za", "ng", "ke", "gh", "eg", "pk"}
)
# ca: bilingual en-CA + fr-CA handled in locale_dirs_for_store

# Universal Latin tokens allowed on non-English storefronts
LATIN_ALLOWLIST = frozenset(
    {
        "healthkit",
        "mindfulness",
        "heatmap",
        "badge",
        "move",
        "log",
        "pro",
        "ios",
        "apple",
        "watch",
        "widget",
    }
)

HEADACHE_PATTERNS = re.compile(
    r"headache|migraine|migräne|migraña|kopfschmerz|cefalea|emicrania|hoofdpijn|"
    r"hoofdpijn|huvudvärk|hodepine|صداع|شقيقة|頭痛|片頭痛|두통|편두통|偏頭痛|"
    r"боль|мигрень|migren",
    re.I,
)

# Native suggestion seeds per tier-1 Astro store
TIER1_SEEDS: dict[str, tuple[str, ...]] = {
    "us": ("habit streak", "streak tracker", "fitness habits", "activity rings", "apple health"),
    "gb": ("habit streak", "streak tracker", "fitness habits", "activity rings", "apple health"),
    "ca": ("habit streak", "suivi habitudes", "activity rings", "apple health"),
    "au": ("habit streak", "streak tracker", "fitness habits", "activity rings"),
    "de": ("fitness gewohnheiten", "aktivitätsringe", "streak tracker", "apple health", "schritte"),
    "fr": ("suivi habitudes", "anneaux activité", "série fitness", "apple health"),
    "es": ("racha fitness", "hábitos salud", "anillos actividad", "apple health"),
    "mx": ("racha fitness", "hábitos salud", "anillos actividad"),
    "br": ("sequência fitness", "hábitos saúde", "anel atividade", "apple health"),
    "it": ("abitudini fitness", "anello attività", "serie fitness", "apple health"),
    "nl": ("fitness gewoonte", "activiteiten ringen", "streak tracker", "apple health"),
    "jp": ("フィットネス 習慣", "連続記録", "アクティビティリング", "ヘルスケア"),
    "kr": ("피트니스 습관", "연속 기록", "활동 링", "건강"),
    "cn": ("健身 习惯", "连续 记录", "活动 圆环", "健康"),
    "tw": ("健身 習慣", "連續 記錄", "活動 圓環", "健康"),
}

DEFAULT_SEEDS = ("habit streak", "streak tracker", "fitness streak", "activity rings")


def load_store_entry(code: str) -> dict | None:
    for s in json.loads(STORES_JSON.read_text())["stores"]:
        if s["code"] == code:
            return s
    return None


def locale_dirs_for_store(store_code: str, store_entry: dict | None = None) -> list[Path]:
    """Primary native fastlane locale(s) per Astro store — no en-US bleed on de/fr/jp/etc."""
    entry = store_entry or load_store_entry(store_code)
    if not entry:
        return []

    ordered: list[str] = []
    for locale, mapped in LOCALE_TO_STORE.items():
        if mapped == store_code and locale not in ordered:
            ordered.append(locale)
    for locale in entry.get("fallbackLocales", []):
        if locale not in ordered:
            ordered.append(locale)

    dirs = [META / loc for loc in ordered if (META / loc).is_dir()]
    if not dirs:
        return []

    if store_code in ENGLISH_ASTRO_STORES:
        en = [d for d in dirs if d.name.startswith("en-")]
        return en if en else dirs[:1]

    native = [d for d in dirs if not d.name.startswith("en-")]
    if native:
        # Bilingual Canada: fr-CA + en-CA
        if store_code == "ca":
            en_ca = META / "en-CA"
            if en_ca.is_dir() and en_ca not in native:
                native.append(en_ca)
        return native

    return dirs[:1]


def primary_locale_names(store_code: str) -> list[str]:
    return [d.name for d in locale_dirs_for_store(store_code)]


def is_cjk(text: str) -> bool:
    return bool(re.search(r"[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]", text))


def is_headache_junk(keyword: str) -> bool:
    return bool(HEADACHE_PATTERNS.search(keyword))


def is_wrong_script(keyword: str, store: str) -> bool:
    kw = keyword.strip()
    if not kw:
        return True
    ar_stores = {"sa", "ae", "eg", "kw", "qa", "om", "bh", "jo", "lb", "iq", "dz", "ma"}
    cjk_stores = {"jp", "kr", "cn", "tw", "hk", "mo"}
    cyr_stores = {"ru", "ua", "kz", "kg", "uz", "by", "am", "az"}

    if re.search(r"[\u0600-\u06ff]", kw) and store not in ar_stores:
        return True
    if is_cjk(kw) and store not in cjk_stores:
        return True
    if re.search(r"[\u0400-\u04ff]", kw) and store not in cyr_stores:
        return True
    return False


def is_english_bleed(keyword: str, store: str) -> bool:
    """Latin English on a non-English-primary storefront."""
    if store in ENGLISH_ASTRO_STORES:
        return False
    kw = keyword.lower().strip()
    if kw in LATIN_ALLOWLIST:
        return False
    if is_cjk(kw) or re.search(r"[\u0600-\u06ff\u0400-\u04ff]", kw):
        return False
    # Pure ASCII Latin token(s)
    if re.match(r"^[a-z0-9][a-z0-9\s\-']*$", kw):
        # Short tech terms often OK
        if kw in LATIN_ALLOWLIST or len(kw) <= 4:
            return False
        return True
    return False


def should_prune(keyword: str, store: str) -> bool:
    if is_headache_junk(keyword):
        return True
    if is_wrong_script(keyword, store):
        return True
    if is_english_bleed(keyword, store):
        return True
    return False


def seeds_for_store(store: str) -> list[str]:
    return list(TIER1_SEEDS.get(store, DEFAULT_SEEDS))
