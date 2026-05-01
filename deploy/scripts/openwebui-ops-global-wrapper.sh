#!/usr/bin/env bash
set -euo pipefail

# Global wrapper for Open WebUI production operations.
# Installed target: /usr/local/bin/openwebui-ops
# Source controller: /home/ubuntu/openwebui-custom/deploy/scripts/openwebui-ops.sh

PROJECT_ROOT="${OPENWEBUI_CUSTOM_ROOT:-/home/ubuntu/openwebui-custom}"
CONTROLLER="$PROJECT_ROOT/deploy/scripts/openwebui-ops.sh"

if [[ ! -x "$CONTROLLER" ]]; then
  echo "ERROR: Open WebUI ops controller not found or not executable: $CONTROLLER" >&2
  echo "Hint: set OPENWEBUI_CUSTOM_ROOT=/path/to/openwebui-custom if the project moved." >&2
  exit 1
fi

exec "$CONTROLLER" "$@"
