#!/bin/bash
# Install claude-voice-notifications
# Copies scripts to ~/.claude/voice-notifications/ and adds hooks to ~/.claude/settings.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.claude/voice-notifications"
SETTINGS_FILE="${HOME}/.claude/settings.json"

echo "=== Claude Voice Notifications Installer ==="
echo ""

# --- Install scripts ---
echo "Installing scripts to ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"
cp "${SCRIPT_DIR}/scripts/notify-done.sh" "$INSTALL_DIR/"
cp "${SCRIPT_DIR}/scripts/notify-input.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR"/*.sh
echo "  Done."

# --- Install skill (to project if available, otherwise to user-level) ---
find_project_root() {
    local dir="$PWD"
    while [ "$dir" != "/" ]; do
        if [ -d "$dir/.claude" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

PROJECT_ROOT=$(find_project_root 2>/dev/null || echo "")
if [ -n "$PROJECT_ROOT" ]; then
    SKILL_DIR="${PROJECT_ROOT}/.claude/skills/voice-notification"
    echo "Installing skill to ${SKILL_DIR}..."
    mkdir -p "$SKILL_DIR"
    cp "${SCRIPT_DIR}/skill/voice-notification/SKILL.md" "$SKILL_DIR/"
    echo "  Done."
else
    echo "NOTE: No project .claude/ directory found. Skill not installed to project."
    echo "  To use /voice-notification, copy skill/voice-notification/ to your project's .claude/skills/"
fi

# --- Update ~/.claude/settings.json hooks ---
echo ""
echo "Updating hooks in ${SETTINGS_FILE}..."

mkdir -p "${HOME}/.claude"
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "{}" > "$SETTINGS_FILE"
fi

# Detect if node is available; fall back to python3; fall back to manual instructions
if command -v node &>/dev/null; then
    node -e "
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync('${SETTINGS_FILE}', 'utf8'));

if (!settings.hooks) settings.hooks = {};

const notifHook = {
    hooks: [{
        type: 'command',
        command: '\"\$HOME\"/.claude/voice-notifications/notify-input.sh',
        timeout: 15,
        statusMessage: 'Playing input notification...'
    }]
};

const stopHook = {
    hooks: [{
        type: 'command',
        command: '\"\$HOME\"/.claude/voice-notifications/notify-done.sh',
        timeout: 15,
        statusMessage: 'Playing done notification...'
    }]
};

const hasNotif = (settings.hooks.Notification || []).some(h =>
    h.hooks && h.hooks.some(hh => hh.command && hh.command.includes('notify-input'))
);
if (!hasNotif) {
    if (!settings.hooks.Notification) settings.hooks.Notification = [];
    settings.hooks.Notification.push(notifHook);
    console.log('  Added Notification hook (notify-input.sh)');
}

const hasStop = (settings.hooks.Stop || []).some(h =>
    h.hooks && h.hooks.some(hh => hh.command && hh.command.includes('notify-done'))
);
if (!hasStop) {
    if (!settings.hooks.Stop) settings.hooks.Stop = [];
    settings.hooks.Stop.push(stopHook);
    console.log('  Added Stop hook (notify-done.sh)');
}

fs.writeFileSync('${SETTINGS_FILE}', JSON.stringify(settings, null, 2) + '\n');
"
elif command -v python3 &>/dev/null; then
    python3 -c "
import json, os
path = os.path.expanduser('${SETTINGS_FILE}')
with open(path) as f:
    settings = json.load(f)

settings.setdefault('hooks', {})

notif_hook = {'hooks': [{'type': 'command', 'command': '\"\$HOME\"/.claude/voice-notifications/notify-input.sh', 'timeout': 15, 'statusMessage': 'Playing input notification...'}]}
stop_hook = {'hooks': [{'type': 'command', 'command': '\"\$HOME\"/.claude/voice-notifications/notify-done.sh', 'timeout': 15, 'statusMessage': 'Playing done notification...'}]}

has_notif = any(
    any('notify-input' in hh.get('command', '') for hh in h.get('hooks', []))
    for h in settings['hooks'].get('Notification', [])
)
if not has_notif:
    settings['hooks'].setdefault('Notification', []).append(notif_hook)
    print('  Added Notification hook (notify-input.sh)')

has_stop = any(
    any('notify-done' in hh.get('command', '') for hh in h.get('hooks', []))
    for h in settings['hooks'].get('Stop', [])
)
if not has_stop:
    settings['hooks'].setdefault('Stop', []).append(stop_hook)
    print('  Added Stop hook (notify-done.sh)')

with open(path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
"
else
    echo "WARNING: Neither node nor python3 found. Add hooks manually to ${SETTINGS_FILE}:"
    echo ""
    cat <<'HOOKS'
{
  "hooks": {
    "Notification": [
      { "hooks": [{ "type": "command", "command": "\"$HOME\"/.claude/voice-notifications/notify-input.sh", "timeout": 15 }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "\"$HOME\"/.claude/voice-notifications/notify-done.sh", "timeout": 15 }] }
    ]
  }
}
HOOKS
fi
echo "  Done."

echo ""
echo "=== Installation complete ==="
echo ""
echo "Hooks installed to: ${SETTINGS_FILE} (applies to ALL projects)"
echo "Voice notifications are ON by default."
echo "Use /voice-notification to toggle on/off inside Claude Code."
echo ""
echo "Environment variables (optional):"
echo "  CLAUDE_VOICE_SESSION_ID  - Custom session name for TTS (default: auto-detected or 'local')"
