#!/usr/bin/env bash
# OpenFlexure microscope v2 HTTP diagnostics: online check + hardware/software signals
# for building monitoring / health checks.
#
# Env: OPENFLEXURE_BASE (default http://microscope.local:5000), CURL_CONNECT_TIMEOUT (default 8)
#      WARN_EMPTY_CAMERA_STATE=1  warn when /instrument/state camera is {} (idle scopes are often empty)
#
# Commands:
#   check       exit 0 OK, 1 hard fail, 2 warnings (stderr); STRICT_WARNINGS=1 -> warnings exit 1
#   summary     human-readable snapshot (default if no args)
#   json        one JSON line for log/metrics agents
#   discover    GET a curated path list + HTTP codes
#   inventory   parse /api/v2 Thing Description; list readproperty GET hrefs (no per-URL fetch)

set -u

BASE_RAW="${OPENFLEXURE_BASE:-http://microscope.local:5000}"
BASE="${BASE_RAW%/}"
CTO="${CURL_CONNECT_TIMEOUT:-8}"

usage() {
  cat >&2 <<EOF
usage: openflexure_diagnose.sh [check|summary|json|discover|inventory]

  check     Exit 0 OK, 1 hard fail (unreachable/bad state), 2 warnings only
            STRICT_WARNINGS=1: any warning makes check exit 1
            WARN_EMPTY_CAMERA_STATE=1: warn if live camera state is empty

  summary   Text report (default)
  json      Single JSON object to stdout
  discover  Probe common diagnostic URLs
  inventory Extract GET property URLs from /api/v2 Thing Description JSON

Env: OPENFLEXURE_BASE  CURL_CONNECT_TIMEOUT  STRICT_WARNINGS  WARN_EMPTY_CAMERA_STATE
EOF
  exit "${1:-0}"
}

die() { echo "error: $*" >&2; exit 1; }

code_for() {
  curl -sS --connect-timeout "$CTO" -o /dev/null -w '%{http_code}' "$1" 2>/dev/null || echo "000"
}

cmd_discover() {
  echo "base: ${BASE}"
  local paths=(
    "/api/v2/instrument/state"
    "/api/v2/instrument/state/stage/position"
    "/api/v2/instrument/state/stage"
    "/api/v2/instrument/state/camera"
    "/api/v2/instrument/configuration"
    "/api/v2/instrument/settings"
    "/api/v2/instrument/stage/type"
    "/api/v2/captures"
    "/api/v2/actions/"
    "/api/v2/extensions/org.openflexure.autostorage/location"
    "/api/v2/extensions/org.openflexure.autostorage/list-locations"
    "/api/v2/extensions/org.openflexure.zipbuilder/get"
    "/api/v2/extensions/org.openflexure.camera-stage-mapping/get_calibration"
    "/api/v2/docs/openapi.yaml"
  )
  local p u c
  for p in "${paths[@]}"; do
    u="${BASE}${p}"
    c=$(code_for "$u")
    echo "${c}	${p}"
  done
}

cmd_inventory() {
  echo "base: ${BASE}"
  curl -sS --connect-timeout "$CTO" "${BASE}/api/v2/" | python3 -c '
import json, sys
try:
    td = json.load(sys.stdin)
except Exception as e:
    print("error: could not parse /api/v2 as JSON:", e, file=sys.stderr)
    sys.exit(1)
seen = set()

def walk(o):
    if isinstance(o, dict):
        if "forms" in o and isinstance(o["forms"], list):
            for f in o["forms"]:
                if not isinstance(f, dict):
                    continue
                if f.get("op") == "readproperty" and f.get("htv:methodName") == "GET":
                    href = f.get("href")
                    if isinstance(href, str) and href not in seen:
                        seen.add(href)
        for v in o.values():
            walk(v)
    elif isinstance(o, list):
        for x in o:
            walk(x)

walk(td)
for href in sorted(seen):
    print(href)
'
}

