# /voice-notification

Toggle voice notifications, select audio device, configure per-project sounds, and tune false-positive suppression.

## Usage

```
/voice-notification                          — show status
/voice-notification on                       — enable notifications
/voice-notification off                      — disable notifications
/voice-notification devices                  — list and select audio output device
/voice-notification device <id>              — set output device directly

/voice-notification sound <project> done <sound>   — set "work done" sound for a project
/voice-notification sound <project> input <sound>  — set "needs input" sound for a project
/voice-notification sound default done <sound>     — set default "work done" sound (all projects)
/voice-notification sound default input <sound>    — set default "needs input" sound (all projects)
/voice-notification sound <project> remove         — remove custom sounds for a project
/voice-notification sound list                     — list all configured sounds

/voice-notification cooldown <seconds>       — set false-positive cooldown (default: 3)
/voice-notification cooldown off             — disable cooldown (set to 0)
```

## Arguments

- `on` / `off` — Enable or disable all notifications
- `devices` — Interactively list and select audio output device
- `device <id>` — Set audio output device directly
- `sound ...` — Configure per-project sounds (see below)
- `cooldown <n>` — Set seconds to wait before firing an input notification after a done notification
- *(no argument)* — Show current status

## Instructions

### Config files

| File | Purpose |
|------|---------|
| `~/.claude/voice-notifications-disabled` | Flag — if present, all notifications silenced |
| `~/.claude/voice-notifications-device` | Selected audio device name/ID |
| `~/.claude/voice-notifications-sounds.json` | Per-project sound mappings |
| `~/.claude/voice-notifications-cooldown` | Cooldown seconds (integer, or `0` to disable) |
| `~/.claude/voice-notifications-last-stop` | Timestamp of last Stop event (written by notify-done.sh) |

---

### `on` / `off`

**If `on`:** Remove `$HOME/.claude/voice-notifications-disabled` if it exists.
Confirm: "Voice notifications enabled."

**If `off`:** Create `$HOME/.claude/voice-notifications-disabled` with content `disabled`.
Confirm: "Voice notifications disabled."

---

### `devices`

- macOS (no PulseAudio): run `system_profiler SPAudioDataType 2>/dev/null` and extract device names; or try `say -a '?'`.
- Linux / PulseAudio: run `pactl list sinks short 2>/dev/null` (column 2 = device name).
- Read current device from `$HOME/.claude/voice-notifications-device`.
- Use AskUserQuestion to let the user pick. Mark current selection with "(Current)".
- Write chosen name to `$HOME/.claude/voice-notifications-device`.
- Confirm: "Audio output set to: <device-name>"

**If `device <id>`:** Write `<id>` to `$HOME/.claude/voice-notifications-device`.
Confirm: "Audio output set to: <id>"

---

### `sound` subcommands

All sound config is stored in `~/.claude/voice-notifications-sounds.json`:

```json
{
  "defaults": { "done": "", "input": "" },
  "projects": {
    "project-1": { "done": "Glass",  "input": "Ping" },
    "project-2": { "done": "Bottle", "input": "Pop"  }
  }
}
```

**Sound values accepted:**
- **macOS system sound name** — `Glass`, `Ping`, `Pop`, `Bottle`, `Funk`, `Hero`, `Tink`, `Basso`, `Blow`, `Frog`, `Morse`, `Purr`, `Sosumi`, `Submarine` (played from `/System/Library/Sounds/<name>.aiff`)
- **Bare filename** — looked up in `~/.claude/voice-notifications/sounds/<name>[.wav|.aiff|.mp3]`
- **Absolute path** — `/path/to/sound.wav`
- **`tts`** — force TTS even if a default is set
- **`""` or remove** — revert to TTS

**`sound <project> done <sound>`:**
- Read `~/.claude/voice-notifications-sounds.json` (create it as `{}` if missing).
- Set `.projects["<project>"].done = "<sound>"`.
- Write back.
- Confirm: "Done sound for <project> set to: <sound>"

**`sound <project> input <sound>`:**
- Same, but set `.projects["<project>"].input`.
- Confirm: "Input sound for <project> set to: <sound>"

**`sound default done <sound>`:**
- Set `.defaults.done = "<sound>"`.
- Confirm: "Default done sound set to: <sound>"

**`sound default input <sound>`:**
- Set `.defaults.input = "<sound>"`.
- Confirm: "Default input sound set to: <sound>"

**`sound <project> remove`:**
- Delete `.projects["<project>"]` from the JSON.
- Confirm: "Sounds for <project> removed (will use defaults/TTS)."

**`sound list`:**
- Read `~/.claude/voice-notifications-sounds.json`.
- Display a table: project → done sound, input sound.
- Include the defaults row.
- If file missing or empty, say "No custom sounds configured. All projects use TTS."

**Implementation notes for `sound` commands:**
- Use python3 to read/write JSON. Load existing file, modify in-place, write back with `indent=2`.
- Preserve all existing keys when updating.
- If the file does not exist yet, create it with the minimal skeleton:
  ```json
  { "defaults": { "done": "", "input": "" }, "projects": {} }
  ```

---

### `cooldown <seconds>` / `cooldown off`

The cooldown suppresses "needs your input" notifications that fire within N seconds after a "work done" notification — these are false positives caused by Claude sending a follow-up event immediately after finishing work.

**`cooldown <n>`** (n is a positive integer):
- Write `<n>` to `$HOME/.claude/voice-notifications-cooldown`.
- Confirm: "False-positive cooldown set to <n> seconds."

**`cooldown off`** (or `cooldown 0`):
- Write `0` to `$HOME/.claude/voice-notifications-cooldown`.
- Confirm: "Cooldown disabled. All input notifications will play immediately."

---

### Status (no argument)

Read and display:
1. Enabled/disabled — check `$HOME/.claude/voice-notifications-disabled`
2. Audio device — read `$HOME/.claude/voice-notifications-device` (show "system default" if absent)
3. Cooldown — read `$HOME/.claude/voice-notifications-cooldown` (show "3s (default)" if absent)
4. Configured sounds — read `~/.claude/voice-notifications-sounds.json` and summarise

Example output:
```
Voice notifications: ON
Audio device: MacBook Pro Speakers
False-positive cooldown: 3s
Configured sounds:
  api-service   → done: Glass, input: Ping
  web-frontend  → done: Bottle, input: (tts)
  (default)     → done: (tts), input: (tts)
```

---

### Important

- Use the Bash tool to read/write files and list devices.
- Do NOT modify settings.json — the scripts read config files at runtime.
- When writing JSON, always load existing content first and merge (never overwrite unrelated keys).
