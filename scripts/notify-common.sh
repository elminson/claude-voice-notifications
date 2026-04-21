#!/bin/bash
# Shared helpers for claude-voice-notifications.
# Sourced by notify-done.sh, notify-input.sh, and notify-escalate.sh.

SOUNDS_FILE="${HOME}/.claude/voice-notifications-sounds.json"
LOG_FILE="${HOME}/.claude/voice-notifications.log"

# ── Config lookup ─────────────────────────────────────────────────────────────

# _cfg PROJECT KEY — returns .projects[PROJECT][KEY] // .defaults[KEY] // ""
_cfg() {
    local project="$1" key="$2"
    if [ ! -f "$SOUNDS_FILE" ]; then echo ""; return; fi
    if command -v jq &>/dev/null; then
        jq -r --arg p "$project" --arg k "$key" \
            '.projects[$p][$k] // .defaults[$k] // empty' \
            "$SOUNDS_FILE" 2>/dev/null | grep -v '^null$'
    elif command -v python3 &>/dev/null; then
        python3 - "$project" "$key" <<'PYEOF'
import json, sys, os
try:
    with open(os.path.expanduser("~/.claude/voice-notifications-sounds.json")) as f:
        cfg = json.load(f)
    p, k = sys.argv[1], sys.argv[2]
    v = cfg.get("projects", {}).get(p, {}).get(k)
    if v is None:
        v = cfg.get("defaults", {}).get(k)
    print("" if v is None else str(v))
except Exception:
    print("")
PYEOF
    fi
}

# _global KEY [FALLBACK] — returns .global[KEY] // FALLBACK
_global() {
    local key="$1" fallback="${2:-}"
    if [ ! -f "$SOUNDS_FILE" ]; then echo "$fallback"; return; fi
    local val=""
    if command -v jq &>/dev/null; then
        val=$(jq -r --arg k "$key" '.global[$k] // empty' \
            "$SOUNDS_FILE" 2>/dev/null | grep -v '^null$')
    elif command -v python3 &>/dev/null; then
        val=$(python3 - "$key" <<'PYEOF'
import json, sys, os
try:
    with open(os.path.expanduser("~/.claude/voice-notifications-sounds.json")) as f:
        cfg = json.load(f)
    v = cfg.get("global", {}).get(sys.argv[1])
    print("" if v is None else str(v).lower())
except Exception:
    print("")
PYEOF
        )
    fi
    echo "${val:-$fallback}"
}

# ── Quiet hours ───────────────────────────────────────────────────────────────

is_quiet_hours() {
    local start="" end=""
    if [ -f "$SOUNDS_FILE" ]; then
        if command -v jq &>/dev/null; then
            start=$(jq -r '.global.quiet_hours.start // empty' "$SOUNDS_FILE" 2>/dev/null | grep -v '^null$')
            end=$(jq -r   '.global.quiet_hours.end   // empty' "$SOUNDS_FILE" 2>/dev/null | grep -v '^null$')
        elif command -v python3 &>/dev/null; then
            local pair
            pair=$(python3 - <<'PYEOF'
import json, os
try:
    with open(os.path.expanduser("~/.claude/voice-notifications-sounds.json")) as f:
        cfg = json.load(f)
    qh = cfg.get("global", {}).get("quiet_hours", {})
    print(qh.get("start", "") + "|" + qh.get("end", ""))
except Exception:
    print("|")
PYEOF
            )
            start="${pair%%|*}"; end="${pair##*|}"
        fi
    fi
    [ -z "$start" ] || [ -z "$end" ] && return 1   # not configured

    local now; now=$(date +%H:%M)
    if [[ "$start" < "$end" ]]; then
        # same-day range (e.g. 09:00-17:00)
        [[ ("$now" > "$start" || "$now" == "$start") && "$now" < "$end" ]] && return 0
    else
        # overnight range (e.g. 22:00-08:00)
        [[ "$now" > "$start" || "$now" == "$start" || "$now" < "$end" ]] && return 0
    fi
    return 1
}

