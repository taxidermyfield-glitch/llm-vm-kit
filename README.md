# llm-vm-kit

Disposable GPU VM setup for local LLM chat, coding, agent work, and durable sync to a dedicated storage server.

The intended pattern is:

1. Keep the GPU VM disposable.
2. Keep projects, configs, memory, outputs, OpenCode state, and Hermes state on dedicated storage.
3. Keep large model files VM-local, so every fresh GPU VM pulls the selected model for itself.

Default model preset:

```text
mid-range  -> Llama 3.3 70B GGUF through llama.cpp, 32K context
```

Alternate max-power preset:

```text
max-power  -> NousResearch/Hermes-3-Llama-3.1-405B through vLLM, 128K context
```

The 405B preset is intentionally guarded. It is a huge full-weight model and should only be selected on very large multi-GPU or multi-node hardware.

---

# Mental model

There are three separate layers:

```text
Git repo
  Installer scripts and commands. Clone this on each VM.

Dedicated storage server
  Durable source of truth for projects, datasets, outputs, memory, prompts, and base config.

GPU VM
  Disposable machine that installs dependencies, downloads the selected model locally, runs chat/code/agent tools, then syncs state back.
```

Important config files:

```text
/workspace/ai/ai.env
  Active VM config. ai-model updates this file.

/workspace/ai/persistent-config/ai.env.base
  Synced base config. ai-sync-to-server writes this from ai.env with AI_LOCAL_MODEL removed.

config/ai-sync.env
  Local-only SSH settings for reaching the dedicated server. Do not commit it.

config/ai.env.example
  Template for the initial synced base config.
```

`bootstrap.sh` does not run sync. Sync first, choose the desired preset if needed, then bootstrap. Bootstrap installs requirements and pulls/starts the model selected in `/workspace/ai/ai.env`.

---

# Fresh GPU VM workflow

Do this each time you create a new Vast or other GPU VM. These commands assume you are logged in as `root`, which is the simplest path on most disposable GPU rentals.

Install the small set of tools needed before bootstrap:

```bash
apt-get update
apt-get install -y git rsync openssh-client python3 nano
mkdir -p /workspace /opt
```

Install the private SSH key for sync:

```bash
install -m 700 -d ~/.ssh
nano ~/.ssh/ai_sync_ed25519
chmod 600 ~/.ssh/ai_sync_ed25519
```

Test SSH:

```bash
ssh -i ~/.ssh/ai_sync_ed25519 ai@DEDICATED_IP 'echo sync-ok'
```

Clone the toolkit:

```bash
git clone https://github.com/taxidermyfield-glitch/llm-vm-kit.git /opt/llm-vm-kit
cd /opt/llm-vm-kit
```

Create the VM-local sync env:

```bash
cp config/ai-sync.env.example config/ai-sync.env
nano config/ai-sync.env
```

Set these values:

```bash
AI_SYNC_REMOTE_USER="ai"
AI_SYNC_REMOTE_HOST="DEDICATED_IP"
AI_SYNC_REMOTE_PORT="22"
AI_SYNC_REMOTE_ROOT="/srv/ai-persistent"
AI_SYNC_SSH_KEY="/root/.ssh/ai_sync_ed25519"
AI_SYNC_LOCAL_ROOT="/workspace"
AI_SYNC_AI_HOME="/workspace/ai"
```

Pull durable state and config from the dedicated server:

```bash
bin/ai-sync-from-server
```

Optional: switch model preset before bootstrap pulls anything:

```bash
bin/ai-model mid-range
bin/ai-model max-power
```

For `max-power`, read the warning and type `405B` when prompted. For non-interactive scripts, use `--yes`.

If you changed the preset and want future VMs to inherit it:

```bash
bin/ai-sync-to-server
```

Install dependencies and pull/start the selected model:

```bash
bash bootstrap.sh
```

Bootstrap requires the selected backend and attempts to install the other built-in backend too, so later preset switches are easier. It only downloads the currently selected model. If optional backend install fails, switch presets first and rerun `bash bootstrap.sh` on that VM.

Check the machine:

```bash
ai-status
ai-chat "Say hello from the selected local model."
```

---

# Model presets

Use `ai-model` to inspect or change model config:

```bash
ai-model
ai-model --list-presets
ai-model mid-range
ai-model max-power
ai-model hf.co/OWNER/GGUF-REPO:Q4_K_M
ai-model --backend vllm OWNER/REPO
```

