#!/bin/bash
# Install claude-voice-notifications
# Copies scripts to ~/.claude/voice-notifications/ and installs the skill
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.claude/voice-notifications"
SKILL_DIR=""

echo "=== Claude Voice Notifications Installer ==="
echo ""

# --- Install scripts ---
echo "Installing scripts to ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"
cp "${SCRIPT_DIR}/scripts/notify-done.sh" "$INSTALL_DIR/"
cp "${SCRIPT_DIR}/scripts/notify-input.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR"/*.sh
echo "  Done."

# --- Install skill ---
# Detect project root: walk up from cwd looking for .claude/ directory
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
    echo "WARNING: No .claude/ project directory found. Skill not installed."
    echo "  To install manually, copy skill/voice-notification/ to your project's .claude/skills/"
fi

# --- Update settings.json hooks ---
SETTINGS_FILE="${PROJECT_ROOT:+${PROJECT_ROOT}/.claude/settings.json}"
if [ -n "$SETTINGS_FILE" ] && [ -f "$SETTINGS_FILE" ]; then
    echo ""
    echo "Updating hooks in ${SETTINGS_FILE}..."

    # Use node to safely merge hooks into settings.json
    node -e "
const fs = require('fs');
const settings = JSON.parse(fs.readFileSync('${SETTINGS_FILE}', 'utf8'));

if (!settings.hooks) settings.hooks = {};

// Add Notification hook (notify-input)
const notifHook = {
    hooks: [{
        type: 'command',
        command: '\"\$HOME\"/.claude/voice-notifications/notify-input.sh',
        timeout: 15,
        statusMessage: 'Playing input notification...'
    }]
};

// Add Stop hook (notify-done)
const stopHook = {
    hooks: [{
        type: 'command',
        command: '\"\$HOME\"/.claude/voice-notifications/notify-done.sh',
        timeout: 15,
        statusMessage: 'Playing done notification...'
    }]
};

// Only add if not already present
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
    echo "  Done."
elif [ -n "$PROJECT_ROOT" ]; then
    echo ""
    echo "No settings.json found. Add these hooks manually to .claude/settings.json:"
    echo ""
    cat <<'HOOKS'
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME\"/.claude/voice-notifications/notify-input.sh",
            "timeout": 15
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$HOME\"/.claude/voice-notifications/notify-done.sh",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
HOOKS
fi

echo ""
echo "=== Installation complete ==="
echo ""
echo "Voice notifications are ON by default."
echo "Use /voice-notification to toggle on/off inside Claude Code."
echo ""
echo "Environment variables (optional):"
echo "  CLAUDE_VOICE_SESSION_ID  - Custom session name for TTS (default: auto-detected or 'local')"
