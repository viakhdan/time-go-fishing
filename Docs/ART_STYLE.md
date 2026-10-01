# Time Go Fishing: Art Style Guide

Derived from the 9 reference images in `Inspo/` (DESIGN.md §9.2). This file is the style authority for every asset. If an asset doesn't match it, fix or regenerate the asset.

> All references are from the game *Dredge*. They define the **style only**. Never trace, copy or ship them. `Inspo/` has a `.gdignore` and is excluded from exports.

---

## 1. Medium and rendering

**Low-poly, flat-shaded 2D illustration** that looks like faceted 3D (`art1`, `art2`, `art3`), with one painterly outlier (`art4`).

- Every form is built from **flat polygon facets**. There are no smooth gradients *inside* a shape. Light and shadow are separate flat planes of colour.
- Foliage and clouds are **jagged, torn-paper silhouettes** (`art2` pine trees, `art3` mangrove canopy).
- Depth comes from **atmospheric fog**: every layer further back is lighter, less saturated and closer to the sky colour (`art3` is the clearest example).
- **Not pixel art.** Assets are vector-like and scale cleanly.

**Practical production path:** because the style is flat polygons, assets can be **hand-authored as SVG** (by Claude or in Inkscape) and imported directly by Godot, instead of relying only on AI image generation. SVG gives exact palette control with no reduction pass. AI output (if used) must be palette-reduced (§9.3 of DESIGN.md).

## 2. Palette

Extracted with `python tools/extract_palette.py --k 32` (k-means over all references), then cleaned up by hand. Hand-added colours are marked ✎.

### Darks and UI

| Token | Hex | Use |
|---|---|---|
| `ink` | `#000000` | UI panel fill (`upgrades_inspo*`, `inventory_inspo`) |
| `ink_soft` | `#121413` | Deepest shadows, slot backgrounds |
| `wood_dark` | `#241f1d` | UI frame shadow, hold cabinet |
| `wood` | `#4c3932` | UI frames, dock planks |
| `maroon_dark` | `#3e211c` | Hold slot fill (`inventory_inspo`), banner shadow |
| `maroon` ✎ | `#5c2427` | Header banners, active tabs (`upgrades_inspo*`) |
| `slate` | `#273244` | Night water, panel alt |

### Earth (lake, dock, wood, fish bodies)

| Token | Hex | Use |
|---|---|---|
| `umber` | `#654831` | Shadow side of wood/earth |
| `rust` | `#7d5230` | Mid tone, rusty metal |
| `ochre_dark` | `#876446` | Lit wood |
| `ochre` | `#a68554` | Golden-hour ground, reeds |
| `sand` | `#b7a072` | Lit highlights on earth |

### Parchment (Encyclopedia book)

| Token | Hex | Use |
|---|---|---|
| `paper_dark` | `#bfaf96` | Page shadow, inset boxes |
| `paper` | `#d5c8af` | Page fill |
| `paper_light` | `#eee4cf` | Highlight panels, text on dark |

### Water and fog (river)

| Token | Hex | Use |
|---|---|---|
| `night` | `#0a1426` | Night sky, deep bay |
| `deep_teal` | `#0f282e` | Deep water shadow |
| `steel` | `#344551` | Distant hills in fog |
| `sea` | `#3f5e6a` | Water mid tone |
| `mist` | `#62878f` | Lit water, fog |
| `foam` | `#a3bdbe` | Far fog, foam highlights |

### Greys

| Token | Hex | Use |
|---|---|---|
| `stone` | `#55504c` | Rocks, disabled UI |
| `ash` | `#7c726c` | Secondary text on dark |
| `silver` | `#96989b` | Metal, Common rarity |

### Accents

| Token | Hex | Use |
|---|---|---|
| `kelp` | `#165f48` | Dark green, pressed button |
| `jade` | `#3b896c` | Green shadow |
| `go` | `#68c07d` | Positive UI (available upgrade, reel zone), Uncommon rarity |
| `glow` | `#18a9a8` | Bioluminescence, eerie highlights |
| `lantern` ✎ | `#f3d27a` | Lamp light, coins, Legendary rarity |
| `alarm` ✎ | `#d8433c` | Timer warning, "need X more", wrong answer |
| `white` | `#fefefd` | Titles, foam, main text on dark |

