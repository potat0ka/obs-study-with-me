# Release Notes

## obs-study-with-me v1.0.0

### What's included
- Packaged OBS Lua tool distribution for the Pomodoro / Study With Me timer
- Browser dock UI (`dock/`) for remote control via OBS WebSocket 4.x and 5.x
- Auto-install helper: one click creates all scenes and sources in OBS
- Prep / countdown phase before each focus session
- Toast notification system for on-screen segment transitions
- Detailed status panel source for stream overlays
- Per-scene looping background music support
- Full hotkey set for all timer actions
- Chat control integration support (mod-only or open)
- Debug mode and safe logging
- Detailed install and quickstart documentation

### Hotkeys registered by the script
- `pomo_start` — Start the timer
- `pomo_pause` — Pause the timer
- `pomo_resume` — Resume from pause
- `pomo_toggle` — Toggle start / pause / resume
- `pomo_skip` — Skip to next segment
- `pomo_reset` — Reset the timer
- `pomo_stop` — Stop the timer entirely
- `pomo_focus` — Jump directly to Focus mode
- `pomo_short_break` — Jump directly to Short Break
- `pomo_long_break` — Jump directly to Long Break

### Auto-created scenes
- `Study With Me - Prep`
- `Study With Me - Focus`
- `Study With Me - Short Break`
- `Study With Me - Long Break`

### Auto-created sources
**Text:** `Pomodoro Timer`, `Pomodoro Status`, `Pomodoro Clock`, `Pomodoro Goal`, `Pomodoro Subject`, `Pomodoro Panel`, `Pomodoro Toast`  
**Audio:** `Pomodoro Alert`, `Pomodoro BGM - Focus`, `Pomodoro BGM - Short Break`, `Pomodoro BGM - Long Break`

### Files included in the release package
- `README.md`
- `LICENSE`
- `lua/pomorodo.lua`
- `dock/index.html`
- `dock/styles.css`
- `dock/app.js`
- `pomodoro_dock.html` (standalone all-in-one dock, no external dependencies)
- `docs/QUICKSTART.md`
- `docs/INSTALL.md`
- `install/README.md`
- `release/README.md`
- `release/NOTES.md`
- `assets/README.md`

### Notes
This release is a Lua-based OBS tool distribution, not a compiled native plugin. It is designed for easy installation and a polished end-user experience.
