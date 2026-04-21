#!/bin/bash
# Uninstall claude-voice-notifications
set -euo pipefail

INSTALL_DIR="${HOME}/.claude/voice-notifications"
DISABLED_FILE="${HOME}/.claude/voice-notifications-disabled"
SETTINGS_FILE="${HOME}/.claude/settings.json"
COOLDOWN_FILE="${HOME}/.claude/voice-notifications-cooldown"
LAST_STOP_FILE="${HOME}/.claude/voice-notifications-last-stop"
LAST_INPUT_FILE="${HOME}/.claude/voice-notifications-last-input"

echo "=== Claude Voice Notifications Uninstaller ==="
echo ""

# Remove scripts
if [ -d "$INSTALL_DIR" ]; then
    echo "Removing ${INSTALL_DIR}..."
    rm -rf "$INSTALL_DIR"
    echo "  Done."
else
    echo "Scripts not found at ${INSTALL_DIR} — skipping."
fi

# Remove runtime flag files
rm -f "$DISABLED_FILE" "$COOLDOWN_FILE" "$LAST_STOP_FILE" "$LAST_INPUT_FILE"

# Remove hooks from ~/.claude/settings.json
if [ -f "$SETTINGS_FILE" ]; then
    echo "Removing hooks from ${SETTINGS_FILE}..."
    if command -v node &>/dev/null; then
        node -e "
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync('${SETTINGS_FILE}', 'utf8'));
if (settings.hooks) {
    if (settings.hooks.Notification) {
        settings.hooks.Notification = settings.hooks.Notification.filter(h =>
            !(h.hooks && h.hooks.some(hh => hh.command && hh.command.includes('notify-input')))
        );
        if (settings.hooks.Notification.length === 0) delete settings.hooks.Notification;
    }
    if (settings.hooks.Stop) {
        settings.hooks.Stop = settings.hooks.Stop.filter(h =>
            !(h.hooks && h.hooks.some(hh => hh.command && hh.command.includes('notify-done')))
        );
        if (settings.hooks.Stop.length === 0) delete settings.hooks.Stop;
    }
    if (Object.keys(settings.hooks).length === 0) delete settings.hooks;
}
fs.writeFileSync('${SETTINGS_FILE}', JSON.stringify(settings, null, 2) + '\n');
console.log('  Done.');
"
    elif command -v python3 &>/dev/null; then
        python3 -c "
import json, os
path = os.path.expanduser('${SETTINGS_FILE}')
with open(path) as f:
    settings = json.load(f)
hooks = settings.get('hooks', {})
if 'Notification' in hooks:
    hooks['Notification'] = [h for h in hooks['Notification'] if not any('notify-input' in hh.get('command', '') for hh in h.get('hooks', []))]
    if not hooks['Notification']: del hooks['Notification']
if 'Stop' in hooks:
    hooks['Stop'] = [h for h in hooks['Stop'] if not any('notify-done' in hh.get('command', '') for hh in h.get('hooks', []))]
    if not hooks['Stop']: del hooks['Stop']
if not hooks: settings.pop('hooks', None)
with open(path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')
print('  Done.')
"
    else
        echo "  WARNING: Neither node nor python3 found. Remove hooks manually from ${SETTINGS_FILE}"
    fi
fi

# Remove skill from project if found
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
    if [ -d "$SKILL_DIR" ]; then
        echo "Removing skill from ${SKILL_DIR}..."
        rm -rf "$SKILL_DIR"
        echo "  Done."
    fi
fi

echo ""
echo "=== Uninstall complete ==="
