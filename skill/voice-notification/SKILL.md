# /voice-notification

Toggle voice notifications on or off, and select the audio output device.

## Usage

```
/voice-notification              — show current status and device
/voice-notification on           — enable voice notifications
/voice-notification off          — disable voice notifications
/voice-notification devices      — list available audio output devices
/voice-notification device <id>  — set the output device
```

## Arguments

- `on` — Enable notifications (removes the disabled flag)
- `off` — Disable notifications (creates a disabled flag file)
- `devices` — List available audio output devices
- `device <id>` — Set the output device by name/ID
- *(no argument)* — Show current status and selected device

## Instructions

### Config files

| File | Purpose |
|------|---------|
| `~/.claude/voice-notifications-disabled` | Flag file — if it exists, notifications are off |
| `~/.claude/voice-notifications-device` | Contains the selected audio device name/ID |

The notification scripts check these files at runtime.

### How to handle each argument

**If argument is `on`:**
- Remove `$HOME/.claude/voice-notifications-disabled` if it exists
- Confirm: "Voice notifications enabled. You'll hear alerts when Claude finishes or needs input."

**If argument is `off`:**
- Create the file `$HOME/.claude/voice-notifications-disabled` with content `disabled`
- Confirm: "Voice notifications disabled. No audio alerts will play."

**If argument is `devices`:**
- Detect the platform and list available audio output devices:
  - **macOS (no PulseAudio):** Run `system_profiler SPAudioDataType 2>/dev/null` and extract device names. If that fails, try `say -a '?'` to list audio devices.
  - **Linux / PulseAudio:** Run `pactl list sinks short 2>/dev/null` to list sink names (column 2 is the device name).
- Read the current device from `$HOME/.claude/voice-notifications-device` (if it exists).
- Present the list to the user using AskUserQuestion with the available devices as options, marking the currently selected one with "(Current)" in the label. If there are more than 4 devices, show the first 3 plus let the user type "Other" for a custom device name.
- After the user selects, write the chosen device name to `$HOME/.claude/voice-notifications-device`.
- Confirm: "Audio output set to: <device-name>"

**If argument is `device <id>`:**
- Write the device ID/name to `$HOME/.claude/voice-notifications-device`
- Confirm: "Audio output set to: <id>"

**If no argument (status check):**
- Check if `$HOME/.claude/voice-notifications-disabled` exists
- Check if `$HOME/.claude/voice-notifications-device` exists and read its content
- Report status, e.g.:
  - "Voice notifications are ON, output device: MacBook Pro Speakers"
  - "Voice notifications are OFF. Use `/voice-notification on` to enable."
  - If no device file: "Voice notifications are ON, output device: system default"

### Important

- Use the Bash tool to check/create/remove files and list devices.
- Do NOT modify settings.json — the scripts check config files at runtime.
- When listing devices, always show the raw device name/ID that should be written to the config file.
