#!/usr/bin/env bash
# Probe microscope host over SSH ("shell"): TCP reachability + non-interactive SSH exec.
# Typical stack: Raspberry Pi + OpenFlexure server (often confused spelling: "OpenFlux").
#
# Usage:
#   ./scripts/test_microscope_shell_online.sh pi@192.168.1.50
#   ./scripts/test_microscope_shell_online.sh microscope.local
#
# Env:
#   SSH_USER        If target has no "user@" prefix, use this login (default: pi)
#   SSH_PORT        SSH port (default: 22)
#   SSH_OPTS        Extra ssh(1) options, space-separated string
#   SKIP_PING       Set to 1 to skip ICMP ping
#   SKIP_SSH_EXEC   Set to 1 to only test TCP to SSH port (no remote command)

set -u

die() { echo "error: $*" >&2; exit 1; }

target="${1:-}"
[[ -n "$target" ]] || die "usage: $0 [user@]host"

if [[ "$target" == *@* ]]; then
  ssh_user="${target%%@*}"
  ssh_host="${target#*@}"
else
  ssh_user="${SSH_USER:-pi}"
  ssh_host="$target"
fi

ssh_port="${SSH_PORT:-22}"
skip_ping="${SKIP_PING:-0}"
skip_ssh_exec="${SKIP_SSH_EXEC:-0}"

# shellcheck disable=SC2206
extra_ssh_opts=()
if [[ -n "${SSH_OPTS:-}" ]]; then
  # shellcheck disable=SC2206
  extra_ssh_opts=( $SSH_OPTS )
fi

echo "target: ${ssh_user}@${ssh_host} port=${ssh_port}"

if [[ "$skip_ping" != "1" ]]; then
  if command -v ping >/dev/null 2>&1; then
    echo -n "ping: "
    if [[ "$(uname -s)" == Darwin ]]; then
      ping_cmd=(ping -c 1 -W 2000 "$ssh_host")
    else
      ping_cmd=(ping -c 1 -W 2 "$ssh_host")
    fi
    if "${ping_cmd[@]}" >/dev/null 2>&1; then
      echo "ok"
    else
      echo "no reply (continuing; ICMP may be blocked)"
    fi
  else
    echo "ping: skipped (ping not found)"
  fi
fi

echo -n "tcp/${ssh_port}: "
if command -v nc >/dev/null 2>&1; then
  if nc -z -w 3 "$ssh_host" "$ssh_port" >/dev/null 2>&1; then
    echo "open"
  else
    echo "closed or filtered"
    exit 2
  fi
elif bash -c "exec 3<>/dev/tcp/${ssh_host}/${ssh_port}" 2>/dev/null; then
  echo "open"
  exec 3<&- 3>&- 2>/dev/null || true
else
  echo "cannot probe (install nc or use bash with /dev/tcp)"
  exit 2
fi

if [[ "$skip_ssh_exec" == "1" ]]; then
  echo "ssh exec: skipped (SKIP_SSH_EXEC=1)"
  echo "result: online (tcp only)"
  exit 0
fi

echo -n "ssh: "
# BatchMode=yes fails fast if a password would be required (no TTY).
# Bash 3.2 + set -u: "${arr[@]}" errors when arr is empty; use + guard.
if ssh \
  -o BatchMode=yes \
  -o ConnectTimeout=8 \
  -o StrictHostKeyChecking="${STRICT_HOST_KEY_CHECKING:-accept-new}" \
  -p "$ssh_port" \
  ${extra_ssh_opts[@]+"${extra_ssh_opts[@]}"} \
  "${ssh_user}@${ssh_host}" \
  'echo ok' >/dev/null 2>&1; then
  echo "shell reachable"
  echo "result: online"
  exit 0
fi

echo "failed (auth, banner, or remote shell)"
echo "hint: ensure SSH key is loaded, or run: ssh -p ${ssh_port} ${ssh_user}@${ssh_host}"
exit 3
