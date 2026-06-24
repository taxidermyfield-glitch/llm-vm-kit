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

for key in AI_BACKEND AI_HF_MODEL AI_MODEL AI_CONTEXT_LENGTH AI_HOME AI_PROJECTS OLLAMA_MODELS AI_HERMES_HOME AI_OPENCODE_HOME OLLAMA_HOST AI_AGENT_TOOLSETS AI_TERMINAL_TIMEOUT AI_APPROVAL_MODE AI_BROWSER_CDP_URL AI_WEB_SEARCH_BACKEND AI_WEB_EXTRACT_BACKEND; do
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


find_nvcc() {
  local nvcc_path

  nvcc_path="$(command -v nvcc 2>/dev/null || true)"
  if [[ -n "$nvcc_path" ]]; then
    echo "$nvcc_path"
    return 0
  fi

  nvcc_path="$(find /usr/local/cuda* -path '*/bin/nvcc' -type f 2>/dev/null | sort -V | tail -n 1 || true)"
  if [[ -n "$nvcc_path" ]]; then
    echo "$nvcc_path"
    return 0
  fi

  return 1
}

install_cuda_compiler() {
  if find_nvcc >/dev/null 2>&1; then
    echo "CUDA compiler already available: $(find_nvcc)"
    return 0
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "apt-get not found and nvcc is missing. Use a CUDA devel image/template." >&2
    return 1
  fi

  echo "Installing CUDA compiler / nvcc..."
  $SUDO apt-get update
  $SUDO apt-get install -y ca-certificates curl gnupg build-essential cmake pkg-config ccache

  # Prefer CUDA 13 packages when available, then CUDA 12.8, then toolkit fallbacks.
  if apt-cache show cuda-nvcc-13-0 >/dev/null 2>&1; then
    $SUDO apt-get install -y cuda-nvcc-13-0 cuda-cudart-dev-13-0 libcublas-dev-13-0
  elif apt-cache show cuda-toolkit-13-0 >/dev/null 2>&1; then
    $SUDO apt-get install -y cuda-toolkit-13-0
  elif apt-cache show cuda-nvcc-12-8 >/dev/null 2>&1; then
    $SUDO apt-get install -y cuda-nvcc-12-8 cuda-cudart-dev-12-8 libcublas-dev-12-8
  elif apt-cache show cuda-toolkit-12-8 >/dev/null 2>&1; then
    $SUDO apt-get install -y cuda-toolkit-12-8
  elif apt-cache show nvidia-cuda-toolkit >/dev/null 2>&1; then
    $SUDO apt-get install -y nvidia-cuda-toolkit
  else
    echo "No CUDA compiler package found in apt." >&2
    echo "This VM likely uses a CUDA runtime image instead of a CUDA devel image." >&2
    echo "Use a CUDA/PyTorch devel template or manually install NVIDIA CUDA toolkit." >&2
    return 1
  fi

  if ! find_nvcc >/dev/null 2>&1; then
    echo "nvcc still not found after CUDA compiler install." >&2
    echo "Debug:" >&2
    echo "  find /usr/local/cuda* -path '*/bin/nvcc' -type f" >&2
    find /usr/local/cuda* -path '*/bin/nvcc' -type f 2>/dev/null || true
    return 1
  fi

  echo "Installed CUDA compiler: $(find_nvcc)"
  "$(find_nvcc)" --version
}

install_llama_cpp() {
  if command -v llama-server >/dev/null 2>&1; then
    echo "llama-server already installed: $(command -v llama-server)"
    return 0
  fi

  install_cuda_compiler

  local nvcc_path
  nvcc_path="$(find_nvcc)"

  export CUDACXX="$nvcc_path"
  export CUDA_HOME="$(dirname "$(dirname "$nvcc_path")")"
  export PATH="$CUDA_HOME/bin:$PATH"
  export LD_LIBRARY_PATH="$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}"

  echo "Building llama.cpp with CUDA..."
  echo "CUDACXX=$CUDACXX"
  echo "CUDA_HOME=$CUDA_HOME"

  $SUDO apt-get update
  $SUDO apt-get install -y git cmake build-essential curl libcurl4-openssl-dev pkg-config ccache

  $SUDO mkdir -p /opt

  if [[ -d /opt/llama.cpp/.git ]]; then
    echo "Updating existing /opt/llama.cpp..."
    $SUDO git -C /opt/llama.cpp pull --ff-only || true
  else
    echo "Cloning llama.cpp..."
    $SUDO rm -rf /opt/llama.cpp
    $SUDO git clone https://github.com/ggml-org/llama.cpp.git /opt/llama.cpp
  fi

  if [[ -n "${RUN_USER:-}" && "$RUN_USER" != "root" ]]; then
    $SUDO chown -R "$RUN_USER:$RUN_GROUP" /opt/llama.cpp || true
  fi

  cd /opt/llama.cpp

  rm -rf build

  cmake -B build \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_COMPILER="$nvcc_path" \
    -DCMAKE_BUILD_TYPE=Release

  cmake --build build --config Release -j"$(nproc)"

  $SUDO ln -sf /opt/llama.cpp/build/bin/llama-server /usr/local/bin/llama-server

  cd "$STACK_DIR"

  echo "llama.cpp CUDA build complete."
  llama-server --help | head -20 || true
}

install_llama_cpp



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

echo "Skipping Ollama install/start; llama.cpp is the default backend."

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

echo "Configuring llama.cpp backend..."
ai-configure

if [[ "${AI_SKIP_PULL:-0}" != "1" ]]; then
  echo "Starting llama.cpp model server..."
  ai-pull
else
  echo "Skipping model server start/download because AI_SKIP_PULL=1"
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