### Rarity colours (DESIGN.md §10)

| Rarity | Hex |
|---|---|
| Common | `#96989b` (silver) |
| Uncommon | `#68c07d` (go) |
| Rare | `#4a90b8` ✎ (blue, darker than `glow` so it stays distinct) |
| Legendary | `#f3d27a` (lantern) |

**Shadow / highlight rules:** shadows shift toward `maroon_dark` (warm scenes) or `deep_teal` (cool scenes), never pure black except in UI. Highlights shift toward `paper_light`, never pure white except foam and lamp cores.

## 3. Line work

- **World art (backgrounds): no outlines.** Shapes are separated by value and colour only.
- **Fish and items:** **thin dark outline** (about 2 px at 256 px sprite size) in a darker version of the local colour, or `ink_soft` (`fish_inspo`, `inventory_inspo`).
- **UI:** 2–4 px frames in `wood` / `paper_light`, and green (`go`) 2 px connector lines for the upgrade tree (`upgrades_inspo*`).

## 4. Shading and light

- **Flat / cel shading** with 2–4 tones per material. Light comes from the **upper left**.
- **Fog** is the main mood tool: 2–4 flat parallax layers, each lighter and less saturated.
- **Glow** is used sparingly for points of interest: lamps (`lantern`), bioluminescence and legendary fish (`glow`). A soft radial halo is the **only** place gradients are allowed.
- Water: flat base colour + thin broken white foam lines at the surface edge (`art1`, `art2`).

## 5. Shapes and proportions

- Creatures have **exaggerated silhouettes**: oversized eyes, spiky fins, jagged teeth, spiral or geometric body markings (`fish_inspo`).
- **For this game (ages 12–13): "eerie-cute".** Keep the big eyes and odd shapes, but round off the menace. Fewer teeth, bigger pupils, no gore or tentacle horror.
- Each fish shows its **math motif** in the silhouette or markings: square scales (Square Carp), a mirror stripe down the middle (Mirror Bream), an x-shaped curve (X-Eel), a spiral or ∅ marking (Great Null).
- Props and boats: chunky, slightly crooked, hand-built.

## 6. Composition and camera

- **Backgrounds:** side-on / slight 3/4 view, horizon at about 55–60% of the height, water in the lower third, a wooden dock in the foreground. Big calm negative space in the sky or fog for UI to sit over.
- **Fish sprites:** strict **side view facing right**, centred, on transparent background.
- **UI:** centred modal panels with a title banner above (`upgrades_inspo*`, `encyclopedia_inspo`), dimmed world behind.

## 7. Mood words

**Foggy, quiet, weathered, mysterious, cosy, slightly eerie, handmade, curious.**

## 8. Do / Don't

**Do**
- Layered fog with lighter, desaturated distance, like `art3.jpg`.
- Torn-paper, jagged tree and cloud silhouettes, like `art2.jpg`.
- Warm lamp glow against cool or muddy surroundings, like `art1.jpg`.
- Black UI panels with a maroon header strip and wood frame, like `upgrades_inspo1.jpg`.
- Cream parchment book with coloured tabs and bordered info boxes for the Encyclopedia, like `encyclopedia_inspo.jpg`.
- Dark maroon slot grid on black for the hold, like `inventory_inspo.jpg`.
- Bold, condensed, all-caps headings in white.
- Sprite silhouettes for unknown fish: solid white on black (`upgrades_inspo1.jpg`) or solid `ink_soft` on parchment.

**Don't**
- Glitch/chromatic effects or heavy grain from `art4.jpg`. Too noisy for readable math.
- Horror elements: tentacles, big teeth rows, gore (`art1.jpg`, `art4.jpg` underwater parts).
- Smooth gradients inside shapes, photo textures, or glossy 3D rendering.
- Math text directly on art. Always a solid `ink` or `paper` panel.
- The *Dredge* logo, fonts, fish designs or UI icons themselves.

## 9. Prompt templates (filled)

