# Claude Voice Notifications

TTS voice notifications for [Claude Code](https://claude.ai/code). Get audio alerts when Claude finishes a task or needs your input — useful when running multiple sessions.

## What it does

| Event | What you hear |
|-------|--------------|
| Claude finishes work (`Stop`) | *"local claude code work done"* |
| Claude needs input (`Notification`) | *"local claude code needs your input"* |

The session identifier (e.g., `local`, `main-2`) is spoken first so you know which instance needs attention.

## Install

```bash
git clone https://github.com/elminson/claude-voice-notifications.git
cd claude-voice-notifications
./install.sh
```

The installer:
1. Copies notification scripts to `~/.claude/voice-notifications/`
2. Adds `Notification` and `Stop` hooks to `~/.claude/settings.json` (global, works across all projects)
3. Installs the `/voice-notification` skill to your project's `.claude/skills/` (if in a project directory)

## Uninstall

```bash
cd claude-voice-notifications
./uninstall.sh
```

## Usage

### Toggle notifications

Inside Claude Code:

```
/voice-notification              # show status
/voice-notification on           # enable
/voice-notification off          # disable
/voice-notification devices      # list and select audio output device
/voice-notification device <id>  # set output device directly
```

### Per-project sounds

Configure a sound effect (instead of TTS) per project:

```
/voice-notification sound my-api done Glass      # "work done" → chime
/voice-notification sound my-api input Ping      # "needs input" → ping
/voice-notification sound default done Tink      # default for all projects
/voice-notification sound list                   # show all configured sounds
/voice-notification sound my-api remove          # revert to TTS
```

Sound values accepted:
- **macOS system sound name** — `Glass`, `Ping`, `Pop`, `Tink`, `Bottle`, `Funk`, `Hero`, `Basso`, `Blow`, `Frog`, `Morse`, `Purr`, `Sosumi`, `Submarine`
- **Bare filename** — looked up in `~/.claude/voice-notifications/sounds/`
- **Absolute path** — `/path/to/sound.wav`
- **`tts`** — force TTS even when a default is set

See [`sounds/README.md`](sounds/README.md) for free/CC0 sound sources and how to install custom files.

### False-positive suppression

The "needs your input" notification is suppressed if it fires within N seconds of the "work done" notification (the default is 3 seconds). This prevents false alerts when Claude finishes a task and an internal hook event immediately follows.

```
/voice-notification cooldown 5    # extend to 5 seconds
/voice-notification cooldown off  # disable suppression entirely
```

### Session identifier

By default, the scripts try to detect the session name from the environment. You can override it:

```bash
export CLAUDE_VOICE_SESSION_ID="my-session"
```

## How it works

```
Claude Code hook fires
        |
        v
  notify-*.sh runs
        |
        v
  Check ~/.claude/voice-notifications-disabled
        |
   [exists?]--yes--> exit silently
        |
       no
        |
        v
  Read ~/.claude/voice-notifications-device
        |
        v
  Detect TTS engine + route to device:
    macOS  --> say -a <device>
    Linux  --> espeak (default device)
    Docker --> paplay --device=<device> / mpv --audio-device=pulse/<device>
```

### Hooks

The install script adds two hooks to `.claude/settings.json`:

- **`Notification`** — fires when Claude sends a notification (needs input, tool approval, etc.)
- **`Stop`** — fires when Claude finishes responding

### Toggle mechanism

`/voice-notification off` creates `~/.claude/voice-notifications-disabled`. The scripts check for this file and exit immediately if it exists. `/voice-notification on` removes it.

### Device selection

`/voice-notification devices` lists available audio outputs and lets you pick one interactively. The selection is saved to `~/.claude/voice-notifications-device`. Scripts read this file on each notification and route audio to that device.

| Platform | How device is used |
|----------|-------------------|
| macOS | `say -a <device>` |
| PulseAudio | `paplay --device=<device>` |
| mpv | `mpv --audio-device=pulse/<device>` |

If no device is configured, the system default is used.

## Supported platforms

| Platform | TTS engine | Audio playback |
|----------|-----------|----------------|
| macOS | `say` (built-in) | built-in |
| Linux | `espeak` | built-in |
| Docker/sandbox | `gTTS` (Python) | `paplay`, `mpv`, or `aplay` |

### Linux prerequisites

```bash
# Option A: espeak (lightweight, offline)
sudo apt install espeak

# Option B: gTTS (Google TTS, requires internet)
pip3 install gTTS
sudo apt install pulseaudio-utils  # for paplay
```

## Configuration

| Environment variable | Default | Description |
|---------------------|---------|-------------|
| `CLAUDE_VOICE_SESSION_ID` | auto-detected or `local` | Custom name spoken in notifications |
| `SANDBOX_CLIPBOARD_FILE` | *(set by sandbox)* | Used to auto-detect sandbox ID |

## File structure

```
~/.claude/
  settings.json                           # hooks added here (global, all projects)
  voice-notifications/
    notify-done.sh                        # "work done" notification
    notify-input.sh                       # "needs your input" notification
    sounds/                               # drop custom sound files here
  voice-notifications-disabled            # flag file (only when off)
  voice-notifications-device             # selected audio device name/ID
  voice-notifications-sounds.json        # per-project sound config
  voice-notifications-cooldown           # false-positive cooldown seconds
  voice-notifications-last-stop          # timestamp of last Stop event (auto-managed)

<your-project>/                           # optional
  .claude/
    skills/
      voice-notification/
        SKILL.md                          # /voice-notification skill
```

### Example `~/.claude/voice-notifications-sounds.json`

```json
{
  "defaults": { "done": "", "input": "" },
  "projects": {
    "api-service":  { "done": "Glass",  "input": "Ping"   },
    "web-frontend": { "done": "Bottle", "input": "Pop"    },
    "scripts":      { "done": "Tink",   "input": "tts"    }
  }
}
```

## License

MIT
