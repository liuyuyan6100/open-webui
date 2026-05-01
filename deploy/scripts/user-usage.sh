#!/usr/bin/env bash
set -euo pipefail

CONTAINER="open-webui"
DB_PATH="/app/backend/data/webui.db"

usage() {
  cat <<'EOF'
Usage:
  deploy/scripts/user-usage.sh status [--period today|month|all] [--include-admin]
  deploy/scripts/user-usage.sh enforce [--daily-tokens N] [--daily-messages N] [--monthly-tokens N] [--monthly-messages N] [--dry-run] [--include-admin]
  deploy/scripts/user-usage.sh disable <email-or-user-id> [--dry-run]

说明：
  status   统计用户消息数与 token 用量
  enforce  按阈值巡检，超额用户改为 pending；默认跳过 admin
  disable  手动禁用指定用户，改为 pending

默认阈值：
  daily tokens:    50000
  daily messages:  100
  monthly tokens:  1000000
  monthly messages:1000
EOF
}

require_runtime() {
  if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
    echo "ERROR: container not found: $CONTAINER" >&2
    exit 1
  fi
}

cmd="${1:-}"
shift || true

case "$cmd" in
  status|enforce|disable) ;;
  -h|--help|help|'') usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

require_runtime

period="today"
include_admin="false"
dry_run="false"
target=""
daily_tokens="50000"
daily_messages="100"
monthly_tokens="1000000"
monthly_messages="1000"

if [[ "$cmd" == "disable" ]]; then
  target="${1:-}"
  if [[ -z "$target" ]]; then
    echo "ERROR: disable requires <email-or-user-id>" >&2
    exit 2
  fi
  shift || true
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --period)
      period="${2:-}"; shift 2 ;;
    --include-admin)
      include_admin="true"; shift ;;
    --dry-run)
      dry_run="true"; shift ;;
    --daily-tokens)
      daily_tokens="${2:-}"; shift 2 ;;
    --daily-messages)
      daily_messages="${2:-}"; shift 2 ;;
    --monthly-tokens)
      monthly_tokens="${2:-}"; shift 2 ;;
    --monthly-messages)
      monthly_messages="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "ERROR: unknown arg: $1" >&2
      usage >&2
      exit 2 ;;
  esac
done

case "$period" in today|month|all) ;; *) echo "ERROR: invalid --period: $period" >&2; exit 2 ;; esac

