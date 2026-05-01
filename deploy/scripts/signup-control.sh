#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/deploy/compose/docker-compose.prod.yml"
ENV_FILE="$ROOT_DIR/deploy/env/.env.prod"
SERVICE="open-webui"
CONTAINER="open-webui"
DB_PATH="/app/backend/data/webui.db"
PUBLIC_CONFIG_URL="https://openweb.aiclawonline.website/api/config"
PUBLIC_HEALTH_URL="https://openweb.aiclawonline.website/health"
RESOLVE_HOST="openweb.aiclawonline.website:443:134.185.87.243"

usage() {
  cat <<'EOF'
Usage:
  deploy/scripts/signup-control.sh status
  deploy/scripts/signup-control.sh enable
  deploy/scripts/signup-control.sh disable

说明：
  enable  开启注册，并保持默认新用户角色为 pending
  disable 关闭注册，并保持默认新用户角色为 pending
  status  查看公网配置、数据库配置和用户角色
EOF
}

require_runtime() {
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: env file not found: $ENV_FILE" >&2
    exit 1
  fi
  if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
    echo "ERROR: container not found: $CONTAINER" >&2
    exit 1
  fi
}

backup_db() {
  local reason="$1"
  docker exec "$CONTAINER" sh -lc "python - <<'PY'
import sqlite3, datetime
src='$DB_PATH'
ts=datetime.datetime.now().strftime('%Y%m%d%H%M%S')
dst=f'/app/backend/data/webui.db.pre-${reason}-{ts}.bak'
con=sqlite3.connect(src)
bak=sqlite3.connect(dst)
con.backup(bak)
bak.close(); con.close()
print(dst)
PY"
}

set_signup() {
  local enabled="$1"
  docker exec "$CONTAINER" sh -lc "python - <<'PY'
import sqlite3, json
p='$DB_PATH'
enabled = ${enabled}
con=sqlite3.connect(p)
row=con.execute('select id,data from config order by id limit 1').fetchone()
if not row:
    data={'version':0,'ui':{'enable_signup': enabled, 'default_user_role':'pending'}}
    con.execute('insert into config (data, version) values (?, 0)', (json.dumps(data, ensure_ascii=False),))
else:
    cid, raw=row
    data=json.loads(raw or '{}')
    data.setdefault('version', 0)
    ui=data.setdefault('ui', {})
    ui['enable_signup'] = enabled
    ui['default_user_role'] = 'pending'
    con.execute('update config set data=?, updated_at=CURRENT_TIMESTAMP where id=?', (json.dumps(data, ensure_ascii=False), cid))
con.commit(); con.close()
print({'enable_signup': enabled, 'default_user_role': 'pending'})
PY"
}

restart_and_wait() {
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" restart "$SERVICE"
  for i in $(seq 1 40); do
    local st
    st="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$CONTAINER" 2>/dev/null || true)"
    echo "try=$i health=$st"
    [[ "$st" == "healthy" ]] && return 0
    sleep 3
  done
  echo "ERROR: container did not become healthy" >&2
  return 1
}

status() {
  require_runtime
  echo "--- public /api/config ---"
  local tmp code
  tmp="$(mktemp)"
  code="$(curl --resolve "$RESOLVE_HOST" -sS -o "$tmp" -w '%{http_code}' "$PUBLIC_CONFIG_URL")"
  printf 'http_code=%s bytes=%s\n' "$code" "$(wc -c < "$tmp")"
  python3 - "$tmp" <<'PY'
import sys,json
with open(sys.argv[1], encoding='utf-8') as f:
    cfg=json.load(f)
features=cfg.get('features') or {}
print('enable_login_form=', features.get('enable_login_form'))
print('enable_signup=', features.get('enable_signup'))
print('enable_api_keys=', features.get('enable_api_keys'))
print('enable_websocket=', features.get('enable_websocket'))
PY
  rm -f "$tmp"

  echo "--- db config/users ---"
  docker exec "$CONTAINER" sh -lc "python - <<'PY'
import sqlite3,json
con=sqlite3.connect('$DB_PATH')
row=con.execute('select data from config order by id limit 1').fetchone()
data=json.loads(row[0] or '{}') if row else {}
ui=data.get('ui') or {}
print('db.enable_signup=', ui.get('enable_signup'))
print('db.default_user_role=', ui.get('default_user_role'))
for name,email,role in con.execute('select name,email,role from user order by created_at desc'):
    print(f'user={name}\temail={email}\trole={role}')
con.close()
PY"

  echo "--- health ---"
  curl --resolve "$RESOLVE_HOST" -fsS "$PUBLIC_HEALTH_URL"
  echo
}

cmd="${1:-}"
case "$cmd" in
  status)
    status
    ;;
  enable)
    require_runtime
    echo "backup=$(backup_db enable-signup)"
    set_signup True
    restart_and_wait
    status
    ;;
  disable)
    require_runtime
    echo "backup=$(backup_db disable-signup)"
    set_signup False
    restart_and_wait
    status
    ;;
  -h|--help|help|'')
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
