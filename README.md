# llm-vm-kit

`llm-vm-kit` is a portable setup kit for turning a fresh Ubuntu/CUDA GPU rental VM into a local AI workstation.

After installation, you get three main commands:

```bash
ai-chat     # local ChatGPT-style terminal chat
ai-code     # coding agent for working inside software repos
ai-agent    # autonomous Hermes worker with browser, terminal, memory, and tool use
```

The intended workflow:

```text
Rent a fresh CUDA VM
→ clone this repo
→ run bootstrap.sh
→ pull one Hugging Face GGUF model
→ use ai-chat, ai-code, and ai-agent from anywhere in the terminal
```

The VM is disposable. The setup logic lives in this repo. Runtime state, downloaded models, Hermes memory, browser state, and working projects live under `/workspace`.

---

# 1. What this project does

This project gives you a repeatable local-AI machine setup.

Instead of manually setting up Ollama, OpenCode, Hermes, browser automation, model paths, configs, and shell commands every time you rent a GPU VM, this repo does it with one installer:

```bash
sudo bash bootstrap.sh
```

After installation, these commands are available globally:

```bash
ai-chat
ai-code
ai-agent
ai-model
ai-pull
ai-status
ai-configure
ai-ollama-start
ai-ollama-stop
ai-browser-start
ai-browser-reset
ai-backup
```

The three main modes are:

```text
ai-chat   = simple local chat, like a terminal ChatGPT window
ai-code   = repo-focused coding agent using OpenCode
ai-agent  = autonomous worker using Hermes Agent with tools/browser/memory
```

---

# 2. What gets installed

The installer configures:

```text
Ollama        local model server
OpenCode      coding agent
Hermes Agent  autonomous terminal/browser/tool agent
Node.js       needed for JS tools and MCP servers
uv / uvx      useful for Python MCP servers
Google Chrome headless browser automation for Hermes
```

It also creates persistent runtime folders:

```text
/workspace/ai
/workspace/projects
```

---

# 3. Directory layout

The setup repo is usually cloned here:

```bash
/opt/llm-vm-kit
```

During development, it may be here:

```bash
~/llm-vm-kit
```

Runtime files live here:

```text
/workspace/ai/ai.env             main config file
/workspace/ai/ollama/models      downloaded Ollama models
/workspace/ai/hermes             Hermes config, memory, sessions, env
/workspace/ai/opencode           OpenCode config
/workspace/ai/logs               Ollama and browser logs
/workspace/projects              your actual project repos
```

Use `/workspace/projects` for normal work.

Do not use the `llm-vm-kit` setup repo itself as your normal coding workspace.

Correct:

```bash
cd /workspace/projects/my-project
ai-code
```

Wrong:

```bash
cd ~/llm-vm-kit
ai-code
```

---

# 4. Fresh VM install

Start with a fresh Ubuntu/CUDA/PyTorch-style GPU rental VM.

Install basic tools:

```bash
sudo apt-get update
sudo apt-get install -y git curl ca-certificates
```

Clone this repo:

```bash
git clone https://github.com/YOUR_USERNAME/llm-vm-kit.git /opt/llm-vm-kit
cd /opt/llm-vm-kit
```

Run the installer:

```bash
sudo bash bootstrap.sh
```

This will:

```text
install system packages
install Node.js
install Ollama
install OpenCode
install Hermes Agent
install Google Chrome for browser automation
install the ai-* commands into /usr/local/bin
create /workspace/ai/ai.env
start Ollama
pull the configured Hugging Face GGUF model
create the local Ollama alias called local-ai
```

After install:

```bash
ai-status
```

---

# 5. Fast install test without model download

Model downloads can take a while. To test the installer quickly without pulling a model:

```bash
cd /opt/llm-vm-kit
sudo AI_SKIP_PULL=1 bash bootstrap.sh
```

Then later pull the model:

```bash
ai-pull
```

---

# 6. Install with a custom model immediately

You can override the default model during install:

```bash
sudo AI_HF_MODEL="hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:Q4_K_M" bash bootstrap.sh
```

