#!/usr/bin/env bash
# OpenFlexure microscope HTTP API (v2): probe connectivity + stage axis moves.
# Default base matches a typical mDNS install: http://microscope.local:5000
#
# Env:
#   OPENFLEXURE_BASE   e.g. http://169.254.103.118:5000 (no trailing slash)
#   CURL_CONNECT_TIMEOUT  seconds (default 5)
#   DEMO_DELAY_SEC     sleep between demo moves (default 2)
#   DEMO_STEP_X, DEMO_STEP_Y, DEMO_STEP_Z  integer steps for demo-axes (100/100/20)
#   POLL_MAX           max polls when waiting on an action (default 60)
#   POLL_INTERVAL      seconds between polls (default 0.5)
#   SKIP_ACTION_WAIT   set to 1 to skip polling after move/zero

set -u

die() { echo "error: $*" >&2; exit 1; }

usage() {
  local ec="${1:-1}"
  cat >&2 <<'EOF'
usage: openflexure_stage.sh <command> [args]

commands:
  test              GET state + stage type (+ try nested stage/position)
  get <path>        GET /api/v2/<path> (path without leading slash)
  move <json>       POST /api/v2/actions/stage/move/ with JSON body
  zero              POST /api/v2/actions/stage/zero/ with {}
  action <id>       GET /api/v2/actions/<id>
  demo-axes         small relative X/Y/Z moves (env DEMO_STEP_*)

examples:
  OPENFLEXURE_BASE=http://microscope.local:5000 ./openflexure_stage.sh test
  ./openflexure_stage.sh move '{"x":100}'
  ./openflexure_stage.sh move '{"x":0,"y":0,"z":0,"absolute":true}'
  ./openflexure_stage.sh zero
  DEMO_STEP_Z=10 ./openflexure_stage.sh demo-axes
EOF
  exit "$ec"
}

BASE_RAW="${OPENFLEXURE_BASE:-http://microscope.local:5000}"
BASE="${BASE_RAW%/}"
CTO="${CURL_CONNECT_TIMEOUT:-5}"

curl_json_get() {
  local url="$1"
  curl -sS --connect-timeout "$CTO" -H 'Accept: application/json' "$url"
}

curl_json_post() {
  local url="$1"
  local body="$2"
  curl -sS --connect-timeout "$CTO" -H 'Content-Type: application/json' \
    -H 'Accept: application/json' -X POST -d "$body" "$url"
}

http_get_code() {
  local url="$1"
  curl -sS --connect-timeout "$CTO" -o /dev/null -w '%{http_code}' "$url"
}

extract_action_id() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.uuid // .id // .task_id // empty' 2>/dev/null
  else
    python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("uuid") or d.get("id") or d.get("task_id") or "")' 2>/dev/null
  fi
}

action_status_line() {
  # prints a one-line summary if jq/python available
  if command -v jq >/dev/null 2>&1; then
    jq -c '{status: (.status // .state // .), error: (.error // .exception // null)}' 2>/dev/null
  else
    python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps({"keys": list(d)[:8]}))' 2>/dev/null
  fi
}

wait_for_action() {
  local id="$1"
  [[ -n "$id" ]] || return 0
  if [[ "${SKIP_ACTION_WAIT:-0}" == "1" ]]; then
    echo "action ${id}: SKIP_ACTION_WAIT=1 (not polling)"
    return 0
  fi
  local max="${POLL_MAX:-60}"
  local interval="${POLL_INTERVAL:-0.5}"
  local i=0
  echo "action ${id}: polling…"
  while (( i < max )); do
    local body
    body=$(curl_json_get "${BASE}/api/v2/actions/${id}")
    # Heuristic: many builds expose a string status; treat common terminals.
    if echo "$body" | grep -qiE '"status"[[:space:]]*:[[:space:]]*"(finished|complete|completed|done|success)"'; then
      echo "$body" | action_status_line || echo "$body"
      echo "action ${id}: finished"
      return 0
    fi
    if echo "$body" | grep -qiE '"status"[[:space:]]*:[[:space:]]*"(failed|error|cancelled|canceled)"'; then
      echo "$body" >&2
      die "action ${id}: failed (see JSON above)"
    fi
    sleep "$interval"
    i=$((i + 1))
  done
  die "action ${id}: timed out after ${max} polls"
}

