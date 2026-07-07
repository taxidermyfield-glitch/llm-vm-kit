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
  config/ai-sync.env.example
  bin/ai-chat
  bin/ai-code
  bin/ai-agent
  bin/ai-model
  bin/ai-memory
  bin/ai-pull
  bin/ai-status
  bin/ai-server-start
  bin/ai-server-stop
  bin/ai-vllm-start
  bin/ai-vllm-stop
  bin/ai-sync-from-server
  bin/ai-sync-to-server
  bin/ai-sync-status
  bin/ai-set-system-prompt
  bin/set-system-prompt
  bin/ai-configure
  bin/ai-browser-start
  bin/ai-backup
  README.md
)

for f in "${required[@]}"; do
  [[ -f "$f" ]] || { echo "Missing required file: $f" >&2; exit 1; }
done

while read -r mode _ _ path; do
  [[ "$mode" == "100755" ]] || {
    echo "Command file is not executable in Git index: $path ($mode)" >&2
    exit 1
  }
done < <(git ls-files -s 'bin/*')

while IFS= read -r -d '' f; do
  bash -n "$f"
done < <(find . -type f \( -name '*.sh' -o -path './bin/ai-*' -o -path './bin/set-system-prompt' -o -name 'install.sh' -o -name 'bootstrap.sh' \) -print0)

python3 - <<'PY'
from pathlib import Path

env_text = Path("config/ai.env.example").read_text()
sync_text = Path("config/ai-sync.env.example").read_text()
sync_lib_text = Path("lib/sync.sh").read_text()

env_required = [
    "AI_HF_MODEL=",
    "AI_BACKEND=",
    "AI_MODEL=",
    "AI_MODEL_PRESET=",
    "AI_CONTEXT_LENGTH=",
    "AI_SYSTEM_PROMPT_FILE=",
    "AI_MEMORY_DIR=",
    "AI_MEMORY_FILE=",
    "AI_VLLM_TENSOR_PARALLEL_SIZE=",
    "AI_VLLM_DTYPE=",
    "AI_VLLM_GPU_MEMORY_UTILIZATION=",
    "AI_VLLM_EXTRA_ARGS=",
    "AI_INSTALL_OPTIONAL_BACKENDS=",
]

sync_required = [
    "AI_SYNC_REMOTE_USER=",
    "AI_SYNC_REMOTE_HOST=",
    "AI_SYNC_REMOTE_PORT=",
    "AI_SYNC_REMOTE_ROOT=",
    "AI_SYNC_SSH_KEY=",
    "AI_SYNC_LOCAL_ROOT=",
    "AI_SYNC_AI_HOME=",
    "AI_SYNC_DELETE=",
]

missing = [x for x in env_required if x not in env_text]
missing += [x for x in sync_required if x not in sync_text]
if missing:
    raise SystemExit(f"Missing config keys: {missing}")

for forbidden in ["AI_SYNC_REMOTE_USER=", "AI_SYNC_REMOTE_HOST=", "AI_SYNC_SSH_KEY="]:
    if forbidden in env_text:
        raise SystemExit(f"Sync credential key leaked into config/ai.env.example: {forbidden}")

stable_remote_dirs = [
    "projects",
    "datasets",
    "outputs",
    "config",
    "memory",
    "opencode",
    "hermes",
    "logs",
    "sync",
]
missing_dirs = [d for d in stable_remote_dirs if f"  {d}" not in sync_lib_text]
if missing_dirs:
    raise SystemExit(f"Stable sync schema dirs missing from lib/sync.sh: {missing_dirs}")
PY

echo "Smoke test passed."
