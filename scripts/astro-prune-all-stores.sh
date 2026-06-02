#!/bin/bash
# Prune junk keywords on all 91 Astro stores (wrong language, headache terms, EN bleed).
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/astro-optimize.py --all-stores --prune
