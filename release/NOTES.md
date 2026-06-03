# Release Notes

## obs-study-with-me v1.0.0

### What's included
- Packaged OBS Lua tool distribution for the Pomodoro / Study With Me timer
- Browser dock UI for remote control via OBS WebSocket
- Auto-install helper for first-run scene and source creation
- Debug mode and safe logging added to the Lua script
- Detailed install and quickstart documentation

### Notable changes
- Added `SCRIPT_VERSION` metadata and `script_description()` support
- Added `auto_install_on_first_load` option for one-click initial setup
- Added `control_dock_url` setting support in script properties
- Added `debug_mode` toggle and safe logging wrapper
- Packaged the tool into a clean directory structure for release

### Files included in the release package
- `README.md`
- `LICENSE`
- `lua/pomorodo.lua`
- `dock/index.html`
- `dock/styles.css`
- `dock/app.js`
- `docs/QUICKSTART.md`
- `docs/INSTALL.md`
- `install/README.md`
- `release/README.md`
- `release/NOTES.md`
- `assets/README.md`

### Notes
This release is a Lua-based OBS tool distribution, not a compiled native plugin. It is designed for easy installation and a polished end-user experience.
