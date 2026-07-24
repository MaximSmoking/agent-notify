#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
codex_dir=${CODEX_HOME:-"$HOME/.codex"}
config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/codex-telegram-notify
bin_dir=${XDG_BIN_HOME:-"$HOME/.local/bin"}
notifier="$bin_dir/telegram_notify.sh"
codex_config="$codex_dir/config.toml"

for command_name in curl python3 sed; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Error: missing dependency %s. Please install it first.\n' "$command_name" >&2
    exit 1
  fi
done

printf '\nCodex Telegram notification setup\n'
printf 'Create a bot with @BotFather, then send that bot a message.\n\n'

read -r -s -p 'Bot Token (input hidden): ' bot_token
printf '\n'
read -r -p 'Chat ID: ' chat_id

if [[ ! "$bot_token" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
  printf 'Error: invalid Bot Token format.\n' >&2
  exit 1
fi
if [[ ! "$chat_id" =~ ^-?[0-9]+$ ]]; then
  printf 'Error: Chat ID must be numeric (group IDs may start with a minus sign).\n' >&2
  exit 1
fi

printf 'Validating Bot Token...\n'
if ! curl --silent --show-error --fail --max-time 15 \
  "https://api.telegram.org/bot${bot_token}/getMe" >/dev/null; then
  printf 'Error: token validation failed. Check the token and network connection.\n' >&2
  exit 1
fi

printf 'Sending a test message...\n'
if ! curl --silent --show-error --fail --max-time 15 \
  --request POST "https://api.telegram.org/bot${bot_token}/sendMessage" \
  --data-urlencode "chat_id=${chat_id}" \
  --data-urlencode 'text=✅ Codex Telegram notification setup complete' >/dev/null; then
  printf 'Error: test message failed. Send a message to the bot and verify the Chat ID.\n' >&2
  exit 1
fi

mkdir -p "$config_dir" "$bin_dir" "$codex_dir"
install -m 700 "$script_dir/telegram_notify.sh" "$notifier"
printf '%s\n%s\n' "$bot_token" "$chat_id" >"$config_dir/config"
chmod 600 "$config_dir/config"

# `notify` is user-level only. Update an existing value or insert it before the
# first TOML table so it remains a top-level key.
python3 - "$codex_config" "$notifier" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
notifier = sys.argv[2]
line = 'notify = ["' + notifier.replace("\\", "\\\\").replace('"', '\\"') + '"]\n'
text = path.read_text() if path.exists() else ""
lines = text.splitlines(keepends=True)

top_level_notify = re.compile(r"^\s*notify\s*=")
replaced = False
inside_table = False
for index, current in enumerate(lines):
    stripped = current.lstrip()
    if stripped.startswith("["):
        inside_table = True
    if not inside_table and top_level_notify.match(current):
        lines[index] = line
        replaced = True
        break

if not replaced:
    insert_at = next(
        (i for i, current in enumerate(lines) if current.lstrip().startswith("[")),
        len(lines),
    )
    prefix = [] if insert_at == 0 or lines[insert_at - 1].endswith("\n") else ["\n"]
    lines[insert_at:insert_at] = prefix + [line, "\n"]

path.write_text("".join(lines))
PY
chmod 600 "$codex_config"

printf '\nSetup complete!\n'
printf 'Notifier: %s\n' "$notifier"
printf 'Codex config: %s\n' "$codex_config"
printf 'Restart Codex. A Telegram message will be sent after each completed turn.\n'
