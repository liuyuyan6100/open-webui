#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="$ROOT_DIR/deploy/scripts"

usage() {
  cat <<'EOF'
Open WebUI production ops controller

Usage:
  openwebui-ops <command> [args...]
  deploy/scripts/openwebui-ops.sh <command> [args...]

Commands:
  status                 Run healthcheck.sh
  up                     Run up-prod.sh
  backup                 Run backup.sh
  rollback [args...]     Run rollback.sh
  update-image [args...] Run update-image.sh
  signup status          Show signup/users status
  signup enable          Enable public signup; new users stay pending
  signup disable         Disable public signup
  usage status [args...] Show per-user usage
  usage enforce [args...] Enforce per-user usage limits by setting offenders to pending
  usage disable <user>   Disable one user by email or user id

Examples:
  openwebui-ops status
  openwebui-ops signup status
  openwebui-ops signup enable
  openwebui-ops signup disable
  openwebui-ops usage status --period today
  openwebui-ops usage enforce --daily-tokens 50000 --daily-messages 100 --dry-run
  openwebui-ops update-image --image ghcr.io/open-webui/open-webui:v0.9.2 --dry-run
EOF
}

run_script() {
  local script="$1"; shift
  exec "$SCRIPTS_DIR/$script" "$@"
}

cmd="${1:-}"
case "$cmd" in
  status|health|healthcheck)
    run_script healthcheck.sh "${@:2}"
    ;;
  up|start)
    run_script up-prod.sh "${@:2}"
    ;;
  backup)
    run_script backup.sh "${@:2}"
    ;;
  rollback)
    run_script rollback.sh "${@:2}"
    ;;
  update-image|update)
    run_script update-image.sh "${@:2}"
    ;;
  signup)
    shift || true
    run_script signup-control.sh "$@"
    ;;
  usage)
    shift || true
    run_script user-usage.sh "$@"
    ;;
  -h|--help|help|'')
    usage
    ;;
  *)
    echo "ERROR: unknown command: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
