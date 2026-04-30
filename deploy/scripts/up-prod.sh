#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../compose"

ENV_FILE="../env/.env.prod"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  echo "Create it first: cp ../env/.env.example ../env/.env.prod"
  exit 1
fi

docker compose --env-file "$ENV_FILE" -f docker-compose.prod.yml up -d

echo "Open WebUI production stack started."