You can also set context length during install:

```bash
sudo AI_HF_MODEL="hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:Q4_K_M" \
     AI_CONTEXT_LENGTH="8192" \
     bash bootstrap.sh
```

---

# 7. Main config file

The main config file is:

```bash
/workspace/ai/ai.env
```

View it:

```bash
cat /workspace/ai/ai.env
```

Edit it:

```bash
sudo nano /workspace/ai/ai.env
```

Save in nano:

```text
Ctrl+O
Enter
Ctrl+X
```

Important lines:

```bash
AI_HF_MODEL="hf.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF:Q4_K_M"
AI_MODEL="local-ai"
AI_CONTEXT_LENGTH="64000"
AI_AUTO_BROWSER="1"
AI_BROWSER_CDP_URL="http://127.0.0.1:9222"
```

Meaning:

```text
AI_HF_MODEL         Hugging Face GGUF model to pull
AI_MODEL            local Ollama alias used by all commands
AI_CONTEXT_LENGTH   context window size
AI_AUTO_BROWSER     whether ai-agent auto-starts headless Chrome
AI_BROWSER_CDP_URL  local Chrome DevTools browser endpoint
```

Normally leave this unchanged:

```bash
AI_MODEL="local-ai"
```

Usually you only edit:

```bash
AI_HF_MODEL
AI_CONTEXT_LENGTH
```

---

# 8. Hugging Face model format

This toolkit uses Ollama.

When using Hugging Face, the model must be an Ollama-compatible **GGUF** model.

Correct format:

```bash
hf.co/OWNER/REPO:QUANT
```

Examples:

```bash
hf.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF:Q4_K_M
hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:Q4_K_M
hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:Q6_K
hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:Q8_0
hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:BF16
```

Incorrect:

```bash
HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive
```

Correct:

```bash
hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:Q4_K_M
```

If a short quant tag does not work, use the exact `.gguf` filename from the Hugging Face file list:

```bash
hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:Qwen3.5-9B-Uncensored-HauhauCS-Aggressive-Q4_K_M.gguf
```

---

# 9. How to choose a Hugging Face GGUF model

On a Hugging Face model page, look for downloadable files ending in:

```text
.gguf
```

Common examples:

```text
model-Q4_K_M.gguf
model-Q5_K_M.gguf
model-Q6_K.gguf
model-Q8_0.gguf
model-BF16.gguf
```

Use the quantization after the final dash.

Example file:

```text
Qwen3.5-9B-Uncensored-HauhauCS-Aggressive-Q4_K_M.gguf
```

Use:

```bash
:Q4_K_M
```

Full model string:

```bash
hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:Q4_K_M
```

If you see a table like this:

```text
BF16     17 GB
Q8_0     8.9 GB
Q6_K     6.9 GB
Q4_K_M   5.3 GB
```

then valid model strings are:

```bash
hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:BF16
hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:Q8_0
hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:Q6_K
hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:Q4_K_M
```

---

# 10. Quantization guide

Quantization controls size, speed, and quality.

```text
Q4_K_M   best default; smaller, faster, lower VRAM
Q5_K_M   better quality if available, more VRAM
Q6_K     better quality, more VRAM
Q8_0     high quality, slower, much more VRAM
BF16     largest, highest memory requirement
```

Recommended default:

```bash
Q4_K_M
```

Recommended for stronger quality if the GPU can handle it:

```bash
Q6_K
```

Avoid unless you have a large GPU:

```bash
Q8_0
BF16
```

---

# 11. Changing the model

## Method 1: use ai-model

```bash
ai-model hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:Q4_K_M
```

This updates `/workspace/ai/ai.env`, pulls the model, and rebuilds the local Ollama alias.

## Method 2: edit manually

```bash
sudo nano /workspace/ai/ai.env
```

Change:

```bash
AI_HF_MODEL="hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:Q4_K_M"
```

Then apply:

```bash
ai-pull
```

Confirm:

```bash
ai-status
```

---

# 12. Changing context length

Context length controls how much text the model can keep in memory.

