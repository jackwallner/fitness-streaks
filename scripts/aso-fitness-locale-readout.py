#!/usr/bin/env python3
"""Generate full Fitness Habits ASC locale readout + apply fastlane metadata."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"
ASTRO = Path("/tmp/aso_en_pop_fitness_full.json")
if not ASTRO.exists():
    ASTRO = Path("/tmp/aso_en_keyword_pop_checkpoint.json")

import importlib.util

# Import keyword pools from existing optimizer
_apply = Path(__file__).parent / "aso-apply-locale-optimizations.py"
_spec = importlib.util.spec_from_file_location("aso_apply", _apply)
_mod = importlib.util.module_from_spec(_spec)
assert _spec.loader
_spec.loader.exec_module(_mod)
BASE_KW: dict[str, str] = _mod.KEYWORDS

LOCALE_TO_STORE = {
    "ar-SA": "sa", "bn-BD": "in", "ca": "es", "cs": "cz", "da": "dk",
    "de-DE": "de", "el": "gr", "en-AU": "au", "en-CA": "ca", "en-GB": "gb",
    "en-US": "us", "es-ES": "es", "es-MX": "mx", "fi": "fi", "fr-CA": "ca",
    "fr-FR": "fr", "gu-IN": "in", "he": "il", "hi": "in", "hr": "hr",
    "hu": "hu", "id": "id", "it": "it", "ja": "jp", "kn-IN": "in", "ko": "kr",
    "ml-IN": "in", "mr-IN": "in", "ms": "my", "nl-NL": "nl", "no": "no",
    "or-IN": "in", "pa-IN": "in", "pl": "pl", "pt-BR": "br", "pt-PT": "pt",
    "ro": "ro", "ru": "ru", "sk": "sk", "sl-SI": "si", "sv": "se",
    "ta-IN": "in", "te-IN": "in", "th": "th", "tr": "tr", "uk": "ua",
    "ur-PK": "sa", "vi": "vn", "zh-Hans": "cn", "zh-Hant": "tw",
}
ASTRO_STORE_FALLBACK = {"si": "hr"}

EN_CANDIDATES = [
    "healthkit", "widget", "watch", "streak", "fitness", "workout", "habits",
    "steps", "exercise", "move", "stand", "complication", "counter", "chain",
    "reminder", "calendar", "timer", "wellness", "routine", "progress",
]

# en-* brand; localized elsewhere (no English Streak Tracker paste)
NAMES: dict[str, str] = {
    "en-US": "Streak Tracker: Fitness Habits",
    "en-AU": "Streak Tracker: Fitness Habits",
    "en-CA": "Streak Tracker: Fitness Habits",
    "en-GB": "Streak Tracker: Fitness Habits",
    "de-DE": "Fitness-Serien: Gesundheitstracker",
    "fr-FR": "Séries fitness · Santé & Pas",
    "fr-CA": "Séries fitness · Santé & Pas",
    "es-ES": "Rachas fitness · Salud activa",
    "es-MX": "Rachas Fitness: Salud Activa",
    "ca": "Ratxes fitness · Salut activa",
    "it": "Serie fitness · Salute attiva",
    "pt-BR": "Sequências fitness · Saúde ativa",
    "pt-PT": "Sequências fitness · Saúde ativa",
    "nl-NL": "Fitness reeksen · Gezondheid",
    "pl": "Serie fitness · Zdrowie i kroki",
    "sv": "Streak-koll: Träning & hälsa",
    "da": "Fitness-serier · Sundhedstjek",
    "no": "Fitness-serier · Helsedata",
    "fi": "Kunto-putket · Terveysdata",
    "cs": "Fitness série · Zdraví a pohyb",
    "sk": "Fitness série · Zdravie a pohyb",
    "hu": "Fitness sorozat · Egészség",
    "ro": "Serii fitness · Tracker pași",
    "hr": "Fitness nizovi · Zdravlje",
    "el": "Σερί fitness · Παρακολούθηση",
    "tr": "Fitness seri takibi · Sağlık",
    "ru": "Фитнес-серии: трекер шагов",
    "uk": "Трекер фітнес-серій · Рух",
    "ja": "フィットネス連続記録トラッカー · 健康習慣管理",
    "ko": "스트릭 피트니스 트래커 · 헬스 연속 기록 앱",
    "zh-Hans": "健身连胜打卡习惯追踪器 · 运动与健康数据管理器",
    "zh-Hant": "健身連勝打卡習慣追蹤器 · 運動與健康數據管理器",
    "ar-SA": "سلاسل اللياقة · تتبع تلقائي",
    "he": "רצפי כושר · מעקב אוטומטי",
    "hi": "स्ट्रीक फिटनेस · स्वास्थ्य ट्रैकर",
    "bn-BD": "স্ট্রিক ফিটনেস · স্বাস্থ্য ট্র্যাকার",
    "th": "ตัวติดตามสตรีคฟิตเนส · สุขภาพ",
    "vi": "Theo dõi chuỗi tập luyện · Sức khỏe",
    "id": "Streak fitness · Data kesehatan",
    "ms": "Siri kecergasan · Data kesihatan",
    "gu-IN": "સ્ટ્રીક ફિટનેસ · આરોગ્ય ટ્રેકર",
    "kn-IN": "ಸ್ಟ್ರೀಕ್ ಫಿಟ್‌ನೆಸ್ · ಆರೋಗ್ಯ ಟ್ರ್ಯಾಕರ್",
    "ml-IN": "സ്ട്രീക്ക് ഫിറ്റ്നസ് · ആരോഗ്യ ട്രാക്കർ",
    "mr-IN": "स्ट्रीक फिटनेस · आरोग्य ट्रॅकर",
    "or-IN": "ଷ୍ଟ୍ରିକ୍ ଫିଟନେସ୍ · ସ୍ୱାସ୍ଥ୍ୟ ଟ୍ରାକର୍",
    "pa-IN": "ਸਟ੍ਰੀਕ ਫਿਟਨੈਸ · ਸਿਹਤ ਟ੍ਰੈਕਰ",
    "ta-IN": "ஃபிட்னஸ் ஸ்ட்ரீக் · உடல்நல டிராக்கர்",
    "te-IN": "ఫిట్‌నెస్ స్ట్రీక్ · ఆరోగ్య ట్రాకర్",
    "ur-PK": "فٹنس اسٹریک ٹریکر · صحت ٹریکر",
    "sl-SI": "Fitness Streaks: nizi gibanja",
}

SUBTITLES: dict[str, str] = {
    "en-US": "Auto Streaks From Health Data",
    "en-AU": "Auto Streaks From Health Data",
    "en-CA": "Auto Streaks From Health Data",
    "en-GB": "Auto Streaks From Health Data",
    "de-DE": "Auto-Serien aus Health-Daten",
    "fr-FR": "Séries auto via données santé",
    "fr-CA": "Séries auto de données santé",
    "es-ES": "Rachas auto desde tu salud",
    "es-MX": "Rachas auto desde datos salud",
    "ca": "Ratxes automàtiques de salut",
    "it": "Serie auto dai dati salute",
    "pt-BR": "Sequências auto da saúde",
    "pt-PT": "Sequências auto. da saúde",
    "nl-NL": "Reeksen automatisch herkend",
    "pl": "Auto serie z danych zdrowia",
    "sv": "Auto-serier från hälsodata",
    "da": "Auto serier fra sundhedsdata",
    "no": "Auto streaks fra helsedata",
    "fi": "Auto-putket terveysdatasta",
    "cs": "Automatické série ze zdraví",
    "sk": "Automatické série zo zdravia",
    "hu": "Sorozatok az egészségadatból",
    "ro": "Serii auto din date sănătate",
    "hr": "Auto nizovi iz Apple Health",
    "el": "Αυτόματη εύρεση από Health",
    "tr": "Sağlık verisinden otomatik seri",
    "ru": "Авто-серии из данных здоровья",
    "uk": "Авто-серії з даних здоров'я",
    "ja": "ヘルスケアデータから継続記録を自動で見つけ出します",
    "ko": "헬스케어 데이터에서 연속 기록을 자동으로 찾아줍니다",
    "zh-Hans": "从健康数据自动发现运动连续记录与日常习惯追踪助手",
    "zh-Hant": "從健康資料自動發現運動連續記錄與日常習慣追蹤助手",
    "ar-SA": "اكتشف عاداتك الصحية فوراً",
    "he": "רצפים אוטומטיים מנתוני בריאות",
    "hi": "हेल्थ से अपने-आप सिलसिले खोजें",
    "bn-BD": "স্বাস্থ্য ধারা অটো খুঁজুন",
    "th": "สตรีคอัตโนมัติจากข้อมูลสุขภาพ",
    "vi": "Chuỗi tự động từ dữ liệu sức khỏe",
    "id": "Otomatis dari data kesehatan",
    "ms": "Siri Auto Dari Data Sihat",
    "gu-IN": "આરોગ્ય ડેટામાંથી સળંગ આપોઆપ શોધો",
    "kn-IN": "ನಿಮ್ಮ ಆರೋಗ್ಯ ಸರಣಿ ಸ್ವಯಂ ಹುಡುಕಿ",
    "ml-IN": "ആരോഗ്യ ശ്രേണി സ്വയം കണ്ടെത്തൂ",
    "mr-IN": "आरोग्य डेटातून आपोआप शोध",
    "or-IN": "ସ୍ୱାସ୍ଥ୍ୟ ଡାଟାରୁ ସ୍ୱୟଂ ଖୋଜ",
    "pa-IN": "ਸਿਹਤ ਡੇਟਾ ਤੋਂ ਆਪੋ ਆਪ ਲੜੀਆਂ ਲੱਭੋ",
    "ta-IN": "ஹெல்த்தில் தானியங்கு தொடர்கள்",
    "te-IN": "హెల్త్ డేటాతో ఆటో స్ట్రీక్‌లు",
    "ur-PK": "ہیلتھ ڈیٹا سے خودکار اسٹریکس",
    "sl-SI": "Samodejni nizi iz Apple Health",
}

# Indian + sl-SI + CJK keyword pools (expanded for 94+ char budget)
EXTRA_KW: dict[str, str] = {
    "ko": "동기,습관,링,healthkit,위젯,워치,이동,걸음,운동,마음챙김,수면,스탠드,체인,히트맵,활동,badge,루틴,진행,칼로리,활동량,동기부여,습관추적,momentum,nudge,streak,fitness,workout,habits,steps,wellness",
    "zh-Hans": "激励,圆环,healthkit,小组件,手表,移动,步数,锻炼,正念,睡眠,站立,链条,热力图,活动,badge,卡路里,活动量,运动环,打卡,连胜,追踪,健康,ring,stand,momentum,nudge,streak,fitness,workout,habits,steps,wellness",
    "zh-Hant": "激勵,圓環,healthkit,小工具,手錶,移動,步數,鍛煉,正念,睡眠,站立,鏈條,熱力圖,活動,badge,卡路里,活動量,運動環,打卡,連勝,追蹤,健康,ring,stand,momentum,nudge,streak,fitness,workout,habits,steps,wellness",
    "ar-SA": "تحفيز,عادة,حلقات,healthkit,ودجت,ساعة,حركة,خطوات,تمرين,تأمل,نوم,وقوف,سلسلة,خريطة,نشاط,badge,لياقة,تمارين,تتبع,عادات,لياقةبدنية,تمارينيومية",
    "gu-IN": "રિંગ,સ્ટેન્ડ,હીટમેપ,માઇન્ડફુલ,ઊંઘ,કસરત,પ્રવૃત્તિ,વર્કઆઉટ,પગલાં,લક્ષ્ય,આદત,કેલેન્ડર,ઇતિહાસ,વિજેટ,વોચ,healthkit,chain,momentum,nudge",
    "kn-IN": "ರಿಂಗ್,ಸ್ಟ್ಯಾಂಡ್,ಹೀಟ್‌ಮ್ಯಾಪ್,ಮೈಂಡ್‌ಫುಲ್,ನಿದ್ರೆ,ವ್ಯಾಯಾಮ,ಚಟುವಟಿಕೆ,ವರ್ಕ್‌ಔಟ್,ಹೆಜ್ಜೆಗಳು,ಗುರಿ,ಆದತೆ,ಕ್ಯಾಲೆಂಡರ್,ಇತಿಹಾಸ,ವಿಜೆಟ್,ವಾಚ್,healthkit,chain,momentum",
    "ml-IN": "റിംഗ്,സ്റ്റാൻഡ്,ഹീറ്റ്‌മാപ്,മൈൻഡ്‌ഫുൾ,ഉറക്കം,വ്യായാമം,പ്രവർത്തനം,വർക്കൗട്ട്,ഘട്ടങ്ങൾ,ലക്ഷ്യം,ശീലം,കലണ്ടർ,ചരിത്രം,വിജറ്റ്,വാച്ച്,healthkit,chain",
    "mr-IN": "रिंग,स्टँड,हीटमॅप,माइंडफुल,झोप,व्यायाम,क्रियाकलाप,वर्कआउट,पाऊल,ध्येय,सवय,कॅलेंडर,इतिहास,विजेट,वॉच,healthkit,chain,momentum",
    "or-IN": "ରିଂ,ଷ୍ଟାଣ୍ଡ,ହିଟମ୍ୟାପ,ମାଇଣ୍ଡଫୁଲ,ଶୋଇବା,ବ୍ୟାୟାମ,କାର୍ଯ୍ୟକଳାପ,ୱର୍କଆଉଟ,ପାଦଗୁଡି,ଲକ୍ଷ୍ୟ,ଅଭ୍ୟାସ,କ୍ୟାଲେଣ୍ଡର,ଇତିହାସ,ୱିଜେଟ,ୱାଚ,healthkit,chain",
    "pa-IN": "ਰਿੰਗ,ਸਟੈਂਡ,ਹੀਟਮੈਪ,ਮਾਈਂਡਫੁਲ,ਨੀਂਦ,ਕਸਰਤ,ਗਤੀਵਿਧੀ,ਵਰਕਆਉਟ,ਕਦਮ,ਲਕ੍ਯ,ਆਦਤ,ਕੈਲੰਡਰ,ਇਤਿਹਾਸ,ਵਿਜੇਟ,ਵਾਚ,healthkit,chain,momentum",
    "ta-IN": "ரிங்,ஸ்டாண்ட்,ஹீட்மேப்,மைண்ட்ஃபுல்,தூக்கம்,உடற்பயிற்சி,செயல்பாடு,வொர்க்அவுட்,படிகள்,இலக்கு,பழக்கம்,காலண்டர்,வரலாறு,விஜெட்,வாட்ச்,healthkit,chain",
    "te-IN": "రింగ్,స్టాండ్,హీట్‌మ్యాప్,మైండ్‌ఫుల్,నిద్ర,వ్యాయామం,కార్యకలాపం,వర్కౌట్,అడుగులు,లక్ష్యం,అలవాటు,క్యాలెండర్,చరిత్ర,విడ్జెట్,వాచ్,healthkit,chain",
    "ur-PK": "رنگ,اسٹینڈ,ہیٹ میپ,مائنڈفل,نیند,ورزش,سرگرمی,ورک آؤٹ,قدم,ہدف,عادت,کیلنڈر,تاریخ,وجیٹ,واچ,healthkit,chain,momentum,nudge",
    "sl-SI": "motivacija,navada,prstani,healthkit,widget,ura,gibanje,koraki,trening,mindfulness,spavanje,stajanje,lanac,heatmap,aktivnost,niz,badge,skriti,nudge",
}

EXTRA_NATIVE: dict[str, list[str]] = {
    "he": ["טבעת", "עמידה", "שינה", "אימון", "צעדים", "יעד", "לוח", "תזכורת"],
    "ko": ["링", "스탠드", "수면", "운동", "걸음", "목표", "캘린더", "알림", "활동"],
    "ja": ["リング", "スタンド", "睡眠", "運動", "歩数", "目標", "カレンダー", "通知"],
    "zh-Hans": ["圆环", "站立", "睡眠", "锻炼", "步数", "目标", "日历", "提醒", "活动", "记录"],
    "zh-Hant": ["圓環", "站立", "睡眠", "鍛煉", "步數", "目標", "日曆", "提醒", "活動", "記錄"],
    "tr": ["halka", "ayakta", "uyku", "adım", "hedef", "takvim", "hatırlatma"],
}


def load_astro() -> dict:
    raw = json.loads(ASTRO.read_text())
    if "fitness" in raw:
        return raw["fitness"]
    return raw


def astro_pop(astro: dict, store: str, term: str) -> int | None:
    meta = astro.get(store, {}).get(term.lower()) or astro.get(store, {}).get(term)
    if not meta or meta.get("skipped"):
        return None
    p = meta.get("pop")
    return int(p) if isinstance(p, (int, float)) else None


def indexed(name: str, subtitle: str) -> set[str]:
    out: set[str] = set()
    for w in re.findall(r"[a-z0-9']+", f"{name} {subtitle}".lower()):
        if len(w) >= 2:
            out.add(w)
    for c in re.findall(r"[\u0600-\u06ff\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af\u0900-\u097f]+", name + subtitle):
        if len(c) >= 2:
            out.add(c)
    return out


def pack_keywords(tokens: list[str], limit: int = 100) -> str:
    out, n, seen = [], 0, set()
    for t in tokens:
        key = t.lower() if t.isascii() else t
        if key in seen:
            continue
        add = len(t) + (1 if out else 0)
        if n + add > limit:
            continue
        out.append(t)
        seen.add(key)
        n += add
    return ",".join(out)


def build_keywords(locale: str, name: str, subtitle: str, native: list[str], astro: dict, store: str) -> tuple[str, list[str]]:
    idx = indexed(name, subtitle)
    astro_store = ASTRO_STORE_FALLBACK.get(store, store)
    tokens: list[str] = []
    en_kept: list[str] = []

    for t in native:
        tl = t.lower() if t.isascii() else t
        if tl in idx or t in name or t in subtitle:
            continue
        tokens.append(t)
    existing = {t.lower() for t in tokens}

    if not locale.startswith("en-"):
        ranked = []
        for term in EN_CANDIDATES:
            p = astro_pop(astro, astro_store, term)
            if p is not None and p >= 6:
                ranked.append((p, term))
        ranked.sort(reverse=True)
        for p, term in ranked:
            if term.lower() not in existing and term.lower() not in idx:
                tokens.append(term)
                en_kept.append(f"{term}({p})")
                existing.add(term.lower())

    for t in EXTRA_NATIVE.get(locale, []):
        tl = t.lower() if t.isascii() else t
        if tl not in idx and tl not in existing:
            tokens.append(t)
            existing.add(tl)

    kw = pack_keywords(tokens, 100)
    if len(kw) < 94:
        for term in EN_CANDIDATES:
            p = astro_pop(astro, astro_store, term)
            if p is None or p < 6 or term.lower() in existing or term.lower() in idx:
                continue
            trial = pack_keywords(tokens + [term], 100)
            if len(trial) > len(kw):
                tokens.append(term)
                existing.add(term.lower())
                tag = f"{term}({p})"
                if tag not in en_kept:
                    en_kept.append(tag)
                kw = trial
            if len(kw) >= 94:
                break
    return kw, en_kept


def trim_field(s: str, limit: int) -> str:
    return s[:limit] if len(s) > limit else s


def all_locales() -> dict[str, dict[str, str]]:
    locs: dict[str, dict[str, str]] = {}
    for loc in sorted(LOCALE_TO_STORE):
        pool = EXTRA_KW.get(loc) or BASE_KW.get(loc) or BASE_KW.get("en-US", "")
        locs[loc] = {
            "name": NAMES[loc],
            "subtitle": SUBTITLES[loc],
            "native_kw": pool,
        }
    return locs


def main() -> None:
    astro = load_astro()
    locales = all_locales()
    report: dict = {}
    issues: list[str] = []

    for locale, spec in locales.items():
        store = LOCALE_TO_STORE[locale]
        name = trim_field(spec["name"], 30)
        subtitle = trim_field(spec["subtitle"], 30)
        native = [t.strip() for t in spec["native_kw"].split(",") if t.strip()]
        kw, en_kept = build_keywords(locale, name, subtitle, native, astro, store)
        overlaps = [t for t in kw.split(",") if t.lower() in indexed(name, subtitle)]
        entry = {
            "store": store,
            "title": name,
            "subtitle": subtitle,
            "keywords": kw,
            "title_len": len(name),
            "subtitle_len": len(subtitle),
            "keywords_len": len(kw),
            "keyword_overlaps": overlaps,
            "astro_en_kept": en_kept,
            "astro_proof": (
                [f"EN loanwords Astro pop≥6: {', '.join(en_kept)}"] if en_kept
                else ["Native/transliterated keywords only; no EN loanwords met pop≥6 in this store."]
            ),
            "rationale": (
                f"{'Streak Tracker brand in title (en-*).' if locale.startswith('en-') else 'Localized title; no English brand paste.'} "
                f"HealthKit auto-streak positioning; keywords deduped vs title+subtitle, packed {len(kw)}/100."
            ),
            "ok": len(name) >= 24 and len(subtitle) >= 24 and len(kw) >= 94 and not overlaps,
        }
        if len(name) < 24:
            issues.append(f"{locale} title {len(name)}<24")
        if len(subtitle) < 24:
            issues.append(f"{locale} subtitle {len(subtitle)}<24")
        if len(kw) < 94:
            issues.append(f"{locale} keywords {len(kw)}<94")
        if overlaps:
            issues.append(f"{locale} kw overlaps: {overlaps}")
        report[locale] = entry

        d = META / locale
        d.mkdir(parents=True, exist_ok=True)
        (d / "name.txt").write_text(name + "\n", encoding="utf-8")
        (d / "subtitle.txt").write_text(subtitle + "\n", encoding="utf-8")
        (d / "keywords.txt").write_text(kw + "\n", encoding="utf-8")

    out_json = ROOT / "scripts" / "aso-fitness-locale-readout.json"
    out_md = ROOT / "scripts" / "aso-fitness-locale-readout.md"
    out_json.write_text(json.dumps({"locales": report, "issues": issues}, ensure_ascii=False, indent=2))

    lines = [
        "# Fitness Habits — full locale readout (proposed ASC metadata)\n",
        "Policy: Streak Tracker in **title** for en-* only · HealthKit auto-streaks · EN loanwords if Astro pop≥6\n",
    ]
    for loc, e in report.items():
        lines.append(f"## {loc} (store: `{e['store']}`)\n")
        lines.append(f"**Title** ({e['title_len']}/30): {e['title']}\n")
        lines.append(f"**Subtitle** ({e['subtitle_len']}/30): {e['subtitle']}\n")
        lines.append(f"**Keywords** ({e['keywords_len']}/100): {e['keywords']}\n")
        if e["astro_en_kept"]:
            lines.append(f"**Astro EN:** {', '.join(e['astro_en_kept'])}\n")
        lines.append(f"**Why:** {e['rationale']}\n")
        lines.append(f"**Astro proof:** {' '.join(e['astro_proof'])}\n")
    if issues:
        lines.append("\n## Warnings\n")
        for i in issues:
            lines.append(f"- {i}\n")
    out_md.write_text("".join(lines))

    print(f"Wrote {out_json}")
    print(f"Wrote {out_md}")
    print(f"Locales: {len(report)}, warnings: {len(issues)}, ok: {sum(1 for e in report.values() if e['ok'])}")


if __name__ == "__main__":
    main()
