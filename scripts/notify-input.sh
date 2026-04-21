#!/bin/bash
# TTS/sound notification when Claude Code needs user input (tool approval, questions, etc.)
# Mode "sound" : plays configured sound only
# Mode "tts"   : speaks "needs your input" only
# Mode "both"  : plays sound first, then speaks (default when sound is configured)
# Works on macOS (say/afplay) and Linux/Docker (gTTS + PulseAudio or espeak)

# Check if notifications are disabled
DISABLED_FILE="${HOME}/.claude/voice-notifications-disabled"
if [ -f "$DISABLED_FILE" ]; then
    exit 0
fi

# Read hook JSON from stdin FIRST — the pipe is only open at script start.
# Must happen before any sleep or the data is lost.
INPUT=""
if ! [ -t 0 ]; then
    INPUT=$(cat)
fi

# False-positive suppression:
# The Notification hook can fire slightly before the Stop hook for the same
# end-of-turn event (race condition). Sleep briefly so notify-done.sh has time
# to write its timestamp, then check whether a real Stop just happened.
# notify-done.sh only writes the timestamp for end_turn stops, so if the
# timestamp is recent it means Claude genuinely finished — this is a false positive.
LAST_STOP_FILE="${HOME}/.claude/voice-notifications-last-stop"
COOLDOWN_FILE="${HOME}/.claude/voice-notifications-cooldown"
COOLDOWN=3  # default seconds

if [ -f "$COOLDOWN_FILE" ]; then
    _raw=$(cat "$COOLDOWN_FILE" 2>/dev/null | tr -d '[:space:]')
    if [[ "$_raw" =~ ^[0-9]+$ ]]; then
        COOLDOWN="$_raw"
    fi
fi

if [ "$COOLDOWN" -gt 0 ] 2>/dev/null; then
    # Wait 1 second so any concurrent notify-done.sh can write its timestamp
    sleep 1
    if [ -f "$LAST_STOP_FILE" ]; then
        LAST_STOP=$(cat "$LAST_STOP_FILE" 2>/dev/null | tr -d '[:space:]')
        NOW=$(date +%s)
        if [[ "$LAST_STOP" =~ ^[0-9]+$ ]] && [ $(( NOW - LAST_STOP )) -le "$COOLDOWN" ] 2>/dev/null; then
            exit 0  # suppressed: a real end_turn Stop fired within the cooldown window
        fi
    fi
fi

# Read selected audio device (if configured)
DEVICE_FILE="${HOME}/.claude/voice-notifications-device"
DEVICE=""
if [ -f "$DEVICE_FILE" ]; then
    DEVICE=$(cat "$DEVICE_FILE" 2>/dev/null | tr -d '\n')
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

# Look up per-project sound + mode config
SOUND=""
MODE=""
SOUNDS_FILE="${HOME}/.claude/voice-notifications-sounds.json"
if [ -f "$SOUNDS_FILE" ] && [ -n "$PROJECT" ]; then
    if command -v jq &>/dev/null; then
        SOUND=$(jq -r --arg p "$PROJECT" \
            '.projects[$p].input // .defaults.input // empty' \
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
    sound = proj.get("input") or defs.get("input") or ""
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

# Play a sound file — blocking
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

# Play a sound file — non-blocking
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
tts.save('/tmp/claude-notify-input.mp3')
" "$msg"
        if command -v paplay &>/dev/null; then
            if [ -n "$DEVICE" ]; then
                paplay --device="$DEVICE" /tmp/claude-notify-input.mp3 &
            else
                paplay /tmp/claude-notify-input.mp3 &
            fi
        elif command -v mpv &>/dev/null; then
            if [ -n "$DEVICE" ]; then
                mpv --no-video --audio-device="pulse/$DEVICE" /tmp/claude-notify-input.mp3 &
            else
                mpv --no-video /tmp/claude-notify-input.mp3 &
            fi
        elif command -v aplay &>/dev/null; then
            ffmpeg -y -i /tmp/claude-notify-input.mp3 /tmp/claude-notify-input.wav 2>/dev/null
            aplay /tmp/claude-notify-input.wav &
        fi
    fi
}

MSG="${SESSION_ID} ${PROJECT} claude code needs your input"

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
