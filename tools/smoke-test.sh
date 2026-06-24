#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo"

required=(
  bootstrap.sh
  install.sh
  lib/env.sh
  config/ai.env.example
  bin/ai-chat
  bin/ai-code
  bin/ai-agent
  bin/ai-model
  bin/ai-pull
  bin/ai-status
  bin/ai-configure
  bin/ai-ollama-start
  bin/ai-browser-start
  bin/ai-backup
  README.md
)

for f in "${required[@]}"; do
  [[ -f "$f" ]] || { echo "Missing required file: $f" >&2; exit 1; }
done

while IFS= read -r -d '' f; do
  bash -n "$f"
done < <(find . -type f \( -name '*.sh' -o -path './bin/ai-*' -o -name 'install.sh' -o -name 'bootstrap.sh' \) -print0)

python3 - <<'PY'
from pathlib import Path

text = Path("config/ai.env.example").read_text()
required = ["AI_HF_MODEL=", "AI_MODEL=", "AI_CONTEXT_LENGTH=", "OLLAMA_MODELS="]
missing = [x for x in required if x not in text]
if missing:
    raise SystemExit(f"Missing config keys: {missing}")
PY

echo "Smoke test passed."
