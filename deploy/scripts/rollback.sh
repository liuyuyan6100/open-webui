#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <previous-image-tag>"
  exit 1
fi

export APP_IMAGE="$1"
cd "$(dirname "$0")/../compose"
docker compose --env-file ../env/.env.prod -f docker-compose.prod.yml up -d

echo "Rolled back to image: $APP_IMAGE"
