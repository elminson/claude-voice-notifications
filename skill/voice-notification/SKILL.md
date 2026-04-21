# /voice-notification

Full control over Claude Code voice notifications: toggle, device, per-project sounds, voices, volume, banners, quiet hours, escalation, logging, and testing.

## Usage

```
/voice-notification                                    — show full status

/voice-notification on | off                           — enable / disable all notifications

/voice-notification devices                            — list + pick audio output device
/voice-notification device <id>                        — set output device directly

/voice-notification sound <project|default> done <sound>      — "work done" sound
/voice-notification sound <project|default> input <sound>     — "needs input" sound
/voice-notification sound <project|default> failure <sound>   — error/interrupted sound
/voice-notification sound <project|default> mode <mode>       — sound | tts | both
/voice-notification sound <project> remove                     — remove project overrides
/voice-notification sound list                                 — list all configured sounds

/voice-notification voice <project|default> <VoiceName>       — TTS voice (e.g. Samantha)
/voice-notification voice list                                 — list available voices

/voice-notification volume <project|default> <0.0–2.0>        — playback volume

/voice-notification banner on | off                           — system banner notifications

/voice-notification quiet <HH:MM> <HH:MM>                     — set quiet hours (start end)
/voice-notification quiet off                                  — disable quiet hours

/voice-notification escalate <project|default> <seconds>      — re-notify if no response
/voice-notification escalate <project|default> off            — disable escalation

/voice-notification cooldown <seconds>                        — false-positive window (default 3)
/voice-notification cooldown off                              — disable cooldown

/voice-notification log                                        — show last 30 log entries
/voice-notification log clear                                  — clear the log
/voice-notification log on | off                              — toggle logging

/voice-notification test [done|input|failure]                 — fire a test notification
```

---

## Config file

All config lives in `~/.claude/voice-notifications-sounds.json`:

```json
{
  "global": {
    "banner": true,
    "log": true,
    "quiet_hours": { "start": "22:00", "end": "08:00" }
  },
  "defaults": {
    "done":          "",
    "input":         "",
    "failure":       "Basso",
    "mode":          "both",
    "voice":         "",
    "volume":        1.0,
    "escalate_after": 0
  },
  "projects": {
    "api-service": {
      "done":          "Glass",
      "input":         "Ping",
      "failure":       "Basso",
      "mode":          "both",
      "voice":         "Samantha",
      "volume":        0.8,
      "escalate_after": 30
    }
  }
}
```

**Sound values:** macOS system sound name (`Glass`, `Ping`, `Pop`, `Tink`, `Bottle`, `Funk`, `Hero`, `Basso`, `Blow`, `Frog`, `Morse`, `Purr`, `Sosumi`, `Submarine`), bare filename in `~/.claude/voice-notifications/sounds/`, absolute path, or `tts` to force TTS.

**Modes:** `both` (sound then TTS — default when sound set) · `sound` (effect only) · `tts` (voice only — default when no sound)

**Volume:** `0.0`–`2.0`. Applies to sound files always. For TTS on macOS, generates AIFF via `say -o` then plays with `afplay -v` when volume ≠ `1.0`.

---

## Instruction: how to handle each command

Use the **Bash** tool throughout. Use python3 to read/write JSON (preserve all existing keys). Write the minimal skeleton `{"global":{},"defaults":{},"projects":{}}` if the file doesn't exist yet.

---

### `on` / `off`
- `on` → remove `$HOME/.claude/voice-notifications-disabled`
- `off` → create `$HOME/.claude/voice-notifications-disabled` with content `disabled`

---

### `devices`
- macOS: `system_profiler SPAudioDataType 2>/dev/null` or `say -a '?'`
- Linux: `pactl list sinks short 2>/dev/null` (column 2)
- Read current from `$HOME/.claude/voice-notifications-device`
- Use AskUserQuestion with "(Current)" label
- Write chosen name to `$HOME/.claude/voice-notifications-device`

### `device <id>`
Write `<id>` to `$HOME/.claude/voice-notifications-device`

---

### `sound <project|default> done|input|failure <sound>`
Set `.projects["<project>"].<key>` (or `.defaults.<key>`) to `<sound>`.

