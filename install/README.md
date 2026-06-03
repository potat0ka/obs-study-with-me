# Install Helper

This folder contains guidance for packaging and installer-style deployment.

Use this package structure for installers and portable releases.

## Where to place files

| File | Action |
|---|---|
| `lua/pomorodo.lua` | Load in OBS via **Tools → Scripts → +** |
| `dock/index.html` | Set as a Custom Browser Dock URL in OBS (`View → Docks → Custom Browser Docks`) |
| `pomodoro_dock.html` | Alternative standalone dock (no external JS/CSS — works offline) |
| `docs/QUICKSTART.md` | Share with the end user as the getting-started guide |
| `docs/INSTALL.md` | Full installation reference |

## First-run auto-install
In the script properties, enable **Run Install on First Load**.  
The script will automatically create all required scenes and sources when OBS first loads the script.

## Recommended OBS settings after install
1. Go to **Settings → Hotkeys** and bind Pomodoro hotkeys as desired.
2. In the **Audio Mixer**, find `Pomodoro Alert` → Gear → **Advanced Audio Properties** → set **Audio Monitoring** to **Monitor and Output**.
3. Optionally bind `dock/index.html` as a Custom Browser Dock for one-click control.
