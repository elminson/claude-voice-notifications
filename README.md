# Claude Voice Notifications

Audio notifications for [Claude Code](https://claude.ai/code) — hear when Claude finishes, needs your input, or hits an error. Useful when running multiple sessions or working across windows.

## What you hear

| Event | Default |
|-------|---------|
| Work done (`end_turn`) | *"local my-api work done"* |
| Hit token limit (`max_tokens`) | *"local my-api check this"* |
| Error | *"local my-api error encountered"* |
| Needs input | *"local my-api claude code needs your input"* |
| No response after N seconds | *"local my-api still needs your input"* (escalation) |

Each event can play a sound effect, TTS, or both — configured per project.

## Install

```bash
git clone https://github.com/elminson/claude-voice-notifications.git
cd claude-voice-notifications
./install.sh
```

### Homebrew (once a release tag exists)

```bash
brew install elminson/tap/claude-voice-notifications
# then follow the post-install instructions
```

The installer copies scripts to `~/.claude/voice-notifications/` and adds `Notification` + `Stop` hooks to `~/.claude/settings.json` (global, all projects).

## Uninstall

```bash
./uninstall.sh
```

---

## Usage — `/voice-notification` skill

All configuration is done inside Claude Code with the `/voice-notification` skill.

### Toggle & device

```
/voice-notification              # full status
/voice-notification on | off     # enable / disable
/voice-notification devices      # list + pick audio output device
/voice-notification device <id>  # set device directly
```

### Per-project sounds

```
/voice-notification sound my-api done Glass         # "work done" → Glass chime
/voice-notification sound my-api input Ping         # "needs input" → Ping
/voice-notification sound my-api failure Basso      # error/limit → Basso
/voice-notification sound my-api mode both          # sound first, then TTS (default)
/voice-notification sound my-api mode sound         # effect only, no voice
/voice-notification sound my-api mode tts           # voice only, no effect
/voice-notification sound default failure Basso     # default for all projects
/voice-notification sound list                      # show all configured sounds
/voice-notification sound my-api remove             # remove project overrides
```

**Modes:**

| Mode | What you hear |
|------|--------------|
| `both` | Sound finishes, then TTS speaks — **default when a sound is set** |
| `sound` | Sound effect only |
| `tts` | TTS only — **default when no sound is set** |

**Built-in macOS sounds** (no download needed): `Glass` `Ping` `Pop` `Tink` `Bottle` `Funk` `Hero` `Basso` `Blow` `Frog` `Morse` `Purr` `Sosumi` `Submarine`

See [`sounds/README.md`](sounds/README.md) for CC0/GPL sound sources and custom file setup.

### Voice selection

```
/voice-notification voice my-api Samantha           # per-project TTS voice
/voice-notification voice default Daniel            # default voice all projects
/voice-notification voice list                      # list available voices
```

macOS has 50+ voices: `Samantha`, `Alex`, `Daniel`, `Moira`, `Fiona`, `Karen`, `Tessa`, and more. Assign a distinct voice per project to know who finished without looking.

### Volume

```
/voice-notification volume my-api 0.8    # 80% for this project (0.0–2.0)
/voice-notification volume default 1.0   # restore default
```

Applies to sound files always. For TTS on macOS, generates AIFF via `say -o` then plays with `afplay -v` when volume ≠ `1.0`.

### System banner notifications

On by default. Shows a native macOS banner (or Linux `notify-send`) alongside audio.

```
/voice-notification banner off   # disable banners
/voice-notification banner on    # re-enable
```

### Quiet hours

```
/voice-notification quiet 22:00 08:00   # silence between 10pm and 8am
/voice-notification quiet off           # disable quiet hours
```

Works overnight (e.g. `22:00`–`08:00`) and same-day (e.g. `09:00`–`17:00`).

### Escalation

Re-fires "still needs your input" if you don't respond within N seconds. Volume escalates by 40%.

```
/voice-notification escalate my-api 30   # re-notify after 30 seconds
/voice-notification escalate default 60  # default for all projects
/voice-notification escalate my-api off  # disable
```

Escalation is automatically cancelled when you respond (Claude finishes the next task).

### False-positive suppression

Prevents "needs your input" from firing right after "work done" (race condition in hooks).

```
/voice-notification cooldown 5    # extend window to 5 seconds (default: 3)
/voice-notification cooldown off  # disable
```

### Notification log

```
/voice-notification log           # show last 30 entries
/voice-notification log clear     # clear log
/voice-notification log off       # disable logging
/voice-notification log on        # re-enable
```

Log location: `~/.claude/voice-notifications.log`

```
2026-04-21 09:12:44 | api-service            | done         | stop_reason=end_turn
2026-04-21 09:14:02 | web-frontend           | input        |
2026-04-21 09:14:32 | web-frontend           | escalation   | after 30s
```

### Test

Fire notifications immediately without waiting for a real hook event:

```
/voice-notification test          # test both done + input
/voice-notification test done     # test "work done"
/voice-notification test input    # test "needs input"
/voice-notification test failure  # test error notification
```

---

## How it works

```
Claude Code hook fires
        │
        ▼
  notify-*.sh runs
        │
        ├─ check disabled flag → exit silently if off
        ├─ check quiet hours → exit silently if in window
        ├─ (Stop) check stop_reason:
        │     tool_use   → skip (intermediate step)
        │     end_turn   → "work done"
        │     max_tokens → "check this"
        │     error/*    → "error encountered"
        ├─ (Notification) 200ms delay → check cooldown
        │     recent end_turn Stop? → suppress false positive
        │
        ├─ send_banner → osascript / notify-send
        ├─ log_notification → ~/.claude/voice-notifications.log
        ├─ (input only) launch notify-escalate.sh in background
        │
        └─ dispatch_audio(sound, mode, voice, volume, device, msg)
              sound mode → afplay / paplay / mpv
              tts mode   → say / espeak / gTTS
              both mode  → sound (sync) then TTS
```

## Supported platforms

| Platform | TTS | Sound files | Banners |
|----------|-----|-------------|---------|
| macOS | `say` | `afplay` | `osascript` |
| Linux | `espeak` | `paplay` / `aplay` / `mpv` | `notify-send` |
| Docker | `gTTS` (Python) | `paplay` / `mpv` / `aplay` | — |

### Linux prerequisites

```bash
# TTS
sudo apt install espeak
# or: pip3 install gTTS && sudo apt install pulseaudio-utils

# Banners
sudo apt install libnotify-bin   # for notify-send
```

## Configuration

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_VOICE_SESSION_ID` | auto / `local` | Name spoken in TTS messages |
| `NOTIFY_TEST` | `0` | Set to `1` to bypass guards during testing |

### Example `~/.claude/voice-notifications-sounds.json`

```json
{
  "global": {
    "banner": true,
    "log": true,
    "quiet_hours": { "start": "22:00", "end": "08:00" }
  },
  "defaults": {
    "done":           "",
    "input":          "",
    "failure":        "Basso",
    "mode":           "both",
    "voice":          "",
    "volume":         1.0,
    "escalate_after": 0
  },
  "projects": {
    "api-service":  { "done": "Glass",  "input": "Ping", "failure": "Basso", "mode": "both",  "voice": "Samantha", "volume": 0.8, "escalate_after": 30 },
    "web-frontend": { "done": "Bottle", "input": "Pop",  "mode": "sound" },
    "scripts":      { "done": "Tink",   "input": "tts",  "mode": "both" }
  }
}
```

## File structure

```
~/.claude/
  settings.json                           # hooks (global, all projects)
  voice-notifications/
    notify-common.sh                      # shared library
    notify-done.sh                        # Stop hook handler
    notify-input.sh                       # Notification hook handler
    notify-escalate.sh                    # escalation re-fire
    sounds/                               # drop custom sound files here
  voice-notifications-disabled            # flag: all notifications off
  voice-notifications-device             # selected audio device
  voice-notifications-sounds.json        # sounds, voices, volumes, modes
  voice-notifications-cooldown           # false-positive cooldown seconds
  voice-notifications-last-stop          # timestamp of last end_turn Stop
  voice-notifications-last-input         # timestamp of last input notification
  voice-notifications.log                # notification history
```

## License

MIT
