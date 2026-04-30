#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/deploy/compose/docker-compose.prod.yml"
ENV_FILE="$PROJECT_ROOT/deploy/env/.env.prod"
BACKUP_ROOT="${BACKUP_DIR:-$PROJECT_ROOT/backups}"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR_ABS="$BACKUP_ROOT/openwebui-$TS"
ARCHIVE="$BACKUP_ROOT/openwebui-$TS.tar.gz"
VOLUME_NAME="${OPEN_WEBUI_VOLUME:-open-webui-data}"
NGINX_SITE="/etc/nginx/sites-available/open-webui"

mkdir -p "$BACKUP_DIR_ABS"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

# 读取 .env.prod 中的 OPEN_WEBUI_VOLUME，但不输出任何密钥。
if grep -q '^OPEN_WEBUI_VOLUME=' "$ENV_FILE"; then
  VOLUME_NAME="$(grep '^OPEN_WEBUI_VOLUME=' "$ENV_FILE" | tail -1 | cut -d= -f2-)"
fi

# Docker Compose 会给 named volume 加 project 前缀。优先从当前容器挂载解析真实 volume。
REAL_VOLUME="$(docker inspect open-webui --format '{{range .Mounts}}{{if eq .Destination "/app/backend/data"}}{{.Name}}{{end}}{{end}}' 2>/dev/null || true)"
if [[ -z "$REAL_VOLUME" ]]; then
  REAL_VOLUME="$VOLUME_NAME"
fi

echo "Backup timestamp: $TS"
echo "Backup directory: $BACKUP_DIR_ABS"
echo "Docker volume: $REAL_VOLUME"

# 1. 备份 Docker volume 数据。
docker run --rm \
  -v "$REAL_VOLUME:/data:ro" \
  -v "$BACKUP_DIR_ABS:/backup" \
  alpine:3.20 \
  sh -c 'cd /data && tar czf /backup/open-webui-data.tar.gz .'

# 2. 备份非密钥配置模板和当前 compose。
mkdir -p "$BACKUP_DIR_ABS/deploy"
cp -a "$PROJECT_ROOT/deploy/compose" "$BACKUP_DIR_ABS/deploy/"
cp -a "$PROJECT_ROOT/deploy/nginx" "$BACKUP_DIR_ABS/deploy/"

# 3. 备份生产 env，但权限收紧。注意该文件含密钥，只放本机备份包，不提交 Git。
mkdir -p "$BACKUP_DIR_ABS/secrets"
cp "$ENV_FILE" "$BACKUP_DIR_ABS/secrets/.env.prod"
chmod 600 "$BACKUP_DIR_ABS/secrets/.env.prod"

# 4. 备份实际 Nginx 站点配置。
if [[ -f "$NGINX_SITE" ]]; then
  mkdir -p "$BACKUP_DIR_ABS/nginx"
  sudo cp "$NGINX_SITE" "$BACKUP_DIR_ABS/nginx/open-webui"
  sudo chown "$(id -u):$(id -g)" "$BACKUP_DIR_ABS/nginx/open-webui"
fi

# 5. 写入恢复说明。
cat > "$BACKUP_DIR_ABS/RESTORE.md" <<EOF
# Open WebUI Restore

Created: $TS

## Restore Docker volume

\`\`\`bash
docker volume create $REAL_VOLUME
docker run --rm -v $REAL_VOLUME:/data -v "\$(pwd):/backup" alpine:3.20 sh -c 'cd /data && tar xzf /backup/open-webui-data.tar.gz'
\`\`\`

## Restore env

\`\`\`bash
cp secrets/.env.prod $PROJECT_ROOT/deploy/env/.env.prod
chmod 600 $PROJECT_ROOT/deploy/env/.env.prod
\`\`\`

## Restart

\`\`\`bash
cd $PROJECT_ROOT
docker compose --env-file deploy/env/.env.prod -f deploy/compose/docker-compose.prod.yml up -d
\`\`\`
EOF

# 6. 打包。
tar czf "$ARCHIVE" -C "$BACKUP_ROOT" "openwebui-$TS"
chmod 600 "$ARCHIVE"

echo "Backup archive: $ARCHIVE"
echo "OK"