Higher context is useful for coding and autonomous agents, but it is slower and uses more VRAM.

Edit:

```bash
sudo nano /workspace/ai/ai.env
```

Fast chat:

```bash
AI_CONTEXT_LENGTH="8192"
```

Balanced coding:

```bash
AI_CONTEXT_LENGTH="16384"
```

Heavier coding or agent work:

```bash
AI_CONTEXT_LENGTH="32768"
```

Maximum agent context, if your GPU can handle it:

```bash
AI_CONTEXT_LENGTH="64000"
```

After changing context length:

```bash
ai-pull
ai-ollama-stop
ai-ollama-start
```

Check:

```bash
ai-status
```

---

# 13. Main commands

## ai-chat

Start local chat:

```bash
ai-chat
```

This opens an interactive Ollama chat session.

One-shot prompt:

```bash
ai-chat "Explain what this toolkit does."
```

Exit chat:

```text
/bye
Ctrl+D
Ctrl+C
```

---

## ai-code

Use this inside a project repo.

Create a workspace:

```bash
mkdir -p /workspace/projects
cd /workspace/projects
```

Clone or create a repo:

```bash
git clone https://github.com/some-user/some-project.git
cd some-project
```

Start the coding agent:

```bash
ai-code
```

One-shot task:

```bash
ai-code "Inspect this repo and tell me how to run it."
```

Do not run `ai-code` from the `llm-vm-kit` setup repo itself.

Correct:

```bash
cd /workspace/projects/your-repo
ai-code
```

Wrong:

```bash
cd ~/llm-vm-kit
ai-code
```

---

## ai-agent

Start Hermes Agent:

```bash
ai-agent
```

This automatically starts:

```text
Ollama
headless Chrome browser automation
Hermes Agent
```

You do not need to manually run:

```bash
ai-browser-start
```

Example prompt inside Hermes:

```text
Navigate to https://example.com and summarize the page using the browser.
```

One-shot task:

```bash
ai-agent "Use local tools to inspect /workspace/projects and summarize what is there."
```

---

# 14. Browser automation

`ai-agent` automatically starts browser automation.

Manual browser commands are only for debugging.

Start browser manually:

```bash
ai-browser-start
```

Reset browser:

```bash
ai-browser-reset
```

Check browser endpoint:

```bash
grep -E 'AI_BROWSER_CDP_URL|BROWSER_CDP_URL' /workspace/ai/ai.env /workspace/ai/hermes/.env
```

Expected:

```text
AI_BROWSER_CDP_URL="http://127.0.0.1:9222"
BROWSER_CDP_URL="http://127.0.0.1:9222"
```

If browser tools get flaky:

```bash
ai-browser-reset
ai-agent
```

Check browser logs:

```bash
cat /workspace/ai/logs/browser.log
```

---

# 15. Status and diagnostics

Check the whole stack:

```bash
ai-status
```

Check GPU:

```bash
nvidia-smi
```

Check Ollama logs:

```bash
cat /workspace/ai/logs/ollama.log
```

Check browser logs:

```bash
cat /workspace/ai/logs/browser.log
```

Check active Ollama models:

```bash
ollama ps
```

List local Ollama models:

```bash
ollama list
```

Check current config:

```bash
cat /workspace/ai/ai.env
```

---

# 16. Backup and restore

Back up runtime state:

```bash
ai-backup
```

This prints an archive path like:

```text
/workspace/ai-vm-state-20260624-120000.tgz
```

Copy that archive to another VM.

Restore on another VM:

```bash
cd /workspace
tar -xzf ai-vm-state-*.tgz
```

Then reinstall the toolkit:

```bash
git clone https://github.com/YOUR_USERNAME/llm-vm-kit.git /opt/llm-vm-kit
cd /opt/llm-vm-kit
sudo bash bootstrap.sh
```

This restores:

```text
/workspace/ai/ai.env
/workspace/ai/ollama/models
/workspace/ai/hermes
/workspace/ai/opencode
/workspace/projects
```

---

# 17. Updating this toolkit repo

