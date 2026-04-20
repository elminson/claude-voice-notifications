#!/bin/bash
# TTS notification when Claude Code finishes a task.
# Plays: "<session-id> <project> claude code work done"
# Works on macOS (say) and in Linux/Docker (gTTS + PulseAudio or espeak)

# Check if notifications are disabled
DISABLED_FILE="${HOME}/.claude/voice-notifications-disabled"
if [ -f "$DISABLED_FILE" ]; then
    exit 0
fi

# Read hook JSON from stdin (non-blocking)
INPUT=""
if ! [ -t 0 ]; then
    INPUT=$(cat)
fi

# Determine session identifier from env or fallback
SESSION_ID="${CLAUDE_VOICE_SESSION_ID:-}"
if [ -z "$SESSION_ID" ] && [ -n "${SANDBOX_CLIPBOARD_FILE:-}" ]; then
    SESSION_ID=$(echo "$SANDBOX_CLIPBOARD_FILE" | sed 's/.*clipboard-\(.*\)-claude-sandbox.*/\1/')
fi
SESSION_ID="${SESSION_ID:-local}"

# Extract project folder from hook JSON cwd, or fall back to PWD
PROJECT=""
if [ -n "$INPUT" ] && command -v jq &>/dev/null; then
    PROJECT=$(echo "$INPUT" | jq -r '.cwd // .workspace.current_dir // empty' 2>/dev/null | xargs basename 2>/dev/null)
fi
if [ -z "$PROJECT" ]; then
    PROJECT=$(basename "${PWD}" 2>/dev/null)
fi

MSG="${SESSION_ID} ${PROJECT} claude code work done"

if command -v say &>/dev/null; then
    say "$MSG" &
elif command -v espeak &>/dev/null; then
    espeak "$MSG" &
elif command -v python3 &>/dev/null && python3 -c "import gtts" 2>/dev/null; then
    python3 -c "
from gtts import gTTS
import sys
tts = gTTS(sys.argv[1], lang='en')
tts.save('/tmp/claude-notify-done.mp3')
" "$MSG"
    if command -v paplay &>/dev/null; then
        paplay /tmp/claude-notify-done.mp3 &
    elif command -v mpv &>/dev/null; then
        mpv --no-video /tmp/claude-notify-done.mp3 &
    elif command -v aplay &>/dev/null; then
        ffmpeg -y -i /tmp/claude-notify-done.mp3 /tmp/claude-notify-done.wav 2>/dev/null
        aplay /tmp/claude-notify-done.wav &
    fi
fi
