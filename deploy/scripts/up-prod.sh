#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../compose"

docker compose --env-file ../env/.env.prod -f docker-compose.prod.yml up -d

echo "Open WebUI production stack started."
