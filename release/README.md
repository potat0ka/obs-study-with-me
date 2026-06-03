# Release Packaging

Package this project into a distribution zip with a versioned filename.

## Release file name
Use a name like:

```
obs-study-with-me-v1.0.0.zip
```

## Files to include
- `lua/pomorodo.lua`
- `dock/index.html`
- `dock/styles.css`
- `dock/app.js`
- `docs/QUICKSTART.md`
- `docs/INSTALL.md`
- `install/README.md`
- `release/README.md`
- `assets/` (optional icons or screenshots)
- `LICENSE`

## Versioning
- Update the constant `SCRIPT_VERSION` in `pomorodo.lua`.
- Update release file name to match the version.
- Record release notes in `release/README.md` or a separate changelog.

## How to build
1. Copy the repo files listed above into a temporary folder.
2. Compress the folder into `obs-study-with-me-v1.0.0.zip`.
3. Upload or distribute the zip.

## Update process
1. Increase `SCRIPT_VERSION` in `pomorodo.lua`.
2. Update docs if behavior or install flow changed.
3. Regenerate the zip with the new version.
