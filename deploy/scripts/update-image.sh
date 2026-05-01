#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$PROJECT_ROOT/deploy/env/.env.prod"
COMPOSE_FILE="$PROJECT_ROOT/deploy/compose/docker-compose.prod.yml"
BACKUP_SCRIPT="$PROJECT_ROOT/deploy/scripts/backup.sh"
HEALTHCHECK_SCRIPT="$PROJECT_ROOT/deploy/scripts/healthcheck.sh"
HEALTH_URL="${HEALTH_URL:-https://openweb.aiclawonline.website/health}"
LOCAL_HEALTH_URL="${LOCAL_HEALTH_URL:-http://127.0.0.1:3000}"
SERVICE_NAME="${SERVICE_NAME:-open-webui}"
BACKUP_ARCHIVE=""
OLD_IMAGE=""
NEW_IMAGE=""
DRY_RUN=0
SKIP_BACKUP=0
SKIP_PULL=0
YES=0
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-180}"

usage() {
  cat <<'EOF'
Usage:
  deploy/scripts/update-image.sh --image <image> [options]

Options:
  --image <image>        Target image, e.g. ghcr.io/open-webui/open-webui:v0.9.2
  --dry-run              Print planned actions and validate config only
  --skip-backup          Skip backup step (not recommended)
  --skip-pull            Skip docker pull
  -y, --yes              Non-interactive; do not prompt
  -h, --help             Show help

Environment:
  HEALTH_URL             Public health URL, default https://openweb.aiclawonline.website/health
  LOCAL_HEALTH_URL       Local health base URL, default http://127.0.0.1:3000
  BACKUP_DIR             Backup output root passed to backup.sh
  TIMEOUT_SECONDS        Container health wait timeout, default 180

Examples:
  bash deploy/scripts/update-image.sh --image ghcr.io/open-webui/open-webui:v0.9.2 --dry-run
  bash deploy/scripts/update-image.sh --image ghcr.io/open-webui/open-webui:v0.9.3
EOF
}

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      NEW_IMAGE="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --skip-backup)
      SKIP_BACKUP=1
      shift
      ;;
    --skip-pull)
      SKIP_PULL=1
      shift
      ;;
    -y|--yes)
      YES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$NEW_IMAGE" ]]; then
  err "--image is required"
  usage
  exit 2
fi

if [[ "$NEW_IMAGE" == *":main" || "$NEW_IMAGE" == "main" ]]; then
  err "Refusing to deploy floating main tag. Use an explicit version tag."
  exit 2
fi

if [[ ! -f "$ENV_FILE" ]]; then
  err "Missing env file: $ENV_FILE"
  exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  err "Missing compose file: $COMPOSE_FILE"
  exit 1
fi

cd "$PROJECT_ROOT"

OLD_IMAGE="$(grep '^APP_IMAGE=' "$ENV_FILE" | tail -1 | cut -d= -f2- || true)"
if [[ -z "$OLD_IMAGE" ]]; then
  OLD_IMAGE="$(docker inspect "$SERVICE_NAME" --format '{{.Config.Image}}' 2>/dev/null || true)"
fi

log "Project: $PROJECT_ROOT"
log "Env file: $ENV_FILE"
log "Service: $SERVICE_NAME"
log "Old image: ${OLD_IMAGE:-unknown}"
log "New image: $NEW_IMAGE"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "Dry run: validate compose with target image"
  tmp_env="$(mktemp)"
  cp "$ENV_FILE" "$tmp_env"
  if grep -q '^APP_IMAGE=' "$tmp_env"; then
    python3 - "$tmp_env" "$NEW_IMAGE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); image=sys.argv[2]
lines=[]
for line in p.read_text().splitlines():
    if line.startswith('APP_IMAGE='):
        lines.append('APP_IMAGE='+image)
    else:
        lines.append(line)
p.write_text('\n'.join(lines)+'\n')
PY
  else
    printf '\nAPP_IMAGE=%s\n' "$NEW_IMAGE" >> "$tmp_env"
  fi
  docker compose --env-file "$tmp_env" -f "$COMPOSE_FILE" config >/tmp/openwebui-update-image-compose.yml
  rm -f "$tmp_env"
  log "Compose config OK: /tmp/openwebui-update-image-compose.yml"
  log "Dry run completed; no changes made."
  exit 0
