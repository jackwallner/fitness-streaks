#!/usr/bin/env python3
"""Step 8: native keyword suggestions for tier-1 Astro stores (Streak Finder)."""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from astro_locale import seeds_for_store
from astro_mcp import add_keywords, call, ping

MCP_URL = "http://127.0.0.1:8089/mcp"
CONFIG = Path(__file__).parent / ".astro-app.json"
TIER1 = ("us", "gb", "de", "fr", "ca", "au", "jp", "br", "mx", "es", "it", "nl", "kr", "cn", "tw")


def main() -> None:
    if not ping(MCP_URL):
        raise SystemExit("error: Astro MCP not reachable")
    app_id = str(json.loads(CONFIG.read_text())["appId"])
    for store in TIER1:
        seeds = seeds_for_store(store)
        try:
            suggestions = call(
                MCP_URL,
                "get_keyword_suggestions",
                {"appId": app_id, "store": store, "seedKeywords": list(seeds)},
            )
            kws: list[str] = []
            if isinstance(suggestions, list):
                for s in suggestions[:25]:
                    if isinstance(s, dict):
                        term = s.get("keyword") or s.get("term")
                        pop = s.get("popularity") or 0
                        diff = s.get("difficulty") or 99
                        if term and pop >= 12 and diff <= 82:
                            kws.append(str(term).lower())
                    elif isinstance(s, str):
                        kws.append(s.lower())
            if not kws:
                print(f"{store}: no suggestions (seeds: {seeds[0]}…)")
                continue
            existing = call(MCP_URL, "get_app_keywords", {"appId": app_id, "store": store})
            have = {k["keyword"].lower() for k in existing if isinstance(k, dict)}
            add = [k for k in kws if k not in have][:12]
            if add:
                add_keywords(MCP_URL, app_id, store, add)
                print(f"{store}: added {len(add)} native suggestions")
            else:
                print(f"{store}: nothing new")
        except Exception as e:
            print(f"{store}: ERROR {e}", file=sys.stderr)
        time.sleep(2.0)


if __name__ == "__main__":
    main()
