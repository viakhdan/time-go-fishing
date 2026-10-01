# Time Go Fishing

Educational math fishing game for Ukrainian 7th graders. Godot 4.7, GDScript, GL Compatibility renderer.

- **Design:** `Docs/DESIGN.md` is the source of truth. Follow the prompt order in its §15.
- **Art:** `Docs/ART_STYLE.md` is the style authority for every asset.
- The design doc's `art_reference/` folder is **`Inspo/`** in this repo, and `DESIGN.md` lives in `Docs/`.
- The repo root is the Godot project root (`res://`). `Inspo/`, `Docs/` and `tools/` have `.gdignore` and are excluded from exports.
- Every visible string goes through `tr()` / translation keys in `i18n/strings.csv` (`keys,uk,en`). Ukrainian is the default locale. Quote CSV values that contain commas.
- Game balance numbers live in `data/*.json`, never in code.
- Godot CLI (headless checks): `C:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe --headless --path . --import` (the `.exe` in that path is a folder; override with the GODOT env var). The user often has the editor open, so avoid rewriting `project.godot` wholesale.
- `Inspo/` is gitignored (copyrighted Dredge reference art); it exists only locally.
- Theme: `art/ui/theme.tres` is **generated** by `tools/build_theme.gd` (run `<godot_console> --headless --path . -s <absolute path to tools/build_theme.gd>`); edit the builder, never the .tres. Its header lists the type variations (PrimaryButton, AnswerButton, HoldSlot, ModalPanel, Card, PaperPanel, PaperLabel…). Colours come from `scripts/Palette.gd` (ART_STYLE.md §2), never raw hex in code.
- Fonts: PT Sans (body, answers) / Oswald (buttons, titles) / PT Serif (Encyclopedia), with Noto Sans + Noto Sans Math fallbacks for superscripts ⁴–⁹ and → √ ≤ ≥ ≠ ★. No font has 🪙: coins are `art/ui/icons/coin.svg`, shown via `CoinCounter`, `Button.icon`, or RichTextLabel BBCode from `UIText.coins()` / `UIText.rich()`; strings.csv marks the spot with `{coin}`.
- Shared components: `FishPicture` (sprite, or faceted placeholder fish in the rarity colour until art exists; silhouette when unknown), `CoinCounter`, `LangToggle`, `HoldPanel`. Sprites/backgrounds are still placeholders.
- Problem pools: `data/problems/<topic>.json`, a JSON array. Each problem has a dev-only `check` field (the math as shown, used by the validator; never shown to players). Run `python tools/validate_problems.py` after any edit; it must print OK. Player-facing math uses − · and superscripts, never ASCII - * ^.
- Game data: `data/fish.json` (rarity table, bonuses, fish), `data/zones.json` (unlock = upgrade + level), `data/upgrades.json` (`base` = level-0 effect, `levels[i]` = level i+1). Stretch content has `"enabled": false`. Run `python tools/validate_data.py` after editing data or strings.
- Autoloads (in order): `GameData` (read-only JSON content), `GameState` (save data), `ProblemBank` (shuffle-bags). `FishingLoop` is pure logic driven by `advance(delta)`; scenes only listen to its signals.
- Tests: `python tools/run_tests.py` (imports, runs every `test_*` method of the suites listed in `tests/run_tests.gd`, and fails on failed checks *or* any SCRIPT ERROR, since GDScript runtime errors don't fail a test by themselves). Suites extend `TestSuite`; GameState is reset before each test and uses a separate save file. Never trigger scene changes in tests: they would replace the runner. Visual check: `<godot_console> --path . res://tests/Screenshots.tscn -- --out=<dir>` (opens a window briefly) writes PNGs of each loop state in both languages.
- Economy simulation: `<godot_console> --headless --path . res://tests/EconomySim.tscn -- --runs=500 [--strategy=boat_first] [--tiered] [--set=upgrades.boat.levels.0.cost=80]`. Uses the real game code plus a time model (constants at the top of `tests/economy_sim.gd`). Findings and tuning suggestions: `Docs/ECONOMY_REPORT.md`.
- Builds: `python tools/export_all.py [--only Web] [--debug]` → `build/itch/*.zip` (Windows, Linux, macOS, Web). Needs the 4.7.2 export templates (installed in %APPDATA%\Godot\export_templates). Release checklist and itch.io settings: `Docs/RELEASE.md`. `build/` is gitignored and has a `.gdignore`.
- Python tools in `tools/` (Python 3.13; deps in `tools/requirements.txt`).
