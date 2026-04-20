#!/bin/bash
# Uninstall claude-voice-notifications
set -euo pipefail

INSTALL_DIR="${HOME}/.claude/voice-notifications"
DISABLED_FILE="${HOME}/.claude/voice-notifications-disabled"

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

# Remove disabled flag
if [ -f "$DISABLED_FILE" ]; then
    rm -f "$DISABLED_FILE"
fi

# Find and remove skill from project
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

    SETTINGS_FILE="${PROJECT_ROOT}/.claude/settings.json"
    if [ -f "$SETTINGS_FILE" ]; then
        echo "Removing hooks from ${SETTINGS_FILE}..."
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
}
fs.writeFileSync('${SETTINGS_FILE}', JSON.stringify(settings, null, 2) + '\n');
console.log('  Done.');
"
    fi
fi

echo ""
echo "=== Uninstall complete ==="
