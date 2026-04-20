# /voice-notification

Toggle voice notifications on or off for Claude Code. When enabled, you'll hear TTS alerts when Claude finishes a task or needs your input.

## Usage

```
/voice-notification        — show current status
/voice-notification on     — enable voice notifications
/voice-notification off    — disable voice notifications
```

## Arguments

- `on` — Enable notifications (removes the disabled flag)
- `off` — Disable notifications (creates a disabled flag file)
- *(no argument)* — Show whether notifications are currently on or off

## Instructions

The toggle works by creating or removing a flag file at `~/.claude/voice-notifications-disabled`. The notification scripts check for this file before playing audio.

When the user runs this skill:

1. Parse the argument from `$ARGUMENTS` (on, off, or empty)
2. Check for the flag file at `$HOME/.claude/voice-notifications-disabled`
3. Take action based on the argument:

**If argument is `on`:**
- Remove `$HOME/.claude/voice-notifications-disabled` if it exists
- Confirm: "Voice notifications enabled. You'll hear alerts when Claude finishes or needs input."

**If argument is `off`:**
- Create the file `$HOME/.claude/voice-notifications-disabled` with content `disabled`
- Confirm: "Voice notifications disabled. No audio alerts will play."

**If no argument (status check):**
- If the flag file exists, report: "Voice notifications are currently OFF. Use `/voice-notification on` to enable."
- If the flag file does not exist, report: "Voice notifications are currently ON. Use `/voice-notification off` to disable."

Use the Bash tool to check/create/remove the flag file. Do not read or modify settings.json — the scripts themselves check the flag file at runtime.
