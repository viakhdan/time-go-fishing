# Time Go Fishing

Educational math fishing game for Ukrainian 7th graders. Godot 4.3, GDScript, GL Compatibility renderer.

- **Design:** `Docs/DESIGN.md` is the source of truth. Follow the prompt order in its §15.
- **Art:** `Docs/ART_STYLE.md` is the style authority for every asset.
- The design doc's `art_reference/` folder is **`Inspo/`** in this repo, and `DESIGN.md` lives in `Docs/`.
- The repo root is the Godot project root (`res://`). `Inspo/`, `Docs/` and `tools/` have `.gdignore` and are excluded from exports.
- Every visible string goes through `tr()` / translation keys in `i18n/strings.csv` (`keys,uk,en`). Ukrainian is the default locale. Quote CSV values that contain commas.
- Game balance numbers live in `data/*.json`, never in code.
- Python tools in `tools/` (Python 3.13, numpy, Pillow, scikit-learn available).
