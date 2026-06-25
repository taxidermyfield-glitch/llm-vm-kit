#!/usr/bin/env bash
set -euo pipefail

AI_STACK_DIR="${AI_STACK_DIR:-$(cat /etc/ai-stack/stack-dir 2>/dev/null || echo /opt/llm-vm-kit)}"
AI_ENV_FILE="${AI_ENV_FILE:-/etc/ai-stack/ai.env}"

if [[ -f "$AI_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$AI_ENV_FILE"
  set +a
fi

: "${AI_BACKEND:=llamacpp}"
: "${AI_HF_MODEL:=hf.co/cyberneurova/CyberNeurova-Kimi-K2.7-Code-UD-IQ2_M-abliterated-GGUF:UD-IQ2_M}"
: "${AI_LOCAL_MODEL:=}"
: "${AI_MODEL_QUANT:=UD-IQ2_M}"
: "${AI_MODEL:=local-ai}"
: "${AI_CONTEXT_LENGTH:=8192}"

: "${AI_HOME:=/workspace/ai}"
: "${AI_PROJECTS:=/workspace/projects}"
: "${AI_HERMES_HOME:=$AI_HOME/hermes}"
: "${AI_OPENCODE_HOME:=$AI_HOME/opencode}"
: "${OLLAMA_MODELS:=$AI_HOME/ollama/models}"

: "${AI_SYNC_REMOTE_USER:=}"
: "${AI_SYNC_REMOTE_HOST:=}"
: "${AI_SYNC_REMOTE_PORT:=22}"
: "${AI_SYNC_REMOTE_ROOT:=/srv/ai-persistent}"
: "${AI_SYNC_SSH_KEY:=$HOME/.ssh/ai_sync_ed25519}"
: "${AI_SYNC_LOCAL_ROOT:=/workspace}"
: "${AI_SYNC_AI_HOME:=$AI_HOME}"
: "${AI_SYNC_DELETE:=0}"
: "${AI_AUTO_SYNC_FROM_SERVER:=0}"
: "${AI_REQUIRE_SYNC_CONFIG:=1}"

: "${AI_LLAMA_HOST:=127.0.0.1}"
: "${AI_LLAMA_PORT:=18080}"
: "${AI_OPENAI_BASE_URL:=http://${AI_LLAMA_HOST}:${AI_LLAMA_PORT}/v1}"
: "${AI_LLAMA_NGL:=999}"
: "${AI_LLAMA_SPLIT_MODE:=layer}"
: "${AI_LLAMA_EXTRA_ARGS:=--jinja}"

: "${AI_AUTO_BROWSER:=1}"
: "${AI_BROWSER_CDP_URL:=}"
: "${AI_AGENT_TOOLSETS:=hermes-cli}"
: "${AI_TERMINAL_TIMEOUT:=180}"
: "${AI_APPROVAL_MODE:=manual}"
: "${AI_WEB_SEARCH_BACKEND:=ddgs}"
: "${AI_WEB_EXTRACT_BACKEND:=}"

export AI_STACK_DIR AI_ENV_FILE
export AI_BACKEND AI_HF_MODEL AI_LOCAL_MODEL AI_MODEL_QUANT AI_MODEL AI_CONTEXT_LENGTH
export AI_HOME AI_PROJECTS AI_HERMES_HOME AI_OPENCODE_HOME OLLAMA_MODELS
export AI_SYNC_REMOTE_USER AI_SYNC_REMOTE_HOST AI_SYNC_REMOTE_PORT AI_SYNC_REMOTE_ROOT AI_SYNC_SSH_KEY
export AI_SYNC_LOCAL_ROOT AI_SYNC_AI_HOME AI_SYNC_DELETE AI_AUTO_SYNC_FROM_SERVER AI_REQUIRE_SYNC_CONFIG
export AI_LLAMA_HOST AI_LLAMA_PORT AI_OPENAI_BASE_URL AI_LLAMA_NGL AI_LLAMA_SPLIT_MODE AI_LLAMA_EXTRA_ARGS
export AI_AUTO_BROWSER AI_BROWSER_CDP_URL AI_AGENT_TOOLSETS AI_TERMINAL_TIMEOUT AI_APPROVAL_MODE
export AI_WEB_SEARCH_BACKEND AI_WEB_EXTRACT_BACKEND
export HERMES_HOME="$AI_HERMES_HOME"
export PATH="/usr/local/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.hermes/bin:$HOME/.opencode/bin:$PATH"

ai_openai_url() {
  echo "${AI_OPENAI_BASE_URL%/}"
}

ai_llama_model_ref() {
  local ref="$AI_HF_MODEL"
  ref="${ref#hf.co/}"
  ref="${ref#https://huggingface.co/}"
  echo "$ref"
}