fi

if [[ "$YES" -ne 1 ]]; then
  printf 'Deploy %s -> %s ? Type yes to continue: ' "${OLD_IMAGE:-unknown}" "$NEW_IMAGE"
  read -r answer
  if [[ "$answer" != "yes" ]]; then
    err "Aborted by user"
    exit 130
  fi
fi

if [[ "$SKIP_BACKUP" -ne 1 ]]; then
  log "Running backup before update"
  backup_log="$(mktemp)"
  if bash "$BACKUP_SCRIPT" | tee "$backup_log"; then
    BACKUP_ARCHIVE="$(awk -F': ' '/^Backup archive: /{print $2}' "$backup_log" | tail -1)"
    rm -f "$backup_log"
    log "Backup completed: ${BACKUP_ARCHIVE:-unknown}"
  else
    rm -f "$backup_log"
    err "Backup failed; aborting update"
    exit 1
  fi
else
  log "Backup skipped by user option"
fi

if [[ "$SKIP_PULL" -ne 1 ]]; then
  log "Pulling target image: $NEW_IMAGE"
  docker pull "$NEW_IMAGE"
fi

log "Updating APP_IMAGE in $ENV_FILE"
python3 - "$ENV_FILE" "$NEW_IMAGE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); image=sys.argv[2]
text=p.read_text()
lines=[]; found=False
for line in text.splitlines():
    if line.startswith('APP_IMAGE='):
        lines.append('APP_IMAGE='+image)
        found=True
    else:
        lines.append(line)
if not found:
    lines.append('APP_IMAGE='+image)
p.write_text('\n'.join(lines)+'\n')
PY
chmod 600 "$ENV_FILE"

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config >/tmp/openwebui-update-image-compose.yml
log "Compose config OK"

log "Recreating $SERVICE_NAME"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --force-recreate "$SERVICE_NAME"

log "Waiting for container health"
end=$((SECONDS + TIMEOUT_SECONDS))
health="unknown"
while [[ "$SECONDS" -lt "$end" ]]; do
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$SERVICE_NAME" 2>/dev/null || true)"
  log "health=$health"
  if [[ "$health" == "healthy" || "$health" == "running" ]]; then
    break
  fi
  sleep 5
done

if [[ "$health" != "healthy" && "$health" != "running" ]]; then
  err "Container did not become healthy; rolling back to $OLD_IMAGE"
  if [[ -n "$OLD_IMAGE" ]]; then
    python3 - "$ENV_FILE" "$OLD_IMAGE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); image=sys.argv[2]
lines=[]
for line in p.read_text().splitlines():
    if line.startswith('APP_IMAGE='):
        lines.append('APP_IMAGE='+image)
    else:
        lines.append(line)
p.write_text('\n'.join(lines)+'\n')
PY
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --force-recreate "$SERVICE_NAME"
  fi
  exit 1
fi

log "Running local healthcheck"
bash "$HEALTHCHECK_SCRIPT" "$LOCAL_HEALTH_URL"

log "Running public healthcheck: $HEALTH_URL"
public_code="$(curl -k -sS -o /tmp/openwebui-update-public-health.out -w '%{http_code}' "$HEALTH_URL" || true)"
if [[ ! "$public_code" =~ ^2|3 ]]; then
  err "Public healthcheck failed: HTTP $public_code"
  cat /tmp/openwebui-update-public-health.out >&2 || true
  err "Rolling back to $OLD_IMAGE"
  if [[ -n "$OLD_IMAGE" ]]; then
    python3 - "$ENV_FILE" "$OLD_IMAGE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); image=sys.argv[2]
lines=[]
for line in p.read_text().splitlines():
    if line.startswith('APP_IMAGE='):
        lines.append('APP_IMAGE='+image)
    else:
        lines.append(line)
p.write_text('\n'.join(lines)+'\n')
PY
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d --force-recreate "$SERVICE_NAME"
  fi
  exit 1
fi

actual_image="$(docker inspect "$SERVICE_NAME" --format '{{.Config.Image}}')"
log "Update successful"
log "Actual image: $actual_image"
log "Backup archive: ${BACKUP_ARCHIVE:-skipped}"