python_core() {
  # Args: mode = check | summary | json
  local mode="$1"
  OPENFLEXURE_BASE="$BASE" CURL_CONNECT_TIMEOUT="$CTO" STRICT_WARNINGS="${STRICT_WARNINGS:-0}" \
    WARN_EMPTY_CAMERA_STATE="${WARN_EMPTY_CAMERA_STATE:-0}" \
    python3 - "$mode" <<'PY'
import json, os, sys, urllib.error, urllib.request

MODE = sys.argv[1]
BASE = os.environ.get("OPENFLEXURE_BASE", "http://microscope.local:5000").rstrip("/")
TIMEOUT = float(os.environ.get("CURL_CONNECT_TIMEOUT", "8"))
STRICT = os.environ.get("STRICT_WARNINGS", "0") == "1"
WARN_CAM = os.environ.get("WARN_EMPTY_CAMERA_STATE", "0") == "1"


def get_json(path: str):
    url = BASE + path
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            raw = r.read().decode()
            ctype = r.headers.get("Content-Type", "")
            if "yaml" in ctype or path.endswith(".yaml"):
                return r.status, raw
            return r.status, json.loads(raw)
    except urllib.error.HTTPError as e:
        try:
            body = e.read().decode()
        except Exception:
            body = ""
        return e.code, body
    except Exception as e:
        return None, str(e)


def as_stage_type_string(obj):
    if isinstance(obj, str):
        return obj.strip('"')
    return obj


issues: list[str] = []
warnings: list[str] = []
info: dict = {}

code, state = get_json("/api/v2/instrument/state")
info["instrument_state_http"] = code
if code != 200 or not isinstance(state, dict):
    issues.append(f"instrument/state not OK (http={code!r}, type={type(state).__name__})")
    state = {}

if isinstance(state, dict) and state:
    info["instrument_state_keys"] = sorted(state.keys())
    stage = state.get("stage") or {}
    pos = stage.get("position") or {}
    info["stage_position"] = pos
    if not all(k in pos for k in ("x", "y", "z")):
        warnings.append("stage.position missing x/y/z (partial state?)")
    cam = state.get("camera")
    info["camera_state"] = cam
    if cam == {} or cam is None:
        info["camera_state_empty"] = True
        if WARN_CAM:
            warnings.append("instrument/state camera subtree empty (set preview on or ignore)")

code_c, conf = get_json("/api/v2/instrument/configuration")
info["configuration_http"] = code_c
if code_c != 200 or not isinstance(conf, dict):
    issues.append(f"instrument/configuration not OK (http={code_c!r})")
    conf = {}
else:
    app = conf.get("application") or {}
    st = conf.get("stage") or {}
    cam = conf.get("camera") or {}
    info["application"] = app
    info["stage_configuration"] = st
    info["camera_configuration"] = {k: cam.get(k) for k in ("type", "board") if k in cam}
    for label, block in (("application", app), ("stage", st)):
        if not block:
            warnings.append(f"configuration.{label} empty")

code_t, stype = get_json("/api/v2/instrument/stage/type")
info["stage_type_http"] = code_t
if code_t != 200:
    warnings.append(f"instrument/stage/type http={code_t!r}")
else:
    t_prop = as_stage_type_string(stype)
    info["stage_type_property"] = t_prop
    t_conf = as_stage_type_string((conf.get("stage") or {}).get("type"))
    if t_conf and t_prop and t_conf != t_prop:
        warnings.append(f"stage type mismatch: configuration.stage.type={t_conf!r} vs property={t_prop!r}")

code_a, actions = get_json("/api/v2/actions/")
info["actions_http"] = code_a
if code_a != 200:
    warnings.append(f"actions/ list http={code_a!r}")
    actions = []
if isinstance(actions, list):
    bad = [a for a in actions if isinstance(a, dict) and a.get("status") not in (None, "completed", "cancelled", "canceled")]
    if bad:
        warnings.append(f"actions with non-terminal/non-success status: {len(bad)} (inspect GUI or GET each href)")
        info["actions_non_completed_sample"] = bad[:3]

# Optional: storage extension (common failure = disk full / unmounted)
code_l, loc = get_json("/api/v2/extensions/org.openflexure.autostorage/location")
info["autostorage_location_http"] = code_l
if code_l != 200:
    warnings.append(f"autostorage/location http={code_l!r} (extension missing or disabled)")

out = {
    "base": BASE,
    "ok": len(issues) == 0,
    "issues": issues,
    "warnings": warnings,
    "info": info,
}

if MODE == "json":
    print(json.dumps(out, separators=(",", ":")))
elif MODE == "summary":
    print(f"base: {BASE}")
    print(f"ok: {out['ok']}")
    if issues:
        print("issues:")
        for i in issues:
            print(f"  - {i}")
    if warnings:
        print("warnings:")
        for w in warnings:
            print(f"  - {w}")
    print("info:")
    if conf:
        app = conf.get("application") or {}
        st = conf.get("stage") or {}
        cam = conf.get("camera") or {}
        print(f"  server: {app.get('name')} {app.get('version')}")
        print(f"  stage: type={st.get('type')} board={st.get('board')} firmware={st.get('firmware')} port={st.get('port')}")
        print(f"  camera: type={cam.get('type')} board={cam.get('board')}")
    pos = (info.get("stage_position") or {})
    if pos:
        print(f"  live position: x={pos.get('x')} y={pos.get('y')} z={pos.get('z')}")
    if info.get("stage_type_property"):
        print(f"  stage type (property): {info.get('stage_type_property')}")
    if info.get("camera_state_empty"):
        print("  note: live camera state empty (common when preview/stream off)")
    if code_l == 200:
        print(f"  autostorage location: {loc!r}")
elif MODE == "check":
    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)
    for i in issues:
        print(f"error: {i}", file=sys.stderr)
    if issues:
        sys.exit(1)
    if warnings and STRICT:
        sys.exit(1)
    if warnings:
        sys.exit(2)
    sys.exit(0)
else:
    print("error: unknown mode", MODE, file=sys.stderr)
    sys.exit(1)
PY
}

main() {
  local cmd="${1:-summary}"
  case "$cmd" in
    -h|--help|help) usage 0 ;;
    check) python_core check ;;
    summary) python_core summary ;;
    json) python_core json ;;
    discover) cmd_discover ;;
    inventory) cmd_inventory ;;
    *) die "unknown: $cmd";;
  esac
}

main "$@"
