# Custom Sound Files

Drop `.wav`, `.aiff`, or `.mp3` files here (or in `~/.claude/voice-notifications/sounds/`) and reference them by bare name in the sound config.

## Built-in macOS system sounds (no download needed)

These names work out of the box on macOS — just use the name as-is:

| Name | Description |
|------|-------------|
| `Glass` | Short glass clink |
| `Ping` | Soft ping |
| `Pop` | Gentle pop |
| `Tink` | High-pitched tink |
| `Bottle` | Bottle tap |
| `Funk` | Funky descending tone |
| `Hero` | Ascending success chime |
| `Blow` | Short blow |
| `Basso` | Deep bass tone |
| `Frog` | Frog croak |
| `Morse` | Morse beep |
| `Purr` | Cat purr |
| `Sosumi` | Classic Mac sound |
| `Submarine` | Sonar ping |

**Example config:**
```json
{
  "projects": {
    "my-api":   { "done": "Glass",  "input": "Ping"  },
    "web-app":  { "done": "Bottle", "input": "Pop"   },
    "scripts":  { "done": "Tink",   "input": "Funk"  }
  }
}
```

## Free / open-licensed sound sources

### CC0 (public domain — no attribution required)

- **Freesound.org** — https://freesound.org — search for "notification", "beep", "chime", filter by CC0
- **OpenGameArt.org** — https://opengameart.org — many CC0 sound packs, search "ui sounds"
- **Kenney.nl** — https://kenney.nl/assets/category:Audio — free game UI sound packs (CC0)
  - UI Audio pack: short, clean notification sounds
  - Interface Sounds: variety of beeps, clicks, chimes
- **Mixkit** — https://mixkit.co/free-sound-effects/ — free for any use (custom license, no attribution)

### GPL-compatible

- **GPL Sound Library** — check your Linux distro's `libcanberra` package for system sounds
  - `/usr/share/sounds/freedesktop/stereo/` — standard Freedesktop sounds

## How to use custom sound files

1. Copy your `.wav`/`.aiff`/`.mp3` to `~/.claude/voice-notifications/sounds/`
2. Configure it (inside Claude Code):
   ```
   /voice-notification sound my-project done blip
   ```
   Or by absolute path:
   ```
   /voice-notification sound my-project done /path/to/notification.wav
   ```

## Sound file resolution order

The scripts try to resolve a bare name in this order:

1. `/System/Library/Sounds/<name>.aiff` (macOS built-ins)
2. `~/.claude/voice-notifications/sounds/<name>`
3. `~/.claude/voice-notifications/sounds/<name>.wav`
4. `~/.claude/voice-notifications/sounds/<name>.aiff`
5. `~/.claude/voice-notifications/sounds/<name>.mp3`
6. `/usr/share/sounds/<name>` (Linux)
7. `/usr/share/sounds/freedesktop/stereo/<name>.oga` (Freedesktop)
