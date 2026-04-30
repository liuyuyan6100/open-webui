#!/usr/bin/env bash
set -euo pipefail

URL="${1:-http://127.0.0.1:3000}"

code=$(curl -k -sS -o /tmp/openwebui-healthcheck.out -w "%{http_code}" "$URL" || true)

if [[ "$code" =~ ^2|3 ]]; then
  echo "OK: $URL HTTP $code"
  exit 0
fi

echo "FAIL: $URL HTTP $code"
cat /tmp/openwebui-healthcheck.out || true
exit 1
