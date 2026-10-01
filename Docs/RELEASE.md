# Building and releasing

## Build everything

```bash
python tools/export_all.py
```

This exports all four presets from `export_presets.cfg` and writes itch.io-ready zips to `build/itch/`:

| File | Platform | Notes |
|---|---|---|
| `TimeGoFishing-windows.zip` | Windows 64-bit | One `.exe`, data embedded |
| `TimeGoFishing-linux.zip` | Linux 64-bit | One `.x86_64` binary, data embedded |
| `TimeGoFishing-macos.zip` | macOS (Intel + Apple Silicon) | Ad-hoc signed, **not notarized** (see below) |
| `TimeGoFishing-web.zip` | Browser | `index.html` at the root, no threads (works on itch.io without special headers) |

To build a single preset: `python tools/export_all.py --only Web`. Add `--debug` for a debug build; on Windows that also adds a console `.exe` that shows errors.

The build needs the Godot 4.7.2 export templates in `%APPDATA%\Godot\export_templates\4.7.2.stable`. In the editor: *Editor → Manage Export Templates → Download and Install*.

The exports leave out `Inspo/` (reference art), `Docs/`, `tools/` and `tests/`. `build/` has a `.gdignore`, so an open editor won't import the build output.

## Check a build before uploading

1. `python tools/run_tests.py` passes.
2. Windows: `build/windows/TimeGoFishing.exe --headless --quit-after 300` exits with code 0, and `%APPDATA%\Godot\app_userdata\Time Go Fishing\logs\godot.log` has no errors.
3. Web: serve `build/web/` locally (the `web-build` config in `.claude/launch.json`, or `python -m http.server 8060 --directory build/web`), play one catch, reload the page, and check the coins are still there. The browser save lives in IndexedDB.

## itch.io upload (DESIGN.md §13 Day 7)

- **Kind of project:** HTML. Upload `TimeGoFishing-web.zip` and tick *This file will be played in the browser*.
- **Viewport:** 1280 × 720, *Mobile friendly* off, *Fullscreen button* on.
- **SharedArrayBuffer support:** leave it **off**. The build doesn't use threads.
- Upload the Windows, Linux and macOS zips as downloads, each tagged with its platform.
- **Visibility:** *Restricted* or *Draft* until a teacher has checked the math and the Ukrainian (DESIGN.md §6, §8.3, §11).
- **macOS note for the page:** the app isn't notarized, so on first launch players right-click → *Open* (or allow it under *System Settings → Privacy & Security*).
