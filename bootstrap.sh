#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive

STACK_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
AI_HOME="${AI_HOME:-/workspace/ai}"
AI_ENV_FILE="${AI_ENV_FILE:-$AI_HOME/ai.env}"

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
else
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "bootstrap.sh must run as root or as a sudo-capable user." >&2
    exit 1
  fi
fi

RUN_USER="${SUDO_USER:-${USER:-root}}"
if [[ "$RUN_USER" == "root" ]]; then
  RUN_GROUP="root"
else
  RUN_GROUP="$(id -gn "$RUN_USER" 2>/dev/null || echo "$RUN_USER")"
fi

set_env_value() {
  local file="$1" key="$2" value="$3"
  python3 - "$file" "$key" "$value" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
key = sys.argv[2]
value = sys.argv[3]
line = f'{key}="{value}"'

lines = path.read_text().splitlines() if path.exists() else []
out = []
found = False

for existing in lines:
    if existing.startswith(f"{key}="):
        out.append(line)
        found = True
    else:
        out.append(existing)

if not found:
    out.append(line)

path.write_text("\n".join(out) + "\n")
PY
}

$SUDO mkdir -p "$AI_HOME" /workspace/projects /etc/ai-stack
echo "$STACK_DIR" | $SUDO tee /etc/ai-stack/stack-dir >/dev/null

if [[ ! -f "$AI_ENV_FILE" ]]; then
  $SUDO cp "$STACK_DIR/config/ai.env.example" "$AI_ENV_FILE"
fi

for key in AI_HF_MODEL AI_MODEL AI_CONTEXT_LENGTH AI_HOME AI_PROJECTS OLLAMA_MODELS AI_HERMES_HOME AI_OPENCODE_HOME OLLAMA_HOST AI_AGENT_TOOLSETS AI_TERMINAL_TIMEOUT AI_APPROVAL_MODE AI_BROWSER_CDP_URL AI_WEB_SEARCH_BACKEND AI_WEB_EXTRACT_BACKEND; do
  if [[ -n "${!key:-}" ]]; then
    set_env_value "$AI_ENV_FILE" "$key" "${!key}"
  fi
done

$SUDO ln -sf "$AI_ENV_FILE" /etc/ai-stack/ai.env

# shellcheck disable=SC1091
source "$STACK_DIR/lib/env.sh"

$SUDO mkdir -p \
  "$AI_HOME" \
  "$AI_PROJECTS" \
  "$OLLAMA_MODELS" \
  "$AI_HERMES_HOME" \
  "$AI_OPENCODE_HOME" \
  "$AI_HOME/logs"

if command -v apt-get >/dev/null 2>&1; then
  echo "Installing system packages..."
  $SUDO apt-get update
  $SUDO apt-get install -y \
    ca-certificates curl git jq rsync tar unzip xz-utils gnupg lsb-release \
    build-essential pkg-config \
    python3 python3-pip python3-venv pipx \
    tmux htop nvtop ripgrep fd-find \
    lsof net-tools procps

  # Browser support for Hermes browser automation.
  $SUDO apt-get install -y chromium || $SUDO apt-get install -y chromium-browser || true

  if ! command -v google-chrome >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1 && ! command -v chromium-browser >/dev/null 2>&1; then
    echo "Installing Google Chrome for Hermes browser automation..."
    tmp_chrome="/tmp/google-chrome-stable_current_amd64.deb"
    curl -fsSL -o "$tmp_chrome" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    $SUDO apt-get install -y "$tmp_chrome"
  fi
else
  echo "apt-get not found; skipping OS package install."
fi

install_node() {
  if command -v node >/dev/null 2>&1; then
    local major
    major="$(node -v | sed 's/^v//' | cut -d. -f1)"
    if [[ "$major" -ge 20 ]]; then
      return 0
    fi
  fi

  if command -v apt-get >/dev/null 2>&1; then
    echo "Installing Node.js 22..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | $SUDO bash -
    $SUDO apt-get install -y nodejs
  else
    echo "Node.js >=20 not found and apt-get is unavailable." >&2
    return 1
  fi
}

