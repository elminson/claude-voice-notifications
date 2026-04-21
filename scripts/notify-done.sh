#!/bin/bash
# Notification when Claude Code finishes a task.
# Event types:  done (end_turn) · interrupted (max_tokens) · failure (error/other)
# Each type has its own sound key, message, and banner text.
# Set NOTIFY_TEST=1 to bypass stop_reason/quiet-hours checks during testing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=notify-common.sh
source "${SCRIPT_DIR}/notify-common.sh"

# ── Guards ────────────────────────────────────────────────────────────────────

[ -f "${HOME}/.claude/voice-notifications-disabled" ] && exit 0

# ── Read stdin immediately (pipe closes after script starts) ──────────────────
INPUT=""
if ! [ -t 0 ]; then INPUT=$(cat); fi

# ── Determine event type from stop_reason ─────────────────────────────────────
# end_turn   → Claude truly finished           → "work done"
# tool_use   → Intermediate tool call          → skip entirely
# max_tokens → Hit context limit               → "check this"
# error/*    → Something went wrong            → "error encountered"
STOP_REASON=""
if [ -n "$INPUT" ]; then
    if command -v jq &>/dev/null; then
        STOP_REASON=$(echo "$INPUT" | jq -r '.stop_reason // empty' 2>/dev/null | grep -v '^null$')
    elif command -v python3 &>/dev/null; then
        STOP_REASON=$(python3 -c "
import json,sys
try: print(json.loads(sys.stdin.read()).get('stop_reason',''))
except: print('')
" <<< "$INPUT" 2>/dev/null)
    fi
fi

EVENT_TYPE="done"
MSG_SUFFIX="work done"
BANNER_MSG="Work done"
SOUND_KEY="done"

if [ "${NOTIFY_TEST:-0}" != "1" ] && [ -n "$STOP_REASON" ]; then
    case "$STOP_REASON" in
        end_turn)  ;;   # defaults above are correct
        tool_use)  exit 0 ;;   # intermediate step — skip
        max_tokens)
            EVENT_TYPE="interrupted"
            MSG_SUFFIX="check this"
            BANNER_MSG="Check this — hit token limit"
            SOUND_KEY="failure" ;;
        *)
            EVENT_TYPE="failure"
            MSG_SUFFIX="error encountered"
            BANNER_MSG="Error encountered"
            SOUND_KEY="failure" ;;
    esac
fi

# ── Quiet hours ───────────────────────────────────────────────────────────────
[ "${NOTIFY_TEST:-0}" != "1" ] && is_quiet_hours && exit 0

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

# ── Timestamps ────────────────────────────────────────────────────────────────
# Write last-stop (only for genuine completions — not tool_use which already exited)
echo "$(date +%s)" > "${HOME}/.claude/voice-notifications-last-stop"
# Cancel any pending escalation for this project
echo "0" > "${HOME}/.claude/voice-notifications-last-input"

# ── Per-project config ────────────────────────────────────────────────────────
DEVICE=""
DEVICE_FILE="${HOME}/.claude/voice-notifications-device"
[ -f "$DEVICE_FILE" ] && DEVICE=$(cat "$DEVICE_FILE" 2>/dev/null | tr -d '\n')

SOUND=$(_cfg "$PROJECT" "$SOUND_KEY")
VOICE=$(_cfg "$PROJECT" "voice")
VOLUME=$(_cfg "$PROJECT" "volume"); VOLUME="${VOLUME:-1.0}"
MODE=$(_cfg "$PROJECT" "mode")

# ── Banner ────────────────────────────────────────────────────────────────────
send_banner "Claude Code — $PROJECT" "$BANNER_MSG"

# ── Log ───────────────────────────────────────────────────────────────────────
log_notification "$EVENT_TYPE" "$PROJECT" "stop_reason=${STOP_REASON:-end_turn}"

# ── Audio ─────────────────────────────────────────────────────────────────────
MSG="${SESSION_ID} ${PROJECT} ${MSG_SUFFIX}"
dispatch_audio "$SOUND" "$MODE" "$VOICE" "$VOLUME" "$DEVICE" "$MSG"
