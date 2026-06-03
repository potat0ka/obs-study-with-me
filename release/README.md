# Release Packaging

Package this project into a distribution zip with a versioned filename.

## Release file name
Use a name like:

```
obs-study-with-me-v1.0.0.zip
```

## Files to include
- `README.md`
- `LICENSE`
- `lua/pomorodo.lua`
- `dock/index.html`
- `dock/styles.css`
- `dock/app.js`
- `pomodoro_dock.html` (standalone all-in-one dock)
- `docs/QUICKSTART.md`
- `docs/INSTALL.md`
- `install/README.md`
- `release/README.md`
- `release/NOTES.md`
- `assets/` (optional icons or screenshots)

## Versioning
- Update the constant `SCRIPT_VERSION` in `lua/pomorodo.lua`.
- Update the release file name and this README to match the version.
- Record release notes in `release/NOTES.md`.

## How to build
1. Copy the files listed above into a temporary folder.
2. Compress the folder into `obs-study-with-me-v1.0.0.zip`.
3. Upload or distribute the zip.

## Update process
1. Increase `SCRIPT_VERSION` in `lua/pomorodo.lua`.
2. Ensure root `pomorodo.lua` matches `lua/pomorodo.lua` (keep them in sync).
3. Update docs if behavior or install flow changed.
4. Update `release/NOTES.md` with the changelog.
5. Regenerate the zip with the new version number.
