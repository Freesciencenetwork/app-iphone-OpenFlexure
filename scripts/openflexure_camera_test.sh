#!/usr/bin/env bash
# OpenFlexure v2: test that the camera HTTP surface responds (snapshot JPEG, live PNG tile),
# and optionally run capture / GPU preview actions. Use your scope's live Swagger for exact schemas:
#   ${OPENFLEXURE_BASE}/api/v2/docs/swagger-ui
#
# Env:
#   OPENFLEXURE_BASE     default http://microscope.local:5000
#   CURL_CONNECT_TIMEOUT default 10
#   PREVIEW_START_JSON   body for POST .../actions/camera/preview/start (default small window)
#   SKIP_CAPTURE         set to 1: `all` skips disk capture on the Pi

set -u

BASE_RAW="${OPENFLEXURE_BASE:-http://microscope.local:5000}"
BASE="${BASE_RAW%/}"
CTO="${CURL_CONNECT_TIMEOUT:-10}"
PREVIEW_JSON="${PREVIEW_START_JSON:-{\"window\":[0,0,832,624]}}"

die() { echo "error: $*" >&2; exit 1; }

usage() {
  cat >&2 <<EOF
usage: openflexure_camera_test.sh <command>

  check              Read-only: configuration camera block + JPEG snapshot + PNG camera/lst
  snapshot [file]    GET /api/v2/streams/snapshot -> JPEG (default: ./openflexure_camera_snapshot.jpg)
  capture [name]     POST /api/v2/actions/camera/capture/ (default basename: of_capture_<epoch>)
  preview-start      POST GPU preview start (body from PREVIEW_START_JSON)
  preview-stop       POST GPU preview stop with {}
  probe                Print HTTP codes for camera-related URLs
  all                check, then snapshot to temp, then capture (unless SKIP_CAPTURE=1)

Examples:
  $0 check
  $0 snapshot /tmp/scope.jpg
  SKIP_CAPTURE=1 $0 all
EOF
  exit "${1:-0}"
}

curl_get() {
  curl -sS --connect-timeout "$CTO" -H 'Accept: */*' "$1"
}

curl_get_code() {
  curl -sS --connect-timeout "$CTO" -o /dev/null -w '%{http_code}' "$1" 2>/dev/null || echo 000
}

curl_post_json() {
  curl -sS --connect-timeout "$CTO" -H 'Content-Type: application/json' -H 'Accept: application/json' \
    -X POST -d "$2" "$1"
}

extract_action_id() {
  if command -v jq >/dev/null 2>&1; then
    jq -r '.id // .uuid // .task_id // empty' 2>/dev/null
  else
    python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("id") or d.get("uuid") or d.get("task_id") or "")' 2>/dev/null
  fi
}

wait_action() {
  local id="$1"
  [[ -n "$id" ]] || return 0
  local max="${POLL_MAX:-90}"
  local interval="${POLL_INTERVAL:-0.5}"
  local i=0
  echo "action ${id}: waiting…"
  while (( i < max )); do
    local body
    body=$(curl_get "${BASE}/api/v2/actions/${id}")
    if echo "$body" | grep -qiE '"status"[[:space:]]*:[[:space:]]*"(completed|finished|done|success)"'; then
      echo "action ${id}: completed"
      return 0
    fi
    if echo "$body" | grep -qiE '"status"[[:space:]]*:[[:space:]]*"(failed|error|cancelled|canceled)"'; then
      echo "$body" >&2
      die "action ${id} failed"
    fi
    sleep "$interval"
    i=$((i + 1))
  done
  die "action ${id}: timeout"
}

verify_magic() {
  local file="$1"
  local kind="$2"
  python3 -c "import sys
p=open(sys.argv[1],'rb').read(16)
k=sys.argv[2]
if k=='jpeg' and p[:2]!=b'\\xff\\xd8':
    print('not JPEG, head=%r'%p[:8], file=sys.stderr); sys.exit(1)
if k=='png' and p[:8]!=bytes([137,80,78,71,13,10,26,10]):
    print('not PNG, head=%r'%p[:8], file=sys.stderr); sys.exit(1)
" "$file" "$kind" || die "magic check failed ($kind)"
}

cmd_probe() {
  echo "base: ${BASE}"
  local paths=(
    "/api/v2/instrument/configuration"
    "/api/v2/instrument/settings"
    "/api/v2/instrument/state/camera"
    "/api/v2/instrument/camera/lst"
    "/api/v2/streams/snapshot"
    "/api/v2/streams/mjpeg"
    "/api/v2/actions/camera/capture/"
    "/api/v2/actions/camera/preview/start"
    "/api/v2/docs/swagger-ui"
  )
  local p c
  for p in "${paths[@]}"; do
    c=$(curl_get_code "${BASE}${p}")
    echo "${c}	${p}"
  done
}

