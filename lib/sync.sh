#!/usr/bin/env bash
# Shared helpers for dedicated-server sync commands.

AI_STACK_DIR="${AI_STACK_DIR:-$(cat /etc/ai-stack/stack-dir 2>/dev/null || echo /opt/llm-vm-kit)}"
# shellcheck disable=SC1091
source "$AI_STACK_DIR/lib/env.sh"

ai_sync_die() {
  echo "ai-sync: $*" >&2
  exit 1
}

ai_sync_init() {
  [[ -n "${AI_SYNC_REMOTE_USER:-}" ]] || ai_sync_die "missing AI_SYNC_REMOTE_USER"
  [[ -n "${AI_SYNC_REMOTE_HOST:-}" ]] || ai_sync_die "missing AI_SYNC_REMOTE_HOST"
  [[ -n "${AI_SYNC_REMOTE_PORT:-}" ]] || AI_SYNC_REMOTE_PORT="22"
  [[ -n "${AI_SYNC_REMOTE_ROOT:-}" ]] || AI_SYNC_REMOTE_ROOT="/srv/ai-persistent"
  [[ -n "${AI_SYNC_SSH_KEY:-}" ]] || AI_SYNC_SSH_KEY="$HOME/.ssh/ai_sync_ed25519"
  [[ -n "${AI_SYNC_LOCAL_ROOT:-}" ]] || AI_SYNC_LOCAL_ROOT="/workspace"
  [[ -n "${AI_SYNC_AI_HOME:-}" ]] || AI_SYNC_AI_HOME="/workspace/ai"

  AI_SYNC_REMOTE_ROOT="${AI_SYNC_REMOTE_ROOT%/}"
  AI_SYNC_LOCAL_ROOT="${AI_SYNC_LOCAL_ROOT%/}"
  AI_SYNC_AI_HOME="${AI_SYNC_AI_HOME%/}"

  [[ "$AI_SYNC_REMOTE_ROOT" != *"'"* ]] || ai_sync_die "AI_SYNC_REMOTE_ROOT cannot contain single quotes"
  [[ "$AI_SYNC_REMOTE_PORT" =~ ^[0-9]+$ ]] || ai_sync_die "AI_SYNC_REMOTE_PORT must be numeric"
  [[ -f "$AI_SYNC_SSH_KEY" ]] || ai_sync_die "SSH key not found: $AI_SYNC_SSH_KEY"

  AI_SYNC_REMOTE="${AI_SYNC_REMOTE_USER}@${AI_SYNC_REMOTE_HOST}"
  AI_SYNC_SSH_CMD=(
    ssh
    -i "$AI_SYNC_SSH_KEY"
    -p "$AI_SYNC_REMOTE_PORT"
    -o StrictHostKeyChecking=accept-new
    -o ServerAliveInterval=15
    -o ServerAliveCountMax=3
  )

  printf -v AI_SYNC_RSYNC_SSH 'ssh -i %q -p %q -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=15 -o ServerAliveCountMax=3' \
    "$AI_SYNC_SSH_KEY" "$AI_SYNC_REMOTE_PORT"
}

ai_sync_build_rsync_args() {
  local enable_delete="${1:-0}"

  AI_SYNC_RSYNC_ARGS=(
    -aHAX
    --info=progress2
    --partial
    --human-readable
    --exclude '.git/lfs/tmp/'
    --exclude 'node_modules/'
    --exclude '.venv/'
    --exclude '__pycache__/'
    --exclude '.cache/'
    --exclude 'dist/'
    --exclude 'build/'
    --exclude 'target/'
    --exclude '*.gguf'
    --exclude '*.safetensors'
    --exclude '*.pt'
    --exclude '*.pth'
    --exclude '*.bin'
    -e "$AI_SYNC_RSYNC_SSH"
  )

  if [[ "$enable_delete" == "1" ]]; then
    AI_SYNC_RSYNC_ARGS+=(--delete)
  fi
}

ai_sync_local_dirs() {
  mkdir -p \
    "$AI_SYNC_LOCAL_ROOT/projects" \
    "$AI_SYNC_AI_HOME/datasets" \
    "$AI_SYNC_AI_HOME/outputs" \
    "$AI_SYNC_AI_HOME/opencode" \
    "$AI_SYNC_AI_HOME/hermes" \
    "$AI_SYNC_AI_HOME/persistent-config" \
    "$AI_SYNC_AI_HOME/models" \
    "$AI_SYNC_AI_HOME/llama-cache" \
    "$AI_SYNC_AI_HOME/logs"
}

ai_sync_validate_remote_root() {
  "${AI_SYNC_SSH_CMD[@]}" "$AI_SYNC_REMOTE" "test -d '$AI_SYNC_REMOTE_ROOT'"
}

ai_sync_remote_dirs() {
  "${AI_SYNC_SSH_CMD[@]}" "$AI_SYNC_REMOTE" \
    "mkdir -p '$AI_SYNC_REMOTE_ROOT'/projects '$AI_SYNC_REMOTE_ROOT'/datasets '$AI_SYNC_REMOTE_ROOT'/outputs '$AI_SYNC_REMOTE_ROOT'/config '$AI_SYNC_REMOTE_ROOT'/memory '$AI_SYNC_REMOTE_ROOT'/opencode '$AI_SYNC_REMOTE_ROOT'/hermes '$AI_SYNC_REMOTE_ROOT'/logs '$AI_SYNC_REMOTE_ROOT'/sync"
}

ai_sync_pull_dir() {
  local remote_subdir="$1"
  local local_dir="$2"

  mkdir -p "$local_dir"
  echo "Pulling ${remote_subdir}/ -> ${local_dir}/"
  rsync "${AI_SYNC_RSYNC_ARGS[@]}" \
    "${AI_SYNC_REMOTE}:${AI_SYNC_REMOTE_ROOT}/${remote_subdir}/" \
    "${local_dir%/}/"
}

ai_sync_push_dir() {
  local local_dir="$1"
  local remote_subdir="$2"

  mkdir -p "$local_dir"
  echo "Pushing ${local_dir}/ -> ${remote_subdir}/"
  rsync "${AI_SYNC_RSYNC_ARGS[@]}" \
    "${local_dir%/}/" \
    "${AI_SYNC_REMOTE}:${AI_SYNC_REMOTE_ROOT}/${remote_subdir}/"
}

ai_sync_strip_local_model() {
  local file="$1"
  local tmp

  [[ -f "$file" ]] || return 0
  tmp="$(mktemp)"
  grep -v '^AI_LOCAL_MODEL=' "$file" > "$tmp" || true
  mv "$tmp" "$file"
}

ai_sync_write_base_env() {
  local src="$1"
  local dest="$2"
  local tmp

  [[ -f "$src" ]] || return 0
  mkdir -p "$(dirname "$dest")"
  tmp="$(mktemp)"
  grep -v '^AI_LOCAL_MODEL=' "$src" > "$tmp" || true
  mv "$tmp" "$dest"
}