By default, `ai-model` only updates config. It does not download or restart a model server.

To change config and immediately apply it on an already bootstrapped VM:

```bash
ai-model mid-range --pull
ai-model max-power --pull
```

Preset source of truth:

```text
bin/ai-model
```

The built-in preset blocks in that file update `/workspace/ai/ai.env`.

Current built-in values:

```text
mid-range
  AI_MODEL_PRESET="llama-3.3-70b"
  AI_BACKEND="llamacpp"
  AI_HF_MODEL="hf.co/bartowski/Llama-3.3-70B-Instruct-abliterated-GGUF:Q4_K_M"
  AI_MODEL_QUANT="Q4_K_M"
  AI_CONTEXT_LENGTH="32768"

max-power
  AI_MODEL_PRESET="hermes-3-llama-3.1-405b"
  AI_BACKEND="vllm"
  AI_HF_MODEL="NousResearch/Hermes-3-Llama-3.1-405B"
  AI_CONTEXT_LENGTH="131072"
  AI_VLLM_TENSOR_PARALLEL_SIZE="16"
  AI_VLLM_DTYPE="bfloat16"
```

After changing a preset, run this if the dedicated server should remember it:

```bash
ai-sync-to-server
```

Model files are intentionally not synced. `AI_LOCAL_MODEL` is stripped from synced config because it points to a VM-local downloaded file.

---

# Sync workflow

Before work, pull the latest dedicated-server state:

```bash
ai-sync-status from-server
ai-sync-from-server
```

After work, push durable changes back:

```bash
ai-sync-status to-server
ai-sync-to-server
```

Run `ai-sync-to-server` after changing any durable state:

```text
model preset
system prompt
manual shared memory
projects
datasets
outputs
OpenCode state
Hermes state
```

Synced paths:

```text
/workspace/projects/              <-> /srv/ai-persistent/projects/
/workspace/ai/datasets/           <-> /srv/ai-persistent/datasets/
/workspace/ai/outputs/            <-> /srv/ai-persistent/outputs/
/workspace/ai/opencode/           <-> /srv/ai-persistent/opencode/
/workspace/ai/hermes/             <-> /srv/ai-persistent/hermes/
/workspace/ai/persistent-config/  <-> /srv/ai-persistent/config/
```

The dedicated server schema is fixed to this top-level layout:

```text
projects/
datasets/
outputs/
config/
memory/
opencode/
hermes/
logs/
sync/
```

Future toolkit changes should store durable state inside those existing directories, usually under `config/` for new settings. That keeps server setup stable; updates should only require pulling a newer repo on the GPU VM.

Not synced:

```text
model weights: *.gguf, *.safetensors, *.pt, *.pth, *.bin
/workspace/ai/models/
/workspace/ai/llama-cache/
node_modules, build outputs, Python caches, virtualenvs
```

`AI_SYNC_DELETE=0` is the default and safest mode. Set `AI_SYNC_DELETE=1` only when you intentionally want rsync delete behavior.

---

# Chat, coding, and agent commands

Show all installed toolkit commands:

```bash
ai-help
```

Chat with the selected local model:

```bash
ai-chat
ai-chat "Summarize this repo."
```

Run OpenCode against a project:

```bash
cd /workspace/projects/my-project
ai-code
ai-code "Fix the failing tests."
```

Run Hermes Agent:

```bash
ai-agent
ai-agent "Inspect /workspace/projects/my-project and report risks."
```

Browser automation for Hermes:

```bash
ai-browser-start
ai-browser-reset
```

Server controls:

```bash
ai-pull          # download/start selected backend
ai-server-start
ai-server-stop
ai-llama-start
ai-llama-stop
ai-vllm-start
ai-vllm-stop
```

Diagnostics:

```bash
ai-status
```

Manual shared memory:

```bash
ai-memory show
ai-memory add "User prefers sync-first bootstrap workflows."
ai-memory edit 1 "Updated memory text."
ai-memory remove 1
ai-memory clear
```

---

# System prompt and shared memory

System prompt:

```bash
set-system-prompt "You are concise, careful, and direct."
set-system-prompt --show
set-system-prompt --clear
```

Manual shared memory details:

```bash
ai-memory show
ai-memory add "User prefers sync-first bootstrap workflows."
ai-memory edit 1 "Updated memory text."
ai-memory remove 1
ai-memory clear
ai-memory path
```

