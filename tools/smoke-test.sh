#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo"

required=(
  bootstrap.sh
  install.sh
  lib/env.sh
  lib/sync.sh
  config/ai.env.example
  bin/ai-chat
  bin/ai-code
  bin/ai-agent
  bin/ai-model
  bin/ai-pull
  bin/ai-status
  bin/ai-sync-from-server
  bin/ai-sync-to-server
  bin/ai-sync-status
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
required = [
    "AI_HF_MODEL=",
    "AI_MODEL=",
    "AI_CONTEXT_LENGTH=",
    "OLLAMA_MODELS=",
    "AI_SYNC_REMOTE_USER=",
    "AI_SYNC_REMOTE_HOST=",
    "AI_SYNC_REMOTE_PORT=",
    "AI_SYNC_REMOTE_ROOT=",
    "AI_SYNC_SSH_KEY=",
    "AI_SYNC_LOCAL_ROOT=",
    "AI_SYNC_AI_HOME=",
    "AI_SYNC_DELETE=",
    "AI_AUTO_SYNC_FROM_SERVER=",
    "AI_REQUIRE_SYNC_CONFIG=",
]
missing = [x for x in required if x not in text]
if missing:
    raise SystemExit(f"Missing config keys: {missing}")
PY

echo "Smoke test passed."
