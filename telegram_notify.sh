#!/usr/bin/env bash
set -u

# Codex passes one JSON object as the first argument to the notifier.
payload=${1:-'{}'}
config_file=${CODEX_TELEGRAM_CONFIG:-"${XDG_CONFIG_HOME:-$HOME/.config}/codex-telegram-notify/config"}

if [[ ! -r "$config_file" ]]; then
  exit 0
fi

bot_token=$(sed -n '1p' "$config_file")
chat_id=$(sed -n '2p' "$config_file")
if [[ -z "$bot_token" || -z "$chat_id" ]]; then
  exit 0
fi

readarray -t fields < <(
  python3 - "$payload" <<'PY'
import json
import os
import re
import subprocess
import sys

try:
    event = json.loads(sys.argv[1])
except (json.JSONDecodeError, IndexError):
    event = {}

event_type = str(event.get("type", ""))
if event_type and event_type != "agent-turn-complete":
    raise SystemExit(0)

cwd = str(event.get("cwd") or os.getcwd())
project = ""
try:
    remote = subprocess.run(["git", "-C", cwd, "remote", "get-url", "origin"], capture_output=True, text=True, timeout=3, check=False).stdout.strip()
    match = re.search(r"github\.com[:/]([^/]+)/([^/]+?)(?:\.git)?/?$", remote)
    if match:
        project = match.group(2)
except (OSError, subprocess.SubprocessError):
    pass
answer = str(event.get("last-assistant-message") or "Task completed")
answer = " ".join(answer.split())
if len(answer) > 1200:
    answer = answer[:1197] + "..."

print(project)
print(answer)
PY
)

project=${fields[0]:-}
answer=${fields[1]:-Task completed}
if [[ -n "$project" ]]; then
  message=$(printf '✅ Codex task completed\n\nProject: %s\nResult: %s' "$project" "$answer")
else
  message=$(printf '✅ Codex task completed\n\nResult: %s' "$answer")
fi

# A notification failure must never make the completed Codex task fail.
curl --silent --show-error --fail --max-time 15 \
  --request POST "https://api.telegram.org/bot${bot_token}/sendMessage" \
  --data-urlencode "chat_id=${chat_id}" \
  --data-urlencode "text=${message}" \
  >/dev/null 2>&1 || true

exit 0