If you edit scripts or README:

```bash
cd /opt/llm-vm-kit
```

or:

```bash
cd ~/llm-vm-kit
```

Run smoke test:

```bash
bash tools/smoke-test.sh
```

Commit and push:

```bash
git status
git add .
git commit -m "update toolkit"
git push
```

---

# 18. Fresh VM test after pushing

On a new VM:

```bash
sudo apt-get update
sudo apt-get install -y git curl ca-certificates
```

Clone:

```bash
git clone https://github.com/YOUR_USERNAME/llm-vm-kit.git /opt/llm-vm-kit
cd /opt/llm-vm-kit
```

Fast install test:

```bash
sudo AI_SKIP_PULL=1 bash bootstrap.sh
```

Full install:

```bash
sudo bash bootstrap.sh
```

Test commands:

```bash
ai-status
ai-chat
ai-code
ai-agent
```

---

# 19. GitHub authentication notes

GitHub does not accept normal account passwords for Git pushes.

Use one of:

```text
GitHub CLI auth
Personal Access Token
SSH key
```

With GitHub CLI and a token:

```bash
gh auth login --with-token
```

Then:

```bash
gh auth status
gh auth setup-git
```

For this repo, if using a classic GitHub token, common permissions are:

```text
public_repo
workflow
```

`workflow` matters because this repo may include files under:

```text
.github/workflows/
```

---

# 20. Security notes

Do not commit:

```text
GitHub tokens
Hugging Face tokens
API keys
browser cookies
model files
/workspace/ai/hermes/.env
/workspace/ai/ollama/models
```

Keep secrets in:

```bash
/workspace/ai/hermes/.env
```

This repo should contain setup scripts only, not private runtime state.

---

# 21. Troubleshooting

## ai-chat is slow

Use a smaller context:

```bash
sudo nano /workspace/ai/ai.env
```

Set:

```bash
AI_CONTEXT_LENGTH="8192"
```

Then:

```bash
ai-pull
ai-ollama-stop
ai-ollama-start
```

Use a Q4 model:

```bash
:Q4_K_M
```

---

## Model does not pull

Check format.

Correct:

```bash
hf.co/OWNER/REPO:Q4_K_M
```

Incorrect:

```bash
OWNER/REPO
```

Also confirm the Hugging Face repo has `.gguf` files.

---

## Browser automation fails

Reset:

```bash
ai-browser-reset
ai-agent
```

Check logs:

```bash
cat /workspace/ai/logs/browser.log
```

Check Chrome:

```bash
google-chrome --version
```

---

## Ollama is not running

Start it:

```bash
ai-ollama-start
```

Check:

```bash
curl http://127.0.0.1:11434/api/tags
```

---

## GPU is not used

Check:

```bash
nvidia-smi
```

While the model is generating, run:

```bash
nvidia-smi
```

If GPU memory is not being used, your VM may not have GPU access or the CUDA template may be wrong.

---

## Ran ai-code in the wrong directory

Stop it:

```text
Ctrl+C
```

If you are in a Git repo and have commits:

```bash
git reset --hard HEAD
git clean -fd
```

If you had no commits, Git cannot restore the previous state. Recreate from backup or from the setup repo.

Going forward, run `ai-code` only inside:

```bash
/workspace/projects/your-project
```

---

# 22. Quick reference

Install:

```bash
git clone https://github.com/YOUR_USERNAME/llm-vm-kit.git /opt/llm-vm-kit
cd /opt/llm-vm-kit
sudo bash bootstrap.sh
```

Skip model pull:

```bash
sudo AI_SKIP_PULL=1 bash bootstrap.sh
```

Change model:

```bash
ai-model hf.co/HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive:Q4_K_M
```

Edit config:

```bash
sudo nano /workspace/ai/ai.env
```

Use chat:

```bash
ai-chat
```

Use coding agent:

```bash
cd /workspace/projects/your-repo
ai-code
```

Use autonomous agent:

```bash
ai-agent
```

Check status:

```bash
ai-status
```

Backup:

```bash
ai-backup
```
