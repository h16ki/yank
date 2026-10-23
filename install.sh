#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer is for macOS." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required: https://brew.sh" >&2
  exit 1
fi
brew list fzf >/dev/null 2>&1 || brew install fzf

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
install -m 755 "$SCRIPT_DIR/yank" "$BIN_DIR/yank"

PLIST_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$PLIST_DIR"
PLIST="$PLIST_DIR/local.yank.clipboard-watcher.plist"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>local.yank.clipboard-watcher</string>
  <key>ProgramArguments</key>
  <array><string>$BIN_DIR/yank</string><string>_watch</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$HOME/.yank-watcher.log</string>
  <key>StandardErrorPath</key><string>$HOME/.yank-watcher.log</string>
</dict>
</plist>
EOF

# Add ~/.local/bin to common shell startup files if needed.
for rc in "$HOME/.zprofile" "$HOME/.bash_profile"; do
  touch "$rc"
  if ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$rc"; then
    printf '\n# Local user commands\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc"
  fi
done

launchctl bootout "gui/$(id -u)" "$PLIST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl enable "gui/$(id -u)/local.yank.clipboard-watcher" || true

cat <<EOF

Installed yank.

1. Restart Terminal (or run: export PATH="$HOME/.local/bin:\$PATH")
2. Use: yank
   - yank 3       restore the 3rd newest clip
   - yank list 20 show the 20 most recent clips
3. After restoring a clip, press Command+V to paste.

History: $HOME/.yank_history
Watcher log: $HOME/.yank-watcher.log
To stop auto-recording: launchctl bootout gui/$(id -u) "$PLIST"
EOF