# ── Banner notification ───────────────────────────────────────────────────────

# Logo for notifications — installed alongside the scripts
_NOTIFICATION_LOGO="${HOME}/.claude/voice-notifications/logo-notification.png"

send_banner() {
    local title="$1" message="$2"
    local enabled; enabled=$(_global "banner" "true")
    [ "$enabled" = "false" ] && return 0

    # Prefer terminal-notifier (supports custom app icon)
    # Install: brew install terminal-notifier
    if command -v terminal-notifier &>/dev/null; then
        local args=(-title "$title" -message "$message" -sender "com.apple.Terminal")
        [ -f "$_NOTIFICATION_LOGO" ] && args+=(-appIcon "$_NOTIFICATION_LOGO")
        terminal-notifier "${args[@]}" 2>/dev/null &
        return 0
    fi

    # Sanitize for AppleScript strings
    local safe_t="${title//\\/\\\\}";  safe_t="${safe_t//\"/\\\"}"
    local safe_m="${message//\\/\\\\}"; safe_m="${safe_m//\"/\\\"}"

    if command -v osascript &>/dev/null; then
        osascript -e "display notification \"${safe_m}\" with title \"${safe_t}\"" 2>/dev/null &
    elif command -v notify-send &>/dev/null; then
        # Linux: notify-send supports --icon
        if [ -f "$_NOTIFICATION_LOGO" ]; then
            notify-send --icon="$_NOTIFICATION_LOGO" "$title" "$message" 2>/dev/null &
        else
            notify-send "$title" "$message" 2>/dev/null &
        fi
    fi
}

# ── Logging ───────────────────────────────────────────────────────────────────

log_notification() {
    local type="$1" project="$2" extra="${3:-}"
    local enabled; enabled=$(_global "log" "true")
    [ "$enabled" = "false" ] && return 0
    printf '%s | %-22s | %-12s | %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$project" "$type" "$extra" \
        >> "$LOG_FILE" 2>/dev/null
}

# ── Sound resolution ──────────────────────────────────────────────────────────

