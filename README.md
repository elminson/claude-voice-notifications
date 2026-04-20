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
/voice-notification        # show current status
/voice-notification on     # enable
/voice-notification off    # disable
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
  Detect TTS engine:
    macOS  --> say
    Linux  --> espeak
    Docker --> gTTS + paplay/mpv
```

### Hooks

The install script adds two hooks to `.claude/settings.json`:

- **`Notification`** — fires when Claude sends a notification (needs input, tool approval, etc.)
- **`Stop`** — fires when Claude finishes responding

### Toggle mechanism

`/voice-notification off` creates `~/.claude/voice-notifications-disabled`. The scripts check for this file and exit immediately if it exists. `/voice-notification on` removes it.

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
  settings.json                      # hooks added here (global, all projects)
  voice-notifications/
    notify-done.sh                   # "work done" notification
    notify-input.sh                  # "needs your input" notification
  voice-notifications-disabled       # flag file (only exists when off)

<your-project>/                      # optional
  .claude/
    skills/
      voice-notification/
        SKILL.md                     # /voice-notification skill
```

## License

MIT
