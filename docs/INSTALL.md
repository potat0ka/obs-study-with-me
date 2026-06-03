# OBS Pomodoro Tool Installation

This package is intentionally structured like a small OBS tooling distribution.

## Package structure
- `lua/` — contains the OBS Lua script.
- `dock/` — contains the browser dock UI.
- `docs/` — contains user-facing setup and install guides.
- `assets/` — place icons, screenshots, or future resources here.
- `install/` — optional helper notes for installers.
- `release/` — packaging instructions and release notes.

## Windows / macOS / Linux install

### 1. Install OBS WebSocket
Install the OBS WebSocket plugin before using the browser dock.

### 2. Load the Lua script
1. Open OBS.
2. Navigate to `Tools -> Scripts`.
3. Click `+` and select `lua/pomorodo.lua` from this repo.
4. Configure settings in the script properties.

### 3. Configure dock URL
1. Open `View -> Docks -> Custom Browser Docks`.
2. Add a custom dock with the URL:
   - `file:///FULL_PATH_TO_REPO/dock/index.html`
3. Name it `Pomodoro Control`.
4. Click `Apply`.

### 4. First-run installer behavior
If you enable `Run Install on First Load`, the Lua script will automatically create the recommended scenes and sources on first run.

### 5. Recommended sources and scenes
The script will auto-create the following by default if enabled:
- `Study With Me - Prep`
- `Study With Me - Focus`
- `Study With Me - Short Break`
- `Study With Me - Long Break`

And these text sources:
- `Pomodoro Timer`
- `Pomodoro Status`
- `Pomodoro Clock`
- `Pomodoro Goal`
- `Pomodoro Subject`
- `Pomodoro Panel`
- `Pomodoro Toast`

## Notes
- If you do not want auto-install, leave the option disabled.
- The script only creates missing scenes/sources and does not overwrite existing user content unless explicitly enabled.
