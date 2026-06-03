# Pomodoro Timer Quickstart

This package is designed to feel like a proper OBS tool distribution.

## 1. Install the Lua script
1. Open OBS.
2. Go to `Tools → Scripts`.
3. Click `+` and select `lua/pomorodo.lua` from this package.
4. In the script properties, click **🪄 Auto-Create Scene Setup** to instantly create all scenes and sources.
5. Click **Defaults** to auto-link sources and scenes.

## 2. Open the browser dock
1. Go to `View → Docks → Custom Browser Docks`.
2. Add a new dock with:
   - Name: `Pomodoro Control`
   - URL: `file:///PATH_TO_PACKAGE/dock/index.html`
3. Click `Apply`.

## 3. Connect the dock
1. Enter your OBS WebSocket host (usually `127.0.0.1`).
2. Enter the WebSocket port (`4455` for OBS WebSocket 5.x, `4444` for legacy 4.x).
3. Enter a password if your OBS WebSocket requires one.
4. Click `Connect`.

## 4. Use the controls

**Timer controls:**
- `Start` — begins the timer (runs Prep → Focus → Break cycle).
- `Pause` — pauses the current timer.
- `Resume` — resumes from a paused state.
- `Toggle` — toggles between start / pause / resume.
- `Skip` — advances immediately to the next segment.
- `Reset` — stops the timer and resets session count.
- `Stop` — stops the timer entirely.

**Direct mode jump:**
- `Focus` — jumps directly to a Focus segment.
- `Short Break` — jumps directly to a Short Break segment.
- `Long Break` — jumps directly to a Long Break segment.

## 5. Hotkeys
All controls are also available as OBS hotkeys. Go to `Settings → Hotkeys` and search for **Pomodoro** to bind them:

| Action | Hotkey ID |
|---|---|
| Start | `pomo_start` |
| Pause | `pomo_pause` |
| Resume | `pomo_resume` |
| Toggle | `pomo_toggle` |
| Skip | `pomo_skip` |
| Reset | `pomo_reset` |
| Stop | `pomo_stop` |
| Focus | `pomo_focus` |
| Short Break | `pomo_short_break` |
| Long Break | `pomo_long_break` |

## 6. Chat control (optional)
Enable **Chat Control** in the script properties. Your chat bot can then trigger:
`!start`, `!pause`, `!resume`, `!toggle`, `!skip`, `!reset`, `!stop`, `!focus`, `!break`, `!longbreak`

## 7. Optional first-run install
In the script properties, enable `Run Install on First Load` to auto-create the scenes and sources on the very first use.
