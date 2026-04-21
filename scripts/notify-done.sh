#!/bin/bash
# TTS/sound notification when Claude Code finishes a task.
# Plays configured sound or TTS: "<session-id> <project> claude code work done"
# Works on macOS (say/afplay) and Linux/Docker (gTTS + PulseAudio or espeak)

# Check if notifications are disabled
DISABLED_FILE="${HOME}/.claude/voice-notifications-disabled"
if [ -f "$DISABLED_FILE" ]; then
    exit 0
fi

# Read selected audio device (if configured)
DEVICE_FILE="${HOME}/.claude/voice-notifications-device"
DEVICE=""
if [ -f "$DEVICE_FILE" ]; then
    DEVICE=$(cat "$DEVICE_FILE" 2>/dev/null | tr -d '\n')
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

# Record last-stop timestamp — used by notify-input.sh to suppress false positives
echo "$(date +%s)" > "${HOME}/.claude/voice-notifications-last-stop"

# Look up per-project sound config
# Config file: ~/.claude/voice-notifications-sounds.json
# Format: {"projects": {"my-project": {"done": "Glass", "input": "Ping"}}, "defaults": {"done": "", "input": ""}}
SOUND=""
SOUNDS_FILE="${HOME}/.claude/voice-notifications-sounds.json"
if [ -f "$SOUNDS_FILE" ] && [ -n "$PROJECT" ]; then
    if command -v jq &>/dev/null; then
        SOUND=$(jq -r --arg p "$PROJECT" \
            '.projects[$p].done // .defaults.done // empty' \
            "$SOUNDS_FILE" 2>/dev/null | grep -v '^null$')
    elif command -v python3 &>/dev/null; then
        SOUND=$(python3 - "$PROJECT" <<'PYEOF'
import json, sys
try:
    import os
    path = os.path.expanduser("~/.claude/voice-notifications-sounds.json")
    with open(path) as f:
        cfg = json.load(f)
    p = sys.argv[1]
    v = cfg.get("projects", {}).get(p, {}).get("done") or cfg.get("defaults", {}).get("done") or ""
    print(v)
except Exception:
    print("")
PYEOF
        )
    fi
fi

# Resolve a sound name/path to a playable file path.
# Accepts: macOS system sound names (Glass, Ping, …), absolute paths,
# ~/relative paths, or bare names looked up in ~/.claude/voice-notifications/sounds/
resolve_sound_file() {
    local sound="$1"
    [ -z "$sound" ] && return 1
    [ "$sound" = "tts" ] && return 1

    local file=""
    if [[ "$sound" == /* ]]; then
        file="$sound"
    elif [[ "$sound" == ~* ]]; then
        file="${sound/#\~/$HOME}"
    else
        local user_sounds="${HOME}/.claude/voice-notifications/sounds"
        for candidate in \
            "/System/Library/Sounds/${sound}.aiff" \
            "/System/Library/Sounds/${sound}" \
            "${user_sounds}/${sound}" \
            "${user_sounds}/${sound}.wav" \
            "${user_sounds}/${sound}.aiff" \
            "${user_sounds}/${sound}.mp3" \
            "/usr/share/sounds/${sound}" \
            "/usr/share/sounds/freedesktop/stereo/${sound}.oga" \
        ; do
            if [ -f "$candidate" ]; then
                file="$candidate"
                break
            fi
        done
    fi

    [ -z "$file" ] && return 1
    [ ! -f "$file" ] && return 1
    echo "$file"
}

# Play a resolved sound file using the best available player
play_sound_file() {
    local file="$1"
    if command -v afplay &>/dev/null; then
        afplay "$file" &
    elif command -v paplay &>/dev/null; then
        if [ -n "$DEVICE" ]; then
            paplay --device="$DEVICE" "$file" &
        else
            paplay "$file" &
        fi
    elif command -v aplay &>/dev/null; then
        aplay "$file" &
    elif command -v mpv &>/dev/null; then
        mpv --no-video --quiet "$file" &
    else
        return 1
    fi
    return 0
}

# Try configured sound first
if [ -n "$SOUND" ]; then
    SOUND_FILE=$(resolve_sound_file "$SOUND")
    if [ -n "$SOUND_FILE" ]; then
        play_sound_file "$SOUND_FILE"
        exit 0
    fi
fi

# Fall back to TTS
MSG="${SESSION_ID} ${PROJECT} claude code work done"

if command -v say &>/dev/null; then
    if [ -n "$DEVICE" ]; then
        say -a "$DEVICE" "$MSG" &
    else
        say "$MSG" &
    fi
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
        if [ -n "$DEVICE" ]; then
            paplay --device="$DEVICE" /tmp/claude-notify-done.mp3 &
        else
            paplay /tmp/claude-notify-done.mp3 &
        fi
    elif command -v mpv &>/dev/null; then
        if [ -n "$DEVICE" ]; then
            mpv --no-video --audio-device="pulse/$DEVICE" /tmp/claude-notify-done.mp3 &
        else
            mpv --no-video /tmp/claude-notify-done.mp3 &
        fi
    elif command -v aplay &>/dev/null; then
        ffmpeg -y -i /tmp/claude-notify-done.mp3 /tmp/claude-notify-done.wav 2>/dev/null
        aplay /tmp/claude-notify-done.wav &
    fi
fi