install_uv() {
  if command -v uv >/dev/null 2>&1 && command -v uvx >/dev/null 2>&1; then
    return 0
  fi

  if command -v pipx >/dev/null 2>&1; then
    echo "Installing uv/uvx for Python-based MCP servers..."
    pipx install uv || pipx upgrade uv || true
    export PATH="$HOME/.local/bin:$PATH"
  fi
}

install_node
install_uv

install_browser_support() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "apt-get not found; skipping browser package install."
    return 0
  fi

  browser_ok=0

  for candidate in /usr/bin/google-chrome /usr/bin/google-chrome-stable /opt/google/chrome/google-chrome /usr/bin/chromium; do
    if [[ -x "$candidate" ]]; then
      version_output="$("$candidate" --version 2>&1 || true)"
      if [[ -n "$version_output" ]] && ! echo "$version_output" | grep -qiE 'snap|requires the chromium snap|command .* requires'; then
        browser_ok=1
        break
      fi
    fi
  done

  if [[ "$browser_ok" == "1" ]]; then
    return 0
  fi

  echo "Installing real Google Chrome for Hermes browser automation..."
  $SUDO apt-get update
  $SUDO apt-get install -y curl ca-certificates fonts-liberation xdg-utils

  tmp_chrome="/tmp/google-chrome-stable_current_amd64.deb"
  curl -fsSL -o "$tmp_chrome" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  $SUDO apt-get install -y "$tmp_chrome"
}

install_browser_support

if ! command -v ollama >/dev/null 2>&1; then
  echo "Installing Ollama..."
  curl -fsSL https://ollama.com/install.sh | sh
fi

if command -v systemctl >/dev/null 2>&1; then
  $SUDO systemctl stop ollama 2>/dev/null || true
  $SUDO systemctl disable ollama 2>/dev/null || true
fi
pkill -x ollama 2>/dev/null || true

if ! command -v opencode >/dev/null 2>&1; then
  echo "Installing OpenCode..."
  export OPENCODE_INSTALL_DIR="/usr/local/bin"
  curl -fsSL https://opencode.ai/install | bash || $SUDO npm install -g opencode-ai
fi

if ! command -v hermes >/dev/null 2>&1; then
  echo "Installing Hermes Agent..."
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup
  export PATH="/usr/local/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.hermes/bin:$PATH"
fi

if [[ "$RUN_USER" != "root" ]]; then
  $SUDO chown -R "$RUN_USER:$RUN_GROUP" "$AI_HOME" "$AI_PROJECTS" || true
fi

touch "$AI_HERMES_HOME/.env"
chmod 600 "$AI_HERMES_HOME/.env" || true

if [[ "$RUN_USER" != "root" ]]; then
  $SUDO chown "$RUN_USER:$RUN_GROUP" "$AI_HERMES_HOME/.env" || true
fi

echo "Installing ai-* commands..."
for f in "$STACK_DIR"/bin/ai-*; do
  $SUDO install -m 0755 "$f" "/usr/local/bin/$(basename "$f")"
done

hash -r

echo "Configuring tools..."
ai-configure

echo "Starting Ollama..."
ai-ollama-start

if [[ "${AI_SKIP_PULL:-0}" != "1" ]]; then
  echo "Pulling and aliasing model..."
  ai-pull
else
  echo "Skipping model pull because AI_SKIP_PULL=1"
fi

ai-status

cat <<'MSG'

Installed.

Main commands:
  ai-chat                 local chat through Ollama
  ai-code                 repo coding agent through OpenCode
  ai-agent                autonomous worker through Hermes
  ai-model                show or change the Hugging Face GGUF model
  ai-pull                 pull current HF model and rebuild local alias
  ai-status               inspect GPU, tools, config, and Ollama state
  ai-browser-start        optional local browser automation helper
  ai-backup               archive /workspace/ai and /workspace/projects

Main config:
  /workspace/ai/ai.env

MSG
