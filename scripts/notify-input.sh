#!/bin/bash
# Notification when Claude Code needs user input (tool approval, questions, etc.)
# Includes false-positive suppression and optional escalation re-fire.
# Set NOTIFY_TEST=1 to bypass cooldown/quiet-hours checks during testing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=notify-common.sh
source "${SCRIPT_DIR}/notify-common.sh"

# ── Guards ────────────────────────────────────────────────────────────────────
[ -f "${HOME}/.claude/voice-notifications-disabled" ] && exit 0

# ── Read stdin FIRST — pipe is only open at script start ─────────────────────
INPUT=""
if ! [ -t 0 ]; then INPUT=$(cat); fi

# ── Quiet hours ───────────────────────────────────────────────────────────────
[ "${NOTIFY_TEST:-0}" != "1" ] && is_quiet_hours && exit 0

# ── False-positive suppression ────────────────────────────────────────────────
# The Notification hook can fire milliseconds before the Stop hook for the same
# end-of-turn event. We sleep briefly, then check whether a genuine end_turn Stop
# just happened. notify-done.sh only writes last-stop for end_turn events, so a
# recent timestamp here means this notification is a false positive.
if [ "${NOTIFY_TEST:-0}" != "1" ]; then
    LAST_STOP_FILE="${HOME}/.claude/voice-notifications-last-stop"
    COOLDOWN_FILE="${HOME}/.claude/voice-notifications-cooldown"
    COOLDOWN=3

    if [ -f "$COOLDOWN_FILE" ]; then
        _raw=$(cat "$COOLDOWN_FILE" 2>/dev/null | tr -d '[:space:]')
        [[ "$_raw" =~ ^[0-9]+$ ]] && COOLDOWN="$_raw"
    fi

    if [ "$COOLDOWN" -gt 0 ] 2>/dev/null; then
        sleep 0.2
        if [ -f "$LAST_STOP_FILE" ]; then
            LAST_STOP=$(cat "$LAST_STOP_FILE" 2>/dev/null | tr -d '[:space:]')
            NOW=$(date +%s)
            if [[ "$LAST_STOP" =~ ^[0-9]+$ ]] \
               && [ $(( NOW - LAST_STOP )) -le "$COOLDOWN" ] 2>/dev/null; then
                exit 0   # suppressed: end_turn Stop fired within the cooldown window
            fi
        fi
    fi
fi

# ── Context ───────────────────────────────────────────────────────────────────
SESSION_ID="${CLAUDE_VOICE_SESSION_ID:-}"
if [ -z "$SESSION_ID" ] && [ -n "${SANDBOX_CLIPBOARD_FILE:-}" ]; then
    SESSION_ID=$(echo "$SANDBOX_CLIPBOARD_FILE" \
        | sed 's/.*clipboard-\(.*\)-claude-sandbox.*/\1/')
fi
SESSION_ID="${SESSION_ID:-local}"

PROJECT=""
if [ -n "$INPUT" ] && command -v jq &>/dev/null; then
    PROJECT=$(echo "$INPUT" \
        | jq -r '.cwd // .workspace.current_dir // empty' 2>/dev/null \
        | xargs basename 2>/dev/null)
fi
[ -z "$PROJECT" ] && PROJECT=$(basename "${PWD}" 2>/dev/null)

# ── Per-project config ────────────────────────────────────────────────────────
DEVICE=""
DEVICE_FILE="${HOME}/.claude/voice-notifications-device"
[ -f "$DEVICE_FILE" ] && DEVICE=$(cat "$DEVICE_FILE" 2>/dev/null | tr -d '\n')

SOUND=$(_cfg "$PROJECT" "input")
VOICE=$(_cfg "$PROJECT" "voice")
VOLUME=$(_cfg "$PROJECT" "volume"); VOLUME="${VOLUME:-1.0}"
MODE=$(_cfg "$PROJECT" "mode")
ESCALATE_AFTER=$(_cfg "$PROJECT" "escalate_after"); ESCALATE_AFTER="${ESCALATE_AFTER:-0}"

# ── Record input timestamp (used by escalation + cancellation in notify-done) ─
INPUT_TS=$(date +%s)
echo "$INPUT_TS" > "${HOME}/.claude/voice-notifications-last-input"

# ── Banner ────────────────────────────────────────────────────────────────────
send_banner "Claude Code — $PROJECT" "Needs your input"

# ── Log ───────────────────────────────────────────────────────────────────────
log_notification "input" "$PROJECT"

# ── Escalation ────────────────────────────────────────────────────────────────
# If the user doesn't respond within ESCALATE_AFTER seconds, re-fire.
if [ "$ESCALATE_AFTER" -gt 0 ] 2>/dev/null; then
    "${SCRIPT_DIR}/notify-escalate.sh" "$PROJECT" "$INPUT_TS" "$ESCALATE_AFTER" &
fi

# ── Audio ─────────────────────────────────────────────────────────────────────
MSG="${SESSION_ID} ${PROJECT} claude code needs your input"
dispatch_audio "$SOUND" "$MODE" "$VOICE" "$VOLUME" "$DEVICE" "$MSG"
