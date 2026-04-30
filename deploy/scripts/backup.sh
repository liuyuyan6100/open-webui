#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups}"
mkdir -p "$BACKUP_DIR"

ts=$(date +%Y%m%d-%H%M%S)

echo "TODO: 根据实际数据目录或数据库类型补充备份命令"
echo "backup placeholder: $BACKUP_DIR/openwebui-$ts"