cmd_test() {
  echo "base: ${BASE}"
  local c
  c=$(http_get_code "${BASE}/api/v2/instrument/state")
  echo -n "GET /api/v2/instrument/state → HTTP ${c} "
  if [[ "$c" == 2* ]]; then echo OK; else echo FAIL; return 2; fi

  echo "--- stage type"
  curl_json_get "${BASE}/api/v2/instrument/stage/type" || true
  echo

  echo -n "GET /api/v2/instrument/state/stage/position → "
  local p
  p=$(http_get_code "${BASE}/api/v2/instrument/state/stage/position")
  echo "HTTP ${p}"
  if [[ "$p" == 2* ]]; then
    curl_json_get "${BASE}/api/v2/instrument/state/stage/position" || true
    echo
  else
    echo "(optional path missing on some builds; try: get instrument/state and inspect stage subtree)"
  fi
}

cmd_get() {
  local path="${1:-}"
  [[ -n "$path" ]] || die "get: missing path (e.g. instrument/state)"
  path="${path#\/}"
  curl_json_get "${BASE}/api/v2/${path}"
  echo
}

cmd_move() {
  local body="${1:-}"
  [[ -n "$body" ]] || die 'move: missing JSON body, e.g. {"x":100}'
  local resp
  resp=$(curl_json_post "${BASE}/api/v2/actions/stage/move/" "$body") || die "move: curl failed"
  echo "$resp"
  local id
  id=$(echo "$resp" | extract_action_id)
  if [[ -n "$id" ]]; then
    wait_for_action "$id"
  fi
}

cmd_zero() {
  local resp
  resp=$(curl_json_post "${BASE}/api/v2/actions/stage/zero/" '{}') || die "zero: curl failed"
  echo "$resp"
  local id
  id=$(echo "$resp" | extract_action_id)
  if [[ -n "$id" ]]; then
    wait_for_action "$id"
  fi
}

cmd_action() {
  local id="${1:-}"
  [[ -n "$id" ]] || die "action: missing id"
  curl_json_get "${BASE}/api/v2/actions/${id}"
  echo
}

cmd_demo_axes() {
  local sx="${DEMO_STEP_X:-100}"
  local sy="${DEMO_STEP_Y:-100}"
  local sz="${DEMO_STEP_Z:-20}"
  local d="${DEMO_DELAY_SEC:-2}"
  echo "demo steps: x=±${sx} y=±${sy} z=±${sz} delay=${d}s"
  echo "== precondition: API"
  cmd_test || die "API probe failed; fix OPENFLEXURE_BASE or server"

  run() {
    local label="$1"
    local json="$2"
    echo "== ${label}: ${json}"
    local resp
    resp=$(curl_json_post "${BASE}/api/v2/actions/stage/move/" "$json") || die "move failed"
    echo "$resp"
    local id
    id=$(echo "$resp" | extract_action_id)
    [[ -n "$id" ]] && wait_for_action "$id"
    sleep "$d"
  }

  run "X+" "{\"x\":${sx}}"
  run "X-" "{\"x\":-${sx}}"
  run "Y+" "{\"y\":${sy}}"
  run "Y-" "{\"y\":-${sy}}"
  run "Z+" "{\"z\":${sz}}"
  run "Z-" "{\"z\":-${sz}}"
  echo "demo-axes: done"
}

main() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || usage 1
  shift || true
  case "$cmd" in
    test|probe) cmd_test ;;
    get) cmd_get "${1:-}" ;;
    move) cmd_move "${1:-}" ;;
    zero) cmd_zero ;;
    action) cmd_action "${1:-}" ;;
    demo-axes) cmd_demo_axes ;;
    -h|--help|help) usage 0 ;;
    *) die "unknown command: ${cmd} (try --help)" ;;
  esac
}

main "$@"
