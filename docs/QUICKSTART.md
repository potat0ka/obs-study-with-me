# Pomodoro Timer Quickstart

This package is designed to feel like a proper OBS tool distribution.

## 1. Install the Lua script
1. Open OBS.
2. Go to `Tools -> Scripts`.
3. Click `+` and select `lua/pomorodo.lua` from this package.

## 2. Open the browser dock
1. Go to `View -> Docks -> Custom Browser Docks`.
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
- `Start` begins the timer.
- `Pause` pauses the timer.
- `Resume` resumes a pause.
- `Toggle` toggles between start/pause.
- `Skip` advances to the next segment.
- `Reset` resets the timer.
- `Stop` stops the timer entirely.

## 5. Optional first-run install
In the script properties, enable `Run Install on First Load` to auto-create the scenes and sources on first use.
