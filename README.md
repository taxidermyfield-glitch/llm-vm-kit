# llm-vm-kit

Portable local-AI toolkit for rented CUDA VMs.

Goal:

```text
Fresh CUDA/PyTorch/Ubuntu rental VM
→ clone this repo
→ run bootstrap.sh
→ get global commands:

ai-chat    # ChatGPT-style local chat through Ollama
ai-code    # repo development coding agent through OpenCode
ai-agent   # autonomous worker through Hermes Agent
```

The stack uses one Hugging Face GGUF model for all three commands. Ollama pulls the model from Hugging Face, creates a stable local alias called `local-ai`, and OpenCode/Hermes use that local OpenAI-compatible Ollama endpoint.

## Important model rule

`AI_HF_MODEL` must be an Ollama-compatible Hugging Face GGUF reference, for example:

```bash
hf.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF:Q4_K_M
hf.co/bartowski/Llama-3.2-3B-Instruct-GGUF:Q4_K_M
hf.co/Qwen/Qwen3-30B-A3B-GGUF:Q4_K_M
```

Plain Hugging Face Transformers/Safetensors repos are not enough for this Ollama-based setup unless they have GGUF files that Ollama can run.

## Main config

```bash
/workspace/ai/ai.env
```

Change this one line to switch the model:

```bash
AI_HF_MODEL="hf.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF:Q4_K_M"
```

All commands use this stable alias:

```bash
AI_MODEL="local-ai"
```

## Install on a fresh VM

```bash
git clone https://github.com/YOUR_USER/llm-vm-kit.git /opt/llm-vm-kit
cd /opt/llm-vm-kit
sudo bash bootstrap.sh
```

Or use the remote installer after the repo is on GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/llm-vm-kit/main/install.sh \
  | AI_STACK_REPO="https://github.com/YOUR_USER/llm-vm-kit.git" bash
```

Install with a different model:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/llm-vm-kit/main/install.sh \
  | AI_STACK_REPO="https://github.com/YOUR_USER/llm-vm-kit.git" \
    AI_HF_MODEL="hf.co/bartowski/Llama-3.2-3B-Instruct-GGUF:Q4_K_M" \
    bash
```

Install without pulling a model yet:

```bash
sudo AI_SKIP_PULL=1 bash bootstrap.sh
```

## Commands

```bash
ai-chat
ai-code /workspace/projects/my-repo
ai-agent
ai-model
ai-status
```

One-shot examples:

```bash
ai-chat "Explain this stack."
ai-code /workspace/projects/my-repo "Inspect the repo and identify the test command."
ai-agent "Search the web, extract current docs, and write notes under /workspace/projects/notes."
```

## Switch model later

```bash
ai-model hf.co/bartowski/Llama-3.2-3B-Instruct-GGUF:Q4_K_M
```

Or edit manually:

```bash
nano /workspace/ai/ai.env
ai-pull
ai-status
```

## Optional browser automation

```bash
ai-browser-start
```

Then copy the printed `AI_BROWSER_CDP_URL` into `/workspace/ai/ai.env` and run:

```bash
ai-configure
ai-agent
```

## MCP servers

Hermes can load MCP servers from `mcp_servers:` in `/workspace/ai/hermes/config.yaml`. For npm-based MCP servers, this toolkit installs Node.js and `npx`; for Python MCP servers, it attempts to install `uv`/`uvx`.

Example config block:

```yaml
mcp_servers:
  time:
    command: uvx
    args: ["mcp-server-time"]
```

Restart `ai-agent` after changing MCP config.

## Backup portable state

```bash
ai-backup
```

Copy the generated archive to another VM, extract under `/workspace`, clone this repo, and run `bootstrap.sh`.

Portable state:

```text
/workspace/ai/ai.env
/workspace/ai/ollama/models
/workspace/ai/hermes
/workspace/ai/opencode
/workspace/projects
```