resolve_sound_file() {
    local sound="$1"
    [ -z "$sound" ] && return 1
    [ "$sound" = "tts" ] && return 1

    local file="" user_sounds="${HOME}/.claude/voice-notifications/sounds"
    if   [[ "$sound" == /* ]];  then file="$sound"
    elif [[ "$sound" == ~* ]];  then file="${sound/#\~/$HOME}"
    else
        for candidate in \
            "/System/Library/Sounds/${sound}.aiff" \
            "/System/Library/Sounds/${sound}" \
            "${user_sounds}/${sound}" \
            "${user_sounds}/${sound}.wav" \
            "${user_sounds}/${sound}.aiff" \
            "${user_sounds}/${sound}.mp3" \
            "/usr/share/sounds/${sound}" \
            "/usr/share/sounds/freedesktop/stereo/${sound}.oga"
        do
            [ -f "$candidate" ] && file="$candidate" && break
        done
    fi
    [ -n "$file" ] && [ -f "$file" ] && echo "$file" && return 0
    return 1
}

# ── Audio playback ────────────────────────────────────────────────────────────

# play_sound_sync FILE [VOLUME] [DEVICE]  — blocks until done
play_sound_sync() {
    local file="$1" volume="${2:-1.0}" device="${3:-}"
    if command -v afplay &>/dev/null; then
        afplay -v "$volume" "$file"
    elif command -v paplay &>/dev/null; then
        local pa_vol
        pa_vol=$(python3 -c "print(int(float('${volume}')*65536))" 2>/dev/null || echo "65536")
        if [ -n "$device" ]; then paplay --volume="$pa_vol" --device="$device" "$file"
        else paplay --volume="$pa_vol" "$file"; fi
    elif command -v aplay &>/dev/null; then
        aplay "$file"
    elif command -v mpv &>/dev/null; then
        local mpv_vol
        mpv_vol=$(python3 -c "print(int(float('${volume}')*100))" 2>/dev/null || echo "100")
        if [ -n "$device" ]; then mpv --no-video --quiet --volume="$mpv_vol" --audio-device="pulse/$device" "$file"
        else mpv --no-video --quiet --volume="$mpv_vol" "$file"; fi
    else
        return 1
    fi
}

# play_sound_async FILE [VOLUME] [DEVICE]  — fire and forget
play_sound_async() { play_sound_sync "$@" & }

# play_tts MSG [VOICE] [DEVICE] [VOLUME]  — always async
# When volume ≠ 1.0 on macOS: generates AIFF via `say -o` then plays with afplay.
play_tts() {
    local msg="$1" voice="${2:-}" device="${3:-}" volume="${4:-1.0}"
    if command -v say &>/dev/null; then
        if command -v afplay &>/dev/null && [ -n "$volume" ] && [ "$volume" != "1.0" ]; then
            (
                local tmpfile; tmpfile=$(mktemp /tmp/claude-tts-XXXXXX.aiff)
                local sargs=(); [ -n "$voice" ] && sargs+=(-v "$voice")
                if say "${sargs[@]}" -o "$tmpfile" "$msg" 2>/dev/null && [ -f "$tmpfile" ]; then
                    play_sound_sync "$tmpfile" "$volume" "$device"
                else
                    local fargs=()
                    [ -n "$voice"  ] && fargs+=(-v "$voice")
                    [ -n "$device" ] && fargs+=(-a "$device")
                    say "${fargs[@]}" "$msg"
                fi
                rm -f "$tmpfile"
            ) &
            return 0
        fi
        local args=()
        [ -n "$voice"  ] && args+=(-v "$voice")
        [ -n "$device" ] && args+=(-a "$device")
        say "${args[@]}" "$msg" &
    elif command -v espeak &>/dev/null; then
        espeak "$msg" &
    elif command -v python3 &>/dev/null && python3 -c "import gtts" 2>/dev/null; then
        local tmpfile; tmpfile=$(mktemp /tmp/claude-tts-XXXXXX.mp3)
        python3 -c "
from gtts import gTTS; import sys
gTTS(sys.argv[1], lang='en').save(sys.argv[2])
" "$msg" "$tmpfile" 2>/dev/null
        if command -v paplay &>/dev/null; then
            if [ -n "$device" ]; then
                paplay --device="$device" "$tmpfile" &
            else
                paplay "$tmpfile" &
            fi
        elif command -v mpv &>/dev/null; then
            if [ -n "$device" ]; then
                mpv --no-video --quiet --audio-device="pulse/$device" "$tmpfile" &
            else
                mpv --no-video --quiet "$tmpfile" &
            fi
        elif command -v aplay &>/dev/null; then
            local wav="${tmpfile%.mp3}.wav"
            ffmpeg -y -i "$tmpfile" "$wav" 2>/dev/null && aplay "$wav" &
        fi
    fi
}

# dispatch_audio SOUND MODE VOICE VOLUME DEVICE MSG
# Single entry point — resolves mode and plays the appropriate audio.
dispatch_audio() {
    local sound="$1" mode="$2" voice="$3" volume="${4:-1.0}" device="$5" msg="$6"
    [ -z "$mode" ] && mode=$([ -n "$sound" ] && echo "both" || echo "tts")

    local file; file=$(resolve_sound_file "$sound")

    case "$mode" in
        sound)
            if [ -n "$file" ]; then play_sound_async "$file" "$volume" "$device"
            else play_tts "$msg" "$voice" "$device" "$volume"; fi ;;
        both)
            [ -n "$file" ] && play_sound_sync "$file" "$volume" "$device"
            play_tts "$msg" "$voice" "$device" "$volume" ;;
        tts|*)
            play_tts "$msg" "$voice" "$device" "$volume" ;;
    esac
}