python_payload=$(cat <<'PY'
import sqlite3, json, os, sys, time, datetime

DB = os.environ['DB_PATH']
CMD = os.environ['CMD']
PERIOD = os.environ.get('PERIOD', 'today')
INCLUDE_ADMIN = os.environ.get('INCLUDE_ADMIN') == 'true'
DRY_RUN = os.environ.get('DRY_RUN') == 'true'
TARGET = os.environ.get('TARGET', '')
DAILY_TOKENS = int(os.environ.get('DAILY_TOKENS', '50000'))
DAILY_MESSAGES = int(os.environ.get('DAILY_MESSAGES', '100'))
MONTHLY_TOKENS = int(os.environ.get('MONTHLY_TOKENS', '1000000'))
MONTHLY_MESSAGES = int(os.environ.get('MONTHLY_MESSAGES', '1000'))

now = int(time.time())
local_now = datetime.datetime.now()
start_today = int(local_now.replace(hour=0, minute=0, second=0, microsecond=0).timestamp())
start_month = int(local_now.replace(day=1, hour=0, minute=0, second=0, microsecond=0).timestamp())

def usage_window(period):
    if period == 'today':
        return start_today, now
    if period == 'month':
        return start_month, now
    return None, now

def parse_usage(raw):
    if not raw or raw == 'null':
        return 0, 0, 0
    try:
        data = json.loads(raw)
    except Exception:
        return 0, 0, 0
    if not isinstance(data, dict):
        return 0, 0, 0
    inp = int(data.get('input_tokens') or data.get('prompt_tokens') or 0)
    out = int(data.get('output_tokens') or data.get('completion_tokens') or 0)
    total = int(data.get('total_tokens') or (inp + out))
    return inp, out, total

def collect(con, period):
    start, end = usage_window(period)
    users = {}
    for uid, name, email, role in con.execute('select id,name,email,role from user order by created_at'):
        if role == 'admin' and not INCLUDE_ADMIN:
            continue
        users[uid] = {
            'id': uid, 'name': name, 'email': email, 'role': role,
            'messages': 0, 'input_tokens': 0, 'output_tokens': 0, 'total_tokens': 0,
        }
    q = "select user_id, usage from chat_message where role='assistant' and user_id is not null"
    args = []
    if start is not None:
        q += ' and created_at >= ?'
        args.append(start)
    if end is not None:
        q += ' and created_at <= ?'
        args.append(end)
    for uid, raw in con.execute(q, args):
        if uid not in users:
            continue
        inp, out, total = parse_usage(raw)
        users[uid]['messages'] += 1
        users[uid]['input_tokens'] += inp
        users[uid]['output_tokens'] += out
        users[uid]['total_tokens'] += total
    return list(users.values())

def print_table(title, rows):
    print(title)
    print('role\tname\temail\tmessages\tinput_tokens\toutput_tokens\ttotal_tokens')
    for r in rows:
        print(f"{r['role']}\t{r['name']}\t{r['email']}\t{r['messages']}\t{r['input_tokens']}\t{r['output_tokens']}\t{r['total_tokens']}")

con = sqlite3.connect(DB)

if CMD == 'status':
    rows = collect(con, PERIOD)
    print_table(f'--- usage period={PERIOD} include_admin={INCLUDE_ADMIN} ---', rows)
    con.close()
    raise SystemExit(0)

if CMD == 'disable':
    row = con.execute('select id,name,email,role from user where id=? or lower(email)=lower(?)', (TARGET, TARGET)).fetchone()
    if not row:
        print(f'ERROR: user not found: {TARGET}', file=sys.stderr)
        con.close(); raise SystemExit(1)
    uid, name, email, role = row
    if role == 'admin':
        print(f'ERROR: refuse to disable admin: {email}', file=sys.stderr)
        con.close(); raise SystemExit(1)
    print(f"target={name}\temail={email}\trole_before={role}\tdry_run={DRY_RUN}")
    if not DRY_RUN:
        con.execute("update user set role='pending', updated_at=? where id=?", (int(time.time()), uid))
        con.commit()
    print(f"action={'would_disable' if DRY_RUN else 'disabled'}\temail={email}\trole_after=pending")
    con.close(); raise SystemExit(0)

if CMD == 'enforce':
    today_rows = collect(con, 'today')
    month_rows = collect(con, 'month')
    month_by_id = {r['id']: r for r in month_rows}
    offenders = []
    for r in today_rows:
        m = month_by_id.get(r['id'], r)
        reasons = []
        if DAILY_TOKENS >= 0 and r['total_tokens'] > DAILY_TOKENS:
            reasons.append(f"daily_tokens>{DAILY_TOKENS} ({r['total_tokens']})")
        if DAILY_MESSAGES >= 0 and r['messages'] > DAILY_MESSAGES:
            reasons.append(f"daily_messages>{DAILY_MESSAGES} ({r['messages']})")
        if MONTHLY_TOKENS >= 0 and m['total_tokens'] > MONTHLY_TOKENS:
            reasons.append(f"monthly_tokens>{MONTHLY_TOKENS} ({m['total_tokens']})")
        if MONTHLY_MESSAGES >= 0 and m['messages'] > MONTHLY_MESSAGES:
            reasons.append(f"monthly_messages>{MONTHLY_MESSAGES} ({m['messages']})")
        if reasons and r['role'] != 'pending':
            offenders.append((r, reasons))
    print('--- enforce thresholds ---')
    print(f'daily_tokens={DAILY_TOKENS} daily_messages={DAILY_MESSAGES} monthly_tokens={MONTHLY_TOKENS} monthly_messages={MONTHLY_MESSAGES} dry_run={DRY_RUN} include_admin={INCLUDE_ADMIN}')
    if not offenders:
        print('no offenders')
    for r, reasons in offenders:
        print(f"offender={r['name']}\temail={r['email']}\trole={r['role']}\treasons={'; '.join(reasons)}")
        if r['role'] == 'admin':
            print(f"skip_admin={r['email']}")
            continue
        if not DRY_RUN:
            con.execute("update user set role='pending', updated_at=? where id=?", (int(time.time()), r['id']))
            print(f"disabled={r['email']} role_after=pending")
        else:
            print(f"would_disable={r['email']} role_after=pending")
    if not DRY_RUN:
        con.commit()
    con.close(); raise SystemExit(0)

print('ERROR: unknown command', CMD, file=sys.stderr)
con.close(); raise SystemExit(2)
PY
)

docker exec \
  -e DB_PATH="$DB_PATH" \
  -e CMD="$cmd" \
  -e PERIOD="$period" \
  -e INCLUDE_ADMIN="$include_admin" \
  -e DRY_RUN="$dry_run" \
  -e TARGET="$target" \
  -e DAILY_TOKENS="$daily_tokens" \
  -e DAILY_MESSAGES="$daily_messages" \
  -e MONTHLY_TOKENS="$monthly_tokens" \
  -e MONTHLY_MESSAGES="$monthly_messages" \
  "$CONTAINER" python -c "$python_payload"