cmd_check() {
  echo "base: ${BASE}"
  local c
  c=$(curl_get_code "${BASE}/api/v2/instrument/configuration")
  [[ "$c" == 2* ]] || die "configuration HTTP ${c}"

  echo "== camera (from configuration)"
  curl_get "${BASE}/api/v2/instrument/configuration" | python3 -c "
import json,sys
d=json.load(sys.stdin).get('camera') or {}
for k in ('type','board'):
    if k in d: print(f'  {k}: {d[k]!r}')
if not d: sys.exit('no camera block in configuration')
" || die "parse configuration"

  echo "== GET /api/v2/streams/snapshot (expect JPEG)"
  local tmp
  tmp=$(mktemp -t of_snap.XXXXXX.jpg)
  curl -sS --connect-timeout "$CTO" -o "$tmp" "${BASE}/api/v2/streams/snapshot" || die "snapshot curl failed"
  verify_magic "$tmp" jpeg
  local sz
  sz=$(wc -c <"$tmp" | tr -d ' ')
  echo "  OK (${sz} bytes)"
  rm -f "$tmp"

  echo "== GET /api/v2/instrument/camera/lst (expect PNG tile)"
  tmp=$(mktemp -t of_lst.XXXXXX.png)
  curl -sS --connect-timeout "$CTO" -o "$tmp" "${BASE}/api/v2/instrument/camera/lst" || die "camera/lst curl failed"
  verify_magic "$tmp" png
  sz=$(wc -c <"$tmp" | tr -d ' ')
  echo "  OK (${sz} bytes)"
  rm -f "$tmp"

  echo "check: all camera probes OK"
}

cmd_snapshot() {
  local out="${1:-./openflexure_camera_snapshot.jpg}"
  curl -sS --connect-timeout "$CTO" -o "$out" "${BASE}/api/v2/streams/snapshot" || die "snapshot failed"
  verify_magic "$out" jpeg
  echo "wrote ${out} ($(wc -c <"$out" | tr -d ' ') bytes)"
}

cmd_capture() {
  local name="${1:-of_capture_$(date +%s)}"
  local body
  body=$(CAPTURE_NAME="$name" python3 -c 'import json,os; print(json.dumps({"filename": os.environ["CAPTURE_NAME"]}))')
  local resp
  resp=$(curl_post_json "${BASE}/api/v2/actions/camera/capture/" "$body") || die "capture POST failed"
  echo "$resp"
  local id
  id=$(echo "$resp" | extract_action_id)
  [[ -n "$id" ]] && wait_action "$id"
}

cmd_preview_start() {
  local resp
  resp=$(curl_post_json "${BASE}/api/v2/actions/camera/preview/start/" "$PREVIEW_JSON") \
    || die "preview-start failed"
  echo "$resp"
  local id
  id=$(echo "$resp" | extract_action_id)
  [[ -n "$id" ]] && wait_action "$id"
}

cmd_preview_stop() {
  local resp
  resp=$(curl_post_json "${BASE}/api/v2/actions/camera/preview/stop/" '{}') || die "preview-stop failed"
  echo "$resp"
  local id
  id=$(echo "$resp" | extract_action_id)
  [[ -n "$id" ]] && wait_action "$id"
}

cmd_all() {
  cmd_check
  local tmp
  tmp=$(mktemp -t of_cam_all.XXXXXX.jpg)
  cmd_snapshot "$tmp"
  rm -f "$tmp"
  if [[ "${SKIP_CAPTURE:-0}" == "1" ]]; then
    echo "SKIP_CAPTURE=1: not running disk capture"
    return 0
  fi
  cmd_capture "of_diag_all_$(date +%s)"
}

main() {
  local cmd="${1:-}"
  [[ -n "$cmd" ]] || usage 1
  shift || true
  case "$cmd" in
    -h|--help|help) usage 0 ;;
    check) cmd_check ;;
    snapshot) cmd_snapshot "${1:-}" ;;
    capture) cmd_capture "${1:-}" ;;
    preview-start) cmd_preview_start ;;
    preview-stop) cmd_preview_stop ;;
    probe) cmd_probe ;;
    all) cmd_all ;;
    *) die "unknown command: $cmd" ;;
  esac
}

main "$@"