### `sound <project|default> mode <mode>`
Set `.projects["<project>"].mode` (or `.defaults.mode`). Allowed: `sound`, `tts`, `both`.

### `sound <project> remove`
Delete `.projects["<project>"]`.

### `sound list`
Display a table: project → done / input / failure / mode. Include defaults row.

---

### `voice <project|default> <VoiceName>`
Set `.projects["<project>"].voice` (or `.defaults.voice`) to `<VoiceName>`.
Example names: `Samantha`, `Alex`, `Daniel`, `Moira`, `Fiona`, `Karen`, `Tessa`.

### `voice list`
- macOS: run `say -v '?'` and display the output (name + language columns).
- Linux: run `espeak --voices` if available.

---

### `volume <project|default> <value>`
Set `.projects["<project>"].volume` (or `.defaults.volume`) to `<value>` (float, 0.0–2.0).

---

### `banner on|off`
Set `.global.banner` to `true` or `false`.

---

### `quiet <HH:MM> <HH:MM>`
Set `.global.quiet_hours.start` and `.global.quiet_hours.end`.
Confirm: "Quiet hours set: 22:00–08:00. No notifications will play during this window."

### `quiet off`
Remove `.global.quiet_hours` key entirely.

---

### `escalate <project|default> <seconds>`
Set `.projects["<project>"].escalate_after` (or `.defaults.escalate_after`) to `<seconds>`.
Confirm: "Escalation set: will re-notify after <seconds>s if no response."

### `escalate <project|default> off`
Set the value to `0`.

---

### `cooldown <seconds>`
Write `<seconds>` to `$HOME/.claude/voice-notifications-cooldown`.

### `cooldown off`
Write `0` to `$HOME/.claude/voice-notifications-cooldown`.

---

### `log`
Run: `tail -30 $HOME/.claude/voice-notifications.log 2>/dev/null || echo "No log entries yet."`

### `log clear`
Run: `> $HOME/.claude/voice-notifications.log && echo "Log cleared."`

### `log on|off`
Set `.global.log` to `true` or `false`.

---

### `test [done|input|failure]`

Fire test notifications by piping synthetic hook payloads. Use `NOTIFY_TEST=1` to bypass cooldown, stop_reason, and quiet-hours checks.

```bash
SCRIPTS=~/.claude/voice-notifications

# test done (default)
echo '{"cwd":"'"$PWD"'","stop_reason":"end_turn"}' \
    | NOTIFY_TEST=1 bash "$SCRIPTS/notify-done.sh"

# test failure
echo '{"cwd":"'"$PWD"'","stop_reason":"error"}' \
    | NOTIFY_TEST=1 bash "$SCRIPTS/notify-done.sh"

# test input
echo '{"cwd":"'"$PWD"'"}' \
    | NOTIFY_TEST=1 bash "$SCRIPTS/notify-input.sh"
```

If argument is omitted, run both `done` and `input` tests sequentially (add a 1-second pause between them so sounds don't overlap).

---

### Status (no argument)

Read and display:
1. **Enabled/disabled** — check `voice-notifications-disabled`
2. **Audio device** — read `voice-notifications-device`
3. **False-positive cooldown** — read `voice-notifications-cooldown`
4. **Banner notifications** — read `global.banner` from JSON
5. **Logging** — read `global.log` from JSON
6. **Quiet hours** — read `global.quiet_hours` from JSON
7. **Configured sounds** — full table from JSON including mode, voice, volume, escalate_after

Example output:
```
Voice notifications: ON
Audio device:        MacBook Pro Speakers
Cooldown:            3s
Banner:              ON
Logging:             ON
Quiet hours:         22:00 – 08:00

Project            done     input    failure  mode   voice      vol  escalate
─────────────────  ───────  ───────  ───────  ─────  ─────────  ───  ────────
(default)          (tts)    (tts)    Basso    both   (system)   1.0  off
api-service        Glass    Ping     Basso    both   Samantha   0.8  30s
web-frontend       Bottle   Pop      (tts)    sound  (system)   1.0  off
```

---

### Important

- Use Bash tool to read/write files and run commands.
- Never modify `settings.json` — scripts read config files at runtime.
- Always load existing JSON before writing; never overwrite unrelated keys.
