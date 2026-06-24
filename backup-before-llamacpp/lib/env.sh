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

: "${AI_HF_MODEL:=hf.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF:Q4_K_M}"
: "${AI_MODEL:=local-ai}"
: "${AI_CONTEXT_LENGTH:=64000}"

: "${AI_HOME:=/workspace/ai}"
: "${AI_PROJECTS:=/workspace/projects}"
: "${OLLAMA_MODELS:=$AI_HOME/ollama/models}"
: "${AI_HERMES_HOME:=$AI_HOME/hermes}"
: "${AI_OPENCODE_HOME:=$AI_HOME/opencode}"

: "${OLLAMA_HOST:=127.0.0.1:11434}"
: "${AI_AGENT_TOOLSETS:=hermes-cli}"
: "${AI_TERMINAL_TIMEOUT:=180}"
: "${AI_APPROVAL_MODE:=manual}"
: "${AI_BROWSER_CDP_URL:=}"
: "${AI_AUTO_BROWSER:=1}"
: "${AI_WEB_SEARCH_BACKEND:=ddgs}"
: "${AI_WEB_EXTRACT_BACKEND:=}"

export AI_STACK_DIR AI_ENV_FILE
export AI_HF_MODEL AI_MODEL AI_CONTEXT_LENGTH
export AI_HOME AI_PROJECTS OLLAMA_MODELS AI_HERMES_HOME AI_OPENCODE_HOME
export OLLAMA_HOST AI_AGENT_TOOLSETS AI_TERMINAL_TIMEOUT AI_APPROVAL_MODE
export AI_BROWSER_CDP_URL AI_AUTO_BROWSER AI_WEB_SEARCH_BACKEND AI_WEB_EXTRACT_BACKEND
export HERMES_HOME="$AI_HERMES_HOME"
export PATH="/usr/local/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.hermes/bin:$HOME/.opencode/bin:$PATH"

ai_ollama_url() {
  echo "http://${OLLAMA_HOST}"
}

ai_ollama_openai_url() {
  echo "http://${OLLAMA_HOST}/v1"
}
