# Codex Telegram Notifications

When you run Codex CLI on a VPS, you do not need to keep watching the terminal
while it works. Step away to focus on something else or take a break, and this
small script will send a Telegram message to your phone as soon as Codex
finishes a task.

Send a Telegram message to your phone after each completed Codex turn.

## Setup

Before running the setup script:

1. Open `@BotFather` in Telegram, create a bot, and copy its Bot Token.
2. Send a message to the new bot.
3. Get the Chat ID by opening
   `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates` and finding
   `message.chat.id` in the response.

Run:

```bash
chmod +x init.sh
./init.sh
```

The setup script asks for the Bot Token and Chat ID, validates them, sends a test message, and:

- Installs `~/.local/bin/telegram_notify.sh`.
- Stores credentials in `~/.config/codex-telegram-notify/config` with mode `600`.
- Configures Codex `notify` in the user-level `~/.codex/config.toml`.

Restart Codex after setup. Project-level `.codex/config.toml` does not support
`notify`, so the setup script updates the user-level configuration.

## Reconfigure

Run `./init.sh` again to update the Token, Chat ID, or notifier. The `notify`
entry will not be duplicated.
