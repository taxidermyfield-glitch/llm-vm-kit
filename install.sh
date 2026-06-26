#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

AI_STACK_REPO="${AI_STACK_REPO:-}"
AI_STACK_DIR="${AI_STACK_DIR:-/opt/llm-vm-kit}"

if [[ -z "$AI_STACK_REPO" ]]; then
  echo "Set AI_STACK_REPO to your GitHub repo URL." >&2
  echo "Example:" >&2
  echo "  AI_STACK_REPO=https://github.com/YOUR_USER/llm-vm-kit.git bash install.sh" >&2
  exit 1
fi

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
else
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "install.sh must run as root or as a sudo-capable user." >&2
    exit 1
  fi
fi

if command -v apt-get >/dev/null 2>&1; then
  $SUDO apt-get update
  $SUDO apt-get install -y ca-certificates curl git
fi

if [[ -d "$AI_STACK_DIR/.git" ]]; then
  $SUDO git -C "$AI_STACK_DIR" pull --ff-only
else
  $SUDO rm -rf "$AI_STACK_DIR"
  $SUDO git clone "$AI_STACK_REPO" "$AI_STACK_DIR"
fi

env_args=("AI_STACK_DIR=$AI_STACK_DIR")

for key in AI_MODEL_PRESET AI_BACKEND AI_HF_MODEL AI_MODEL_QUANT AI_MODEL AI_CONTEXT_LENGTH AI_SKIP_PULL AI_AGENT_TOOLSETS AI_APPROVAL_MODE AI_SYSTEM_PROMPT_FILE AI_SYSTEM_PROMPT AI_VLLM_TENSOR_PARALLEL_SIZE AI_VLLM_DTYPE AI_VLLM_GPU_MEMORY_UTILIZATION AI_VLLM_EXTRA_ARGS AI_SYNC_REMOTE_USER AI_SYNC_REMOTE_HOST AI_SYNC_REMOTE_PORT AI_SYNC_REMOTE_ROOT AI_SYNC_SSH_KEY AI_SYNC_LOCAL_ROOT AI_SYNC_AI_HOME AI_SYNC_DELETE AI_AUTO_SYNC_FROM_SERVER AI_REQUIRE_SYNC_CONFIG; do
  if [[ -n "${!key:-}" ]]; then
    env_args+=("$key=${!key}")
  fi
done

if [[ -n "$SUDO" ]]; then
  $SUDO env "${env_args[@]}" bash "$AI_STACK_DIR/bootstrap.sh"
else
  env "${env_args[@]}" bash "$AI_STACK_DIR/bootstrap.sh"
fi
