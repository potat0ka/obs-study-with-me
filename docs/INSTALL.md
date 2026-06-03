# OBS Pomodoro Tool Installation

This package is intentionally structured like a small OBS tooling distribution.

## Package structure
- `lua/` — contains the OBS Lua script (`pomorodo.lua`).
- `dock/` — contains the browser dock UI (`index.html`, `styles.css`, `app.js`).
- `docs/` — contains user-facing setup and install guides.
- `assets/` — place icons, screenshots, or future resources here.
- `install/` — optional helper notes for installers.
- `release/` — packaging instructions and release notes.

## Windows / macOS / Linux Install

### 1. Install OBS WebSocket (optional, for dock control)
Install the OBS WebSocket plugin before using the browser dock.  
OBS Studio 28+ ships with OBS WebSocket 5.x built-in.

### 2. Load the Lua script
1. Open OBS.
2. Navigate to `Tools → Scripts`.
3. Click `+` and select `lua/pomorodo.lua` from this repo.
4. Configure settings in the script properties panel.

### 3. Run Auto-Setup (Recommended)
At the top of the script properties, click **🪄 Auto-Create Scene Setup**.  
This automatically creates all required scenes and sources in your OBS scene collection.

### 4. Configure dock URL
1. Open `View → Docks → Custom Browser Docks`.
2. Add a custom dock with the URL:
   - `file:///FULL_PATH_TO_REPO/dock/index.html`
3. Name it `Pomodoro Control`.
4. Click `Apply`.

### 5. Bind hotkeys (optional)
Go to `Settings → Hotkeys` to bind keyboard shortcuts to any of the Pomodoro actions.

---

## Recommended Scenes (auto-created by Auto-Setup)
- `Study With Me - Prep`
- `Study With Me - Focus`
- `Study With Me - Short Break`
- `Study With Me - Long Break`

## Recommended Sources (auto-created by Auto-Setup)

**Text Sources:**
- `Pomodoro Timer` — live countdown
- `Pomodoro Status` — current mode message
- `Pomodoro Clock` — real-time local clock
- `Pomodoro Goal` — daily session goal tracker
- `Pomodoro Subject` — current subject/task label
- `Pomodoro Panel` — detailed multi-line status panel
- `Pomodoro Toast` — on-screen transition notifications

**Audio Sources:**
- `Pomodoro Alert` — shared non-looping alert sound
- `Pomodoro BGM - Focus` — looping background music for Focus
- `Pomodoro BGM - Short Break` — looping background music for Short Break
- `Pomodoro BGM - Long Break` — looping background music for Long Break

## Notes
- If you do not want auto-install, leave the option disabled.
- The script only creates missing scenes/sources and does not overwrite existing user content unless explicitly enabled.
- Enable `Run Install on First Load` in the script properties to auto-run setup the very first time OBS loads the script.