Memory is manual by design. The toolkit does not automatically write memories from chats. `ai-chat` injects approved bullet items from:

```text
/workspace/ai/persistent-config/memory/active.md
```

Hermes Agent also keeps its own state under:

```text
/workspace/ai/hermes/
```

Both are synced through the dedicated server when you run `ai-sync-to-server`.

---

# Updating the toolkit

On a VM:

```bash
cd /opt/llm-vm-kit
git pull --ff-only
bash bootstrap.sh
```

If you changed durable config or state before updating:

```bash
ai-sync-to-server
git pull --ff-only
bin/ai-sync-from-server
bash bootstrap.sh
```

---

# Troubleshooting

Bootstrap says `/workspace/ai/ai.env` is missing:

```bash
cd /opt/llm-vm-kit
bin/ai-sync-from-server
bash bootstrap.sh
```

If the dedicated server is new, create `/srv/ai-persistent/config/ai.env.base` first.

Sync SSH fails:

```bash
chmod 600 ~/.ssh/ai_sync_ed25519
ssh -i ~/.ssh/ai_sync_ed25519 ai@DEDICATED_IP 'echo ok'
cat config/ai-sync.env
```

Model pull fails:

```bash
ai-status
ai-server-stop
ai-pull
```

For private Hugging Face models, log in first:

```bash
hf auth login
```

`ai-chat` is slow:

```bash
ai-model mid-range --pull
```

Or lower `AI_CONTEXT_LENGTH` in `/workspace/ai/ai.env`, then restart:

```bash
ai-server-stop
ai-pull
```

405B fails to start:

```text
This usually means the VM does not have enough aggregate VRAM for the model, KV cache, and runtime overhead.
Use mid-range, lower context, or move to a much larger multi-GPU or multi-node setup.
```

Ran `ai-code` in the wrong directory:

```bash
Ctrl+C
cd /workspace/projects/your-project
ai-code
```

---

# Security notes

Do not commit these:

```text
config/ai-sync.env
private SSH keys
Hugging Face tokens
project secrets
```

The dedicated server is the durable source of truth. Back it up like you would any important development machine.

Before deleting a VM:

```bash
ai-sync-status to-server
ai-sync-to-server
```

---

# Dedicated server setup

Do this once on the storage server.

Install the basic server tools:

```bash
sudo apt-get update
sudo apt-get install -y openssh-server rsync
```

Create a user and storage root:

```bash
sudo adduser ai
sudo mkdir -p /srv/ai-persistent/{projects,datasets,outputs,config,memory,opencode,hermes,logs,sync}
sudo chown -R ai:ai /srv/ai-persistent
sudo chmod 750 /srv/ai-persistent
```

Install the public SSH key that the GPU VMs will use:

```bash
sudo -u ai mkdir -p /home/ai/.ssh
sudo -u ai nano /home/ai/.ssh/authorized_keys
sudo chmod 700 /home/ai/.ssh
sudo chmod 600 /home/ai/.ssh/authorized_keys
```

Only the public key goes in `authorized_keys`. The matching private key lives on each GPU VM, usually at:

```text
~/.ssh/ai_sync_ed25519
```

The private key should not live in the GitHub repo.

Create the initial synced model/config preset:

```bash
sudo -u ai nano /srv/ai-persistent/config/ai.env.base
```

Start with the mid-range default:

```bash
AI_MODEL_PRESET="llama-3.3-70b"
AI_BACKEND="llamacpp"
AI_HF_MODEL="hf.co/bartowski/Llama-3.3-70B-Instruct-abliterated-GGUF:Q4_K_M"
AI_MODEL_QUANT="Q4_K_M"
AI_MODEL="local-ai"
AI_CONTEXT_LENGTH="32768"
AI_OPENAI_BASE_URL="http://127.0.0.1:18080/v1"

AI_HOME="/workspace/ai"
AI_PROJECTS="/workspace/projects"
AI_HERMES_HOME="/workspace/ai/hermes"
AI_OPENCODE_HOME="/workspace/ai/opencode"
AI_SYSTEM_PROMPT_FILE="/workspace/ai/persistent-config/system-prompt.txt"
AI_MEMORY_FILE="/workspace/ai/persistent-config/memory/active.md"
```

That file is the dedicated server's base config. Fresh VMs pull it down as `/workspace/ai/ai.env`.
