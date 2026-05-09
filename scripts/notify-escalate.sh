#!/bin/bash
# Escalation re-fire: if the user hasn't responded after WAIT_SECS, repeat the
# "needs your input" notification once more (slightly louder / more insistent).
#
# Called by notify-input.sh in the background:
#   notify-escalate.sh PROJECT EXPECTED_INPUT_TS WAIT_SECS
#
# The escalation is cancelled when:
#   - notify-done.sh fires (writes "0" to last-input → timestamp mismatch)
#   - A new input notification arrives (overwrites last-input with a newer timestamp)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=notify-common.sh
source "${SCRIPT_DIR}/notify-common.sh"

PROJECT="${1:-}"
EXPECTED_TS="${2:-}"
WAIT_SECS="${3:-30}"

[ -z "$PROJECT" ] || [ -z "$EXPECTED_TS" ] && exit 0

sleep "$WAIT_SECS"

# Still pending? Check that last-input timestamp hasn't changed.
LAST_INPUT_FILE="${HOME}/.claude/voice-notifications-last-input"
[ ! -f "$LAST_INPUT_FILE" ] && exit 0

CURRENT_TS=$(cat "$LAST_INPUT_FILE" 2>/dev/null | tr -d '[:space:]')
[ "$CURRENT_TS" != "$EXPECTED_TS" ] && exit 0   # user responded or new event arrived

# Also respect disabled flag and quiet hours
[ -f "${HOME}/.claude/voice-notifications-disabled" ] && exit 0
is_quiet_hours && exit 0

# Re-fire with escalated volume (1.4×) and banner
DEVICE=""
DEVICE_FILE="${HOME}/.claude/voice-notifications-device"
[ -f "$DEVICE_FILE" ] && DEVICE=$(cat "$DEVICE_FILE" 2>/dev/null | tr -d '\n')

SOUND=$(_cfg "$PROJECT" "input")
VOICE=$(_cfg "$PROJECT" "voice")
VOLUME=$(_cfg "$PROJECT" "volume"); VOLUME="${VOLUME:-1.0}"
MODE=$(_cfg "$PROJECT" "mode")

# Escalate volume by 40% (cap at 2.0)
ESC_VOLUME=$(python3 -c "print(min(float('${VOLUME}') * 1.4, 2.0))" 2>/dev/null || echo "$VOLUME")

SESSION_ID="${CLAUDE_VOICE_SESSION_ID:-local}"
MSG="${SESSION_ID} ${PROJECT} still needs your input"

send_banner "Claude Code — $PROJECT" "Still waiting for your input"
log_notification "escalation" "$PROJECT" "after ${WAIT_SECS}s"
dispatch_audio "$SOUND" "$MODE" "$VOICE" "$ESC_VOLUME" "$DEVICE" "$MSG"
