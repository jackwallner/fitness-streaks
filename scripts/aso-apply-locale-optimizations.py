#!/usr/bin/env python3
"""Apply optimized native keywords/subtitles for Streak Finder (go pipeline).

Dedupes keywords against each locale's name + subtitle (Apple indexes all three).
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"

# Raw keyword candidates (≤100 after dedupe). Dedupe strips name/subtitle overlaps.
KEYWORDS: dict[str, str] = {
    "en-US": "motivate,habit,rings,healthkit,widget,watch,move,steps,workout,mindful,sleep,stand,chain,heatmap,activity,exercise,badge,momentum,calendar",
    "en-GB": "motivate,habit,rings,healthkit,widget,watch,move,steps,workout,mindful,sleep,stand,chain,heatmap,activity,exercise,badge,momentum,calendar",
    "en-AU": "motivate,habit,rings,healthkit,widget,watch,move,steps,workout,mindful,sleep,stand,chain,heatmap,activity,exercise,badge,momentum,calendar",
    "en-CA": "motivate,habit,rings,healthkit,widget,watch,move,steps,workout,mindful,sleep,stand,chain,heatmap,activity,exercise,badge,momentum,calendar",
    "de-DE": "motivation,gewohnheit,ringe,healthkit,widget,uhr,bewegung,schritte,training,achtsamkeit,schlaf,stehen,kette,heatmap,aktivität,serie,badge",
    "fr-FR": "motiver,habitude,anneaux,healthkit,widget,montre,mouvement,pas,entraînement,méditation,sommeil,debout,chaîne,carte,activité,série,badge",
    "fr-CA": "motiver,habitude,anneaux,healthkit,widget,montre,mouvement,pas,entraînement,méditation,sommeil,debout,chaîne,carte,activité,série,badge",
    "es-ES": "motivar,hábito,anillos,healthkit,widget,reloj,mover,pasos,entreno,mindfulness,sueño,de pie,cadena,mapa,actividad,racha,badge",
    "es-MX": "motivar,hábito,anillos,healthkit,widget,reloj,mover,pasos,entreno,mindfulness,sueño,de pie,cadena,mapa,actividad,racha,badge",
    "ca": "motivar,hàbit,anells,healthkit,widget,rellotge,moure,passos,entrenament,mindfulness,son,peu,cadena,mapa,activitat,ratxa,badge",
    "it": "motivare,abitudine,anelli,healthkit,widget,orologio,muovere,passi,allenamento,mindfulness,sonno,in piedi,catena,mappa,attività,serie,badge",
    "pt-BR": "motivar,hábito,anéis,healthkit,widget,relógio,mover,passos,treino,mindfulness,sono,em pé,cadeia,mapa,atividade,sequência,badge",
    "pt-PT": "motivar,hábito,anéis,healthkit,widget,relógio,mover,passos,treino,mindfulness,sono,em pé,cadeia,mapa,atividade,sequência,badge",
    "nl-NL": "motiveren,gewoonte,ringen,healthkit,widget,horloge,bewegen,stappen,training,mindfulness,slaap,staan,keten,heatmap,activiteit,reeks,badge",
    "pl": "motywacja,nawyk,pierścienie,healthkit,widget,zegarek,ruch,kroki,trening,mindfulness,sen,stawanie,łańcuch,mapa,aktywność,seria,badge",
    "sv": "motivera,vana,ringar,healthkit,widget,klocka,rörelse,steg,träning,mindfulness,sömn,stå,kedja,heatmap,aktivitet,serie,badge",
    "da": "motivere,vane,ringe,healthkit,widget,ur,bevægelse,skridt,træning,mindfulness,søvn,stå,kæde,heatmap,aktivitet,serie,badge",
    "no": "motivere,vane,ringe,healthkit,widget,klokke,bevegelse,skritt,trening,mindfulness,søvn,stå,kjede,heatmap,aktivitet,serie,badge",
    "fi": "motivoida,tottumus,renkaat,healthkit,widget,kello,liike,askeleet,treeni,mindfulness,uni,seisoa,ketju,heatmap,aktiivisuus,putki,badge",
    "cs": "motivace,návyk,kruhy,healthkit,widget,hodinky,pohyb,kroky,trénink,mindfulness,spánek,stát,řetěz,heatmap,aktivita,série,badge",
    "sk": "motivácia,návyk,kruhy,healthkit,widget,hodinky,pohyb,kroky,tréning,mindfulness,spánok,stát,reťaz,heatmap,aktivita,séria,badge",
    "hu": "motiváció,szokás,gyűrűk,healthkit,widget,óra,mozgás,lépések,edzés,mindfulness,alvás,állás,lánc,heatmap,aktivitás,sorozat,badge",
    "ro": "motivație,obicei,inele,healthkit,widget,ceas,mișcare,pași,antrenament,mindfulness,somn,în picioare,lanț,hartă,activitate,serie,badge",
    "hr": "motivacija,navika,prstenovi,healthkit,widget,sat,pokret,koraci,trening,mindfulness,spavanje,stajanje,lanac,heatmap,aktivnost,niz,badge",
    "el": "κίνητρο,συνήθεια,δαχτυλίδια,healthkit,widget,ρολόι,κίνηση,βήματα,προπόνηση,mindfulness,ύπνος,όρθιος,αλυσίδα,χάρτης,δραστηριότητα,σειρά,badge",
    "tr": "motivasyon,alışkanlık,halkalar,healthkit,widget,saat,hareket,adım,antrenman,mindfulness,uyku,ayakta,zincir,heatmap,aktivite,seri,badge",
    "ru": "мотивация,привычка,кольца,healthkit,widget,часы,движение,шаги,тренировка,осознанность,сон,стоя,цепь,теплокарта,активность,серия,badge",
    "uk": "мотивація,звичка,кільця,healthkit,widget,годинник,рух,кроки,тренування,усвідомленість,сон,стоячи,ланцюг,теплокарта,активність,серія,badge",
    "ja": "やる気,習慣,リング,healthkit,ウィジェット,ウォッチ,ムーブ,歩数,ワークアウト,マインドフル,睡眠,スタンド,チェーン,ヒートマップ,アクティビティ,連続,badge",
    "ko": "동기,습관,링,healthkit,위젯,워치,이동,걸음,운동,마음챙김,수면,스탠드,체인,히트맵,활동,연속,badge",
    "zh-Hans": "激励,习惯,圆环,healthkit,小组件,手表,移动,步数,锻炼,正念,睡眠,站立,链条,热力图,活动,连续,badge",
    "zh-Hant": "激勵,習慣,圓環,healthkit,小工具,手錶,移動,步數,鍛煉,正念,睡眠,站立,鏈條,熱力圖,活動,連續,badge",
    "ar-SA": "تحفيز,عادة,حلقات,healthkit,ودجت,ساعة,حركة,خطوات,تمرين,تأمل,نوم,وقوف,سلسلة,خريطة,نشاط,سلاسل,badge",
    "he": "מוטיבציה,הרגל,טבעות,healthkit,ווידג'ט,שעון,תנועה,צעדים,אימון,מיינדפולנס,שינה,עמידה,שרשרת,מפתחום,פעילות,רצף,badge",
    "hi": "प्रेरणा,आदत,रिंग,healthkit,विजेट,घड़ी,चाल,कदम,वर्कआउट,माइंडफुल,नींद,खड़े,श्रृंखला,हीटमैप,गतिविधि,स्ट्रीक,badge",
    "th": "แรงจูงใจ,นิสัย,วงแหวน,healthkit,วิดเจ็ต,นาฬิกา,เคลื่อนไหว,ก้าว,ออกกำลัง,สติ,นอน,ยืน,สายโซ่,แผนที่ความร้อน,กิจกรรม,สตรีค,badge",
    "vi": "động lực,thói quen,vòng,healthkit,widget,đồng hồ,di chuyển,bước,tập luyện,chánh niệm,ngủ,đứng,chuỗi,bản đồ nhiệt,hoạt động,chuỗi,badge",
    "id": "motivasi,kebiasaan,cincin,healthkit,widget,jam,gerak,langkah,latihan,mindfulness,tidur,berdiri,rantai,heatmap,aktivitas,streak,badge",
    "ms": "motivasi,tabiat,cincin,healthkit,widget,jam,gerak,langkah,latihan,mindfulness,tidur,berdiri,rantaian,heatmap,aktiviti,streak,badge",
}

SUBTITLES: dict[str, str] = {
    "en-US": "Streaks, Widgets & Apple Watch",
    "en-GB": "Streaks, Widgets & Apple Watch",
    "en-AU": "Streaks, Widgets & Apple Watch",
    "en-CA": "Streaks, Widgets & Apple Watch",
    "de-DE": "Serien, Widgets & Apple Watch",
    "fr-FR": "Séries, widgets et Apple Watch",
    "fr-CA": "Séries, widgets et Apple Watch",
    "es-ES": "Rachas, widgets y Apple Watch",
    "es-MX": "Rachas, widgets y Apple Watch",
    "ca": "Ratxes, widgets i Apple Watch",
    "it": "Serie, widget e Apple Watch",
    "pt-BR": "Sequências, widgets e Watch",
    "pt-PT": "Sequências, widgets e Watch",
    "nl-NL": "Reeksen, widgets en Watch",
    "pl": "Serie, widgety i Apple Watch",
    "sv": "Serier, widgets och Watch",
    "da": "Serier, widgets og Watch",
    "no": "Serier, widgets og Watch",
    "fi": "Putket, widgetit ja Watch",
    "cs": "Série, widgety a Apple Watch",
    "sk": "Série, widgety a Apple Watch",
    "hu": "Sorozatok, widgetek, Watch",
    "ro": "Serii, widgeturi și Watch",
    "hr": "Nizovi, widgeti i Watch",
    "el": "Σειρές, widgets & Watch",
    "tr": "Seriler, widget ve Watch",
    "ru": "Серии, виджеты и Watch",
    "uk": "Серії, віджети та Watch",
    "ja": "連続記録・ウィジェット・Watch",
    "ko": "연속 기록·위젯·Watch",
    "zh-Hans": "连续记录、小组件与Watch",
    "zh-Hant": "連續記錄、小工具與Watch",
    "ar-SA": "سلاسل وودجت وWatch",
    "he": "רצפים, ווידג'ט ו-Watch",
    "hi": "स्ट्रीक, विजेट और Watch",
    "th": "สตรีค, วิดเจ็ต และ Watch",
    "vi": "Chuỗi, widget và Watch",
    "id": "Streak, widget & Apple Watch",
    "ms": "Streak, widget & Apple Watch",
}


def indexed_terms(name: str, subtitle: str) -> set[str]:
    text = f"{name} {subtitle}".lower()
    terms: set[str] = set()
    for w in re.findall(r"[a-z0-9\u0080-\uffff]+", text, flags=re.I):
        if len(w) >= 2:
            terms.add(w)
    return terms


def dedupe_keywords(name: str, subtitle: str, keywords_csv: str) -> str:
    indexed = indexed_terms(name, subtitle)
    kept: list[str] = []
    for raw in keywords_csv.replace(" ", "").split(","):
        kw = raw.strip().lower()
        if not kw:
            continue
        if kw in indexed:
            continue
        if any(kw == t or (len(kw) >= 4 and kw in t) or (len(t) >= 4 and t in kw) for t in indexed):
            continue
        kept.append(kw)
    return ",".join(kept)


def trim_keywords(s: str, limit: int = 100) -> str:
    s = s.replace(" ", "")
    if len(s) <= limit:
        return s
    parts = s.split(",")
    while parts and len(",".join(parts)) > limit:
        parts.pop()
    return ",".join(parts)


def trim_subtitle(s: str, limit: int = 30) -> str:
    return s[:limit] if len(s) > limit else s


def main() -> None:
    report: dict[str, dict] = {}
    for loc_dir in sorted(META.iterdir()):
        if not loc_dir.is_dir() or loc_dir.name == "review_information":
            continue
        loc = loc_dir.name
        if loc not in KEYWORDS:
            continue
        kw_path = loc_dir / "keywords.txt"
        sub_path = loc_dir / "subtitle.txt"
        old_kw = kw_path.read_text(encoding="utf-8").strip() if kw_path.exists() else ""
        old_sub = sub_path.read_text(encoding="utf-8").strip() if sub_path.exists() else ""
        name = (loc_dir / "name.txt").read_text(encoding="utf-8").strip() if (loc_dir / "name.txt").exists() else ""
        sub_for_dedupe = SUBTITLES.get(loc, old_sub)
        new_kw = trim_keywords(dedupe_keywords(name, sub_for_dedupe, KEYWORDS[loc]))
        kw_path.write_text(new_kw + "\n", encoding="utf-8")
        new_sub = old_sub
        if loc in SUBTITLES:
            new_sub = trim_subtitle(SUBTITLES[loc])
            sub_path.write_text(new_sub + "\n", encoding="utf-8")
        report[loc] = {
            "keywords": {"old": old_kw, "new": new_kw, "len": len(new_kw)},
            "subtitle": {"old": old_sub, "new": new_sub} if loc in SUBTITLES else {},
        }
    out = ROOT / "scripts" / "aso-locale-optimization-report.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"Updated {len(report)} locales → {out}")


if __name__ == "__main__":
    main()