**Fish**
```
Flat-shaded low-poly vector illustration of a [FISH DESCRIPTION], side view facing right,
[MATH MOTIF],
eerie but cute, oversized round eye, slightly exaggerated spiky fins, faceted body planes,
thin dark outline, flat cel shading with 3 tones, light from upper left,
palette: muted earthy browns, ochre, murky teal and grey-green with one small accent colour,
transparent background, game asset, single subject, no text
```

**Background**
```
Flat-shaded low-poly vector landscape, [ZONE DESCRIPTION],
side-on view, horizon at 60% height, calm water in the lower third, wooden dock in foreground,
layered atmospheric fog with lighter and less saturated distant layers, jagged torn-paper tree silhouettes,
palette: [ZONE PALETTE], foggy, quiet, weathered, mysterious, cosy, 16:9, no characters, no text
```

Zone palettes:
- **Still Lake:** ochre, sand, umber and paper_light golden-hour sky, dark olive reeds.
- **Misty River:** mist, foam, steel and sea blue-grey fog, small lantern-yellow lamps.
- **Deep Bay (stretch):** night, deep_teal and slate with glow cyan bioluminescence.

**UI**
```
Flat game UI element, black panel with dark weathered wood frame, maroon header banner,
bold condensed white all-caps heading, clean and readable, no text content, transparent background
```

## 10. Typography

The references use a bold condensed sans for UI and a serif for book text. Cyrillic-capable OFL equivalents:

| Role | Font | Notes |
|---|---|---|
| Headings, buttons, HUD | **Oswald** (SemiBold) | Condensed, all-caps friendly, full Cyrillic |
| Body, problems, answers | **PT Sans** | Very readable, Ukrainian-designed Cyrillic, has ², ³, −, · |
| Encyclopedia titles and flavour | **PT Serif** | Matches the book style |

Minimum size 20 px (DESIGN.md §10).

**Fallbacks (checked):** PT Sans and Oswald lack superscripts ⁴–⁹, ⁰ and →. Every theme font falls back to **Noto Sans** (superscripts) and then **Noto Sans Math** (→ √ ≤ ≥ ≠). No bundled font has 🪙, so show coins with a coin icon, not the emoji. Set up in `art/ui/theme.tres`.

## 11. Asset production (as built)

- **Fish:** hand-authored SVGs in `art/fish/`, 512 × 256, side view facing right, 5 px outline in `wood_dark` (`ink_soft` for the river fish). Each shows its math motif: zero ring (Zero Perch), 9 / 4 / 1 square scales (Square Carp), mirror line with a reflected eye (Mirror Bream), spots in groups of 1 / 2 / 4 / 8 (Power Pike), body dissolving into mist in flat steps (Fog Catfish), body crossing itself in an x (X-Eel), level armour plates and an "=" (Balanced Sturgeon), glowing ∅ and a lantern lure (The Great Null). Keep fills opaque: partial transparency shows up as grey patches in the silhouette.
- **Silhouettes:** not separate files. `art/ui/silhouette.gdshader` fills the sprite's shape with one colour at runtime.
- **Backgrounds:** generated by `tools/make_backgrounds.py` (flat bands, torn-paper pines, flat fog layers, reflections, broken foam lines). Edit the script and rerun it; don't hand-edit the SVGs.
- **Review:** `tests/ArtPreview.tscn` renders a contact sheet of every fish (dark, parchment, silhouette, hold-slot size) and each background.
- **v3:** all 30 species have sprites. Bosses are bigger and busier (crown, scar, tentacles) but keep the same outline and palette rules. Open Seas uses `sea.svg` (wave crests, sea stacks, the boat's bow instead of a jetty).

## 12. Godot import settings

Not pixel art, so:

- **Filter:** Linear (`rendering/textures/canvas_textures/default_texture_filter = 1`, the default).
- **Mipmaps:** off for UI and fish sprites; on for backgrounds only if they are scaled down a lot.
- **SVG:** import at `scale = 2` for crisp results on 1080p+.
- **Compression:** Lossless for UI and sprites, VRAM Compressed allowed for large backgrounds.
- Base resolution **1920 × 1080**, stretch mode `canvas_items`, aspect `expand`.
