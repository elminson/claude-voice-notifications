#!/bin/bash
# TTS/sound notification when Claude Code finishes a task.
# Mode "sound" : plays configured sound only
# Mode "tts"   : speaks "work done" only
# Mode "both"  : plays sound first, then speaks (default when sound is configured)
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

# Look up per-project sound + mode config
# Config file: ~/.claude/voice-notifications-sounds.json
# Format: {"projects": {"proj": {"done": "Glass", "input": "Ping", "mode": "both"}}, "defaults": {...}}
# mode values: "sound" (sound only), "tts" (voice only), "both" (sound then voice)
SOUND=""
MODE=""
SOUNDS_FILE="${HOME}/.claude/voice-notifications-sounds.json"
if [ -f "$SOUNDS_FILE" ] && [ -n "$PROJECT" ]; then
    if command -v jq &>/dev/null; then
        SOUND=$(jq -r --arg p "$PROJECT" \
            '.projects[$p].done // .defaults.done // empty' \
            "$SOUNDS_FILE" 2>/dev/null | grep -v '^null$')
        MODE=$(jq -r --arg p "$PROJECT" \
            '.projects[$p].mode // .defaults.mode // empty' \
            "$SOUNDS_FILE" 2>/dev/null | grep -v '^null$')
    elif command -v python3 &>/dev/null; then
        _cfg=$(python3 - "$PROJECT" <<'PYEOF'
import json, sys
try:
    import os
    path = os.path.expanduser("~/.claude/voice-notifications-sounds.json")
    with open(path) as f:
        cfg = json.load(f)
    p = sys.argv[1]
    proj = cfg.get("projects", {}).get(p, {})
    defs = cfg.get("defaults", {})
    sound = proj.get("done") or defs.get("done") or ""
    mode  = proj.get("mode")  or defs.get("mode")  or ""
    print(sound + "|" + mode)
except Exception:
    print("|")
PYEOF
        )
        SOUND="${_cfg%%|*}"
        MODE="${_cfg##*|}"
    fi
fi

# Default mode: if a sound is configured use "both"; if not, use "tts"
if [ -z "$MODE" ]; then
    if [ -n "$SOUND" ]; then
        MODE="both"
    else
        MODE="tts"
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

# Play a sound file — blocking (for "both" mode, so it finishes before TTS starts)
play_sound_sync() {
    local file="$1"
    if command -v afplay &>/dev/null; then
        afplay "$file"
    elif command -v paplay &>/dev/null; then
        if [ -n "$DEVICE" ]; then
            paplay --device="$DEVICE" "$file"
        else
            paplay "$file"
        fi
    elif command -v aplay &>/dev/null; then
        aplay "$file"
    elif command -v mpv &>/dev/null; then
        mpv --no-video --quiet "$file"
    else
        return 1
    fi
    return 0
}

# Play a sound file — non-blocking (for "sound" only mode)
play_sound_async() {
    local file="$1"
    play_sound_sync "$file" &
}

# Play TTS — always async
play_tts() {
    local msg="$1"
    if command -v say &>/dev/null; then
        if [ -n "$DEVICE" ]; then
            say -a "$DEVICE" "$msg" &
        else
            say "$msg" &
        fi
    elif command -v espeak &>/dev/null; then
        espeak "$msg" &
    elif command -v python3 &>/dev/null && python3 -c "import gtts" 2>/dev/null; then
        python3 -c "
from gtts import gTTS
import sys
tts = gTTS(sys.argv[1], lang='en')
tts.save('/tmp/claude-notify-done.mp3')
" "$msg"
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
}

MSG="${SESSION_ID} ${PROJECT} claude code work done"

case "$MODE" in
    sound)
        # Sound effect only — no TTS
        SOUND_FILE=$(resolve_sound_file "$SOUND")
        if [ -n "$SOUND_FILE" ]; then
            play_sound_async "$SOUND_FILE"
        else
            # Sound configured but file not found — fall back to TTS
            play_tts "$MSG"
        fi
        ;;
    both)
        # Sound first (blocks until done), then TTS
        SOUND_FILE=$(resolve_sound_file "$SOUND")
        if [ -n "$SOUND_FILE" ]; then
            play_sound_sync "$SOUND_FILE"
        fi
        play_tts "$MSG"
        ;;
    tts|*)
        # TTS only
        play_tts "$MSG"
        ;;
esac
