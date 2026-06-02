#!/usr/bin/env python3
"""Step 3: search_app_store for each Astro store (native head term)."""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from astro_mcp import call, ping

MCP_URL = "http://127.0.0.1:8089/mcp"
STORES_JSON = Path(__file__).parent / "astro-stores-2026.json"
OUT = Path(__file__).parent / "astro-competitor-research.json"

# Native search head terms per store (fitness streak / habit)
HEAD_TERMS: dict[str, str] = {
    "us": "fitness streak tracker",
    "gb": "fitness streak tracker",
    "de": "fitness gewohnheiten tracker",
    "fr": "suivi habitudes fitness",
    "es": "racha fitness hábitos",
    "mx": "racha fitness hábitos",
    "br": "sequência fitness hábitos",
    "jp": "フィットネス 習慣 連続",
    "kr": "피트니스 습관 연속",
    "cn": "健身 习惯 连续",
    "tw": "健身 習慣 連續",
    "it": "abitudini fitness serie",
    "nl": "fitness gewoonte streak",
    "pl": "nawyki fitness seria",
    "ru": "фитнес привычки серия",
    "tr": "fitness alışkanlık seri",
    "sa": "متتبع عادات اللياقة",
    "in": "fitness habit streak",
    "th": "ติดตามนิสัยฟิตเนส",
    "vi": "theo dõi thói quen fitness",
    "id": "pelacak kebiasaan fitness",
}

DEFAULT_TERM = "habit streak tracker"


def head_term(store: str) -> str:
    return HEAD_TERMS.get(store, DEFAULT_TERM)


def main() -> None:
    if not ping(MCP_URL):
        raise SystemExit("error: Astro MCP not reachable")
    stores = json.loads(STORES_JSON.read_text())["stores"]
    results: dict = {"scannedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "stores": {}}
    for i, entry in enumerate(stores):
        code = entry["code"]
        term = head_term(code)
        try:
            hits = call(MCP_URL, "search_app_store", {"query": term, "store": code, "limit": 5})
            top = []
            if isinstance(hits, list):
                for h in hits[:5]:
                    if isinstance(h, dict):
                        top.append(
                            {
                                "name": h.get("name") or h.get("title"),
                                "subtitle": h.get("subtitle"),
                                "bundleId": h.get("bundleId"),
                            }
                        )
            results["stores"][code] = {"term": term, "competitors": top}
            print(f"{code}: {term} → {len(top)} hits")
        except Exception as e:
            results["stores"][code] = {"term": term, "error": str(e)}
            print(f"{code}: ERROR {e}", file=sys.stderr)
        if i < len(stores) - 1:
            time.sleep(1.1)
    OUT.write_text(json.dumps(results, indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
