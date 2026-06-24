#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$0")/.."

if [[ "$(id -u)" -eq 0 ]]; then
  AI_SKIP_PULL=1 bash ./bootstrap.sh
else
  sudo env AI_SKIP_PULL=1 bash ./bootstrap.sh
fi
