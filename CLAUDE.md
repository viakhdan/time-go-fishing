# Time Go Fishing

Educational math fishing game for Ukrainian 7th graders. Godot 4.7, GDScript, GL Compatibility renderer.

- **Design:** `Docs/DESIGN.md` is the source of truth. Follow the prompt order in its §15.
- **Art:** `Docs/ART_STYLE.md` is the style authority for every asset.
- The design doc's `art_reference/` folder is **`Inspo/`** in this repo, and `DESIGN.md` lives in `Docs/`.
- The repo root is the Godot project root (`res://`). `Inspo/`, `Docs/` and `tools/` have `.gdignore` and are excluded from exports.
- Every visible string goes through `tr()` / translation keys in `i18n/strings.csv` (`keys,uk,en`). Ukrainian is the default locale. Quote CSV values that contain commas.
- Game balance numbers live in `data/*.json`, never in code.
- Godot CLI (headless checks): `C:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` (the `.exe` in that path is a folder). The user often has the editor open, so avoid rewriting `project.godot` wholesale.
- `Inspo/` is gitignored (copyrighted Dredge reference art); it exists only locally.
- Fonts: `art/ui/theme.tres` is the project theme. PT Sans (body) / Oswald (buttons, `TitleLabel`) / PT Serif (`SerifLabel`), with Noto Sans + Noto Sans Math fallbacks for superscripts ⁴–⁹ and → √ ≤ ≥ ≠. No font has 🪙, so use a coin icon instead of the emoji.
- Problem pools: `data/problems/<topic>.json`, a JSON array. Each problem has a dev-only `check` field (the math as shown, used by the validator; never shown to players). Run `python tools/validate_problems.py` after any edit; it must print OK. Player-facing math uses − · and superscripts, never ASCII - * ^.
- Game data: `data/fish.json` (rarity table, bonuses, fish), `data/zones.json` (unlock = upgrade + level), `data/upgrades.json` (`base` = level-0 effect, `levels[i]` = level i+1). Stretch content has `"enabled": false`. Run `python tools/validate_data.py` after editing data or strings.
- Autoloads (in order): `GameData` (read-only JSON content), `GameState` (save data), `ProblemBank` (shuffle-bags). `FishingLoop` is pure logic driven by `advance(delta)`; scenes only listen to its signals.
- Tests: `<godot_console> --headless --path . res://tests/TestRunner.tscn` (exit code 1 on failure; uses a separate save file). Visual check: `<godot_console> --path . res://tests/Screenshots.tscn -- --out=<dir>` (opens a window briefly) writes PNGs of each loop state in both languages.
- Python tools in `tools/` (Python 3.13; deps in `tools/requirements.txt`).
