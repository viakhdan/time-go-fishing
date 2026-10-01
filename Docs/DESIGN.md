# 🎣 Math Fishing Game: Design Document (MVP v2)

**Working title:** Математична риболовля / Math Fishing
**Audience:** 7th grade students in Ukraine (ages 12–13)
**Team:** Solo dev + Claude
**Sprint:** 7 days
**Platforms:** Desktop (Windows/macOS/Linux) required · Web (itch.io) nice-to-have
**Languages:** Ukrainian (default), English

> **v2 changes:** the game now runs in fishing trips with a limited hold (inventory). You sell fish at the dock and spend coins on rig upgrades. The Fishdex becomes an Encyclopedia with math facts. The art style now comes from a reference image folder instead of a fixed spec.

---

## 1. Success criteria

The MVP is done when:

1. The core loop works: **solve a math problem → catch a fish → see its rarity → it goes into the hold**.
2. The meta loop works: **hold fills up → return to the dock → sell fish → buy an upgrade → fish better**.
3. **2 zones** are playable, each with its own math topic. The second zone is unlocked by buying an upgrade.
4. The **Encyclopedia** shows every caught fish with a math fact.
5. The UI is **bilingual**: Ukrainian by default, English selectable at runtime.
6. The art matches the **reference folder** style (§9).
7. There is a **desktop build** that runs without the editor.

Out of scope for the MVP: story mode, complex animation, physics-based fishing, runtime problem generation, grid/Tetris-style inventory, accounts or online features.

### Design principle: upgrades never replace the math

No upgrade answers a problem, removes wrong options or skips a question. Upgrades give **more time, more room, better odds or a second attempt with a new problem**. The math always stays the gate.

---

## 2. Tech stack (decided)

| Area | Choice | Why |
|---|---|---|
| Engine | **Godot 4.x, GDScript** | One-click desktop export, free web export, built-in localization |
| Localization | Godot `TranslationServer` + CSV | `tr("KEY")` everywhere, one CSV holds UA and EN |
| Content data | JSON files in `res://data/` | Easy for Claude to generate and validate |
| Save data | JSON in `user://save.json` | Coins, hold, upgrades, encyclopedia |
| Math display | Plain Unicode (x², a³, −, ·, °) | No LaTeX renderer needed |
| Answer input | **Multiple choice, 4 options** | Avoids parsing, decimal commas, keyboard layout issues |
| Art | Style derived from `art_reference/` (§9) | One consistent look |
| Deploy | itch.io (desktop zip + optional HTML5) | Free, standard for small games |

### Project structure

```
art_reference/           # ← your inspiration .jpg files (NOT shipped in the build)
ART_STYLE.md             # written by Claude Code after analysing art_reference/ (§9)
DESIGN.md                # this file
res://
  scenes/
    Main.tscn            # menu: play, language, encyclopedia
    Map.tscn             # zone picker + dock
    Zone.tscn            # shared zone scene, configured by zone id
    Dock.tscn            # tabs: Market (sell) + Workshop (upgrades)
    ProblemPanel.tscn    # question + 4 answer buttons + timer
    ReelMinigame.tscn    # timing bar
    CatchCard.tscn       # fish reveal: sprite, name, rarity, size, value
    HoldPanel.tscn       # inventory slots (used in Zone and Dock)
    Encyclopedia.tscn    # list + detail page with math facts
  scripts/
    GameState.gd         # autoload: coins, hold, upgrades, encyclopedia, save/load
    FishingLoop.gd       # state machine (§3)
    ProblemBank.gd       # loads pools, shuffle-bag per tier, locale-aware
    FishTable.gd         # weighted rarity roll per zone, applies bait modifier
    Economy.gd           # sell prices, upgrade costs, purchase logic
  data/
    zones.json
    fish.json
    upgrades.json
    problems/
      powers_like_terms.json
      linear_equations.json
      angles_triangles.json   # stretch
  i18n/
    strings.csv          # keys,uk,en
  art/
    fish/ backgrounds/ ui/
tools/
  validate_problems.py   # checks every answer_index
  extract_palette.py     # pulls palette from art_reference/ (§9)
```

---

## 3. Game loops

### 3.1 Core loop (inside a zone)

```
        ┌───────────────────────────────────────────────────┐
        ▼                                                   │
   [IDLE] ── Cast (only if hold has a free slot) ──►        │
   [WAITING] random 2–5 s                                   │
        ▼                                                   │
   [BITE!] roll fish (zone table × bait modifier)           │
        ▼                                                   │
   [PROBLEM] tier = fish rarity · timer = base + rod bonus  │
      │ correct                  │ wrong / timeout          │
      ▼                          ▼                          │
   [REEL] timing bar        line upgrade charge left?       │
   (green zone = rod level)  yes → NEW problem, same tier   │
      │                      no  → [ESCAPED] show answer    │
      ▼                          + 1-line solution ─────────┤
   [CAUGHT] catch card → fish goes into the hold            │
   first catch of a species → encyclopedia entry unlocked   │
   (+10 coin discovery bonus) ──────────────────────────────┘

   Hold full → Cast button replaced by "Hold full: return to dock / release a fish"
```

### 3.2 Meta loop (between trips)

```
 Dock ──► pick zone on Map ──► fish until hold is full or you choose to leave
   ▲                                              │
   │                                              ▼
 Workshop: buy upgrades ◄── Market: sell fish ◄── return to Dock
```

A trip is **one hold's worth of fish**. At the start (6 slots, about 30 s per catch) that's about 3–4 minutes, which is a good rhythm for a classroom session.

### 3.3 Rarity drives difficulty

| Rarity | Base spawn weight | Problem tier | Base timer | Base sell price |
|---|---|---|---|---|
| Common | 60 | 1 (one step) | none | 5 |
| Uncommon | 28 | 2 (two steps) | none | 15 |
| Rare | 10 | 3 (multi-step or tricky) | 45 s | 40 |
| Legendary | 2 | 3 | 30 s | 100 |

When a zone has no fish of some rarity, that weight is dropped and the others are renormalized.

**Wrong answer:** always show the correct answer and a one-line worked step (for example `3x + 5 = 20 → 3x = 15 → x = 5`). This is where the learning happens, so never skip it.

**Reel minigame:** a moving marker with a green zone. It exists for feel, not for difficulty. A miss gives one retry, and a second miss loses the fish.

---

## 4. Inventory (the hold)

- The **hold (Трюм / Hold)** is a row of slots. **1 fish = 1 slot.** The MVP has no grid, fish shapes or weight.
- You start with **6 slots**. Hold upgrades raise this to 8 → 11 → 15.
- The HUD always shows `🧺 4/6`.
- **Hold full:** you can't cast. The button offers **"Return to dock"** or **"Release a fish"** (pick a slot to free it, with no coins).
- Each stored fish keeps its own `species`, `size_cm` and `value`. Two X-Eels of different sizes are worth different amounts.
- The hold persists in the save file, so quitting mid-trip loses nothing.
- *Stretch:* Dredge-style grid where bigger fish take more cells.

---

## 5. Economy: selling and upgrades

### 5.1 Selling (Market / Ринок)

```
sell_price = base_price[rarity] × (size_cm / avg_size_cm), rounded, minimum 1
```

- The dock has a **Market** tab: the hold is shown with a price under each fish. Buttons: **Sell** (one) and **Sell all**.
- Encyclopedia entries are never lost by selling, since discovery is recorded at catch time.
- *Optional:* a "Trophy" slot at the dock (1 slot) lets you keep your biggest catch on display instead of selling it.

**Expected income:** about **13 coins per catch** on average at the start (weighted by spawn rates), plus discovery bonuses. The rarity boosts from bait raise this.

### 5.2 Upgrades (Workshop / Майстерня)

| Upgrade | UA | Effect per level | L1 | L2 | L3 | MVP? |
|---|---|---|---|---|---|---|
| **Hold** | Трюм | Slots 6 → 8 → 11 → 15 | 40 | 100 | 200 | ✅ |
| **Rod** | Вудка | Timer +10 / +20 / +30 s; reel green zone +15% / +30% / +50% | 50 | 120 | 250 | ✅ |
| **Bait** | Наживка | Rare & Legendary weight ×1.5 / ×2 / ×3 | 60 | 150 | 300 | ✅ |
| **Boat** | Човен | Unlocks **Misty River** | 80 | — | — | ✅ |
| **Strong line** | Міцна волосінь | 1 / 2 / 3 "second chances" per trip (new problem, same tier, fish stays on) | 80 | 180 | 320 | Stretch |
| **Lantern** | Ліхтар | Unlocks **Deep Bay** | 300 | — | — | Stretch |

**Balance target:** buying all MVP upgrades costs about **1,350 coins**, which is **roughly one hour of play**. The boat (80) should arrive after about 10–15 catches, in the first 5–12 minutes, so every tester sees zone 2. The Workshop lists the boat first. *(Boat lowered from 150 after the economy simulation; see `Docs/ECONOMY_REPORT.md`.)*

Each purchase shows a short "before → after" line (for example `Timer: 45 s → 55 s`). Upgrade level is shown on the rig icon in the HUD.

### `upgrades.json` schema

```json
{ "id": "rod", "name_key": "UPG_ROD", "desc_key": "UPG_ROD_DESC",
  "levels": [
    { "cost": 50,  "timer_bonus_s": 10, "reel_zone_bonus": 0.15 },
    { "cost": 120, "timer_bonus_s": 20, "reel_zone_bonus": 0.30 },
    { "cost": 250, "timer_bonus_s": 30, "reel_zone_bonus": 0.50 }
  ] }
```

All numbers live in `upgrades.json` and `fish.json`, so balancing never needs a code change.

---

## 6. Math curriculum alignment

> ⚠️ **Verify on Day 1** against the current НУШ model program for grades 7–9 (mon.gov.ua). Fractions, ratios and percentages are mostly **6th grade** and are only used here as review inside other topics.

Expected 7th grade topics:

- **Algebra:** expressions, powers with natural exponents, monomials and polynomials, short multiplication formulas (формули скороченого множення), factoring, linear functions, linear equations, systems of linear equations
- **Geometry:** basic figures, adjacent and vertical angles, parallel lines, triangles (angle sum, congruence), the circle

### Topics used in the MVP

| Topic id | Zone | Tier 1 example | Tier 2 example | Tier 3 example |
|---|---|---|---|---|
| `powers_like_terms` | Still Lake | 2³ = ? | Simplify 3a + 5a − 2a | Simplify (2x²)³ |
| `linear_equations` | Misty River | x + 7 = 12 | 3x − 4 = 11 | 2(x − 3) = x + 5 |
| `angles_triangles` *(stretch)* | Deep Bay | Vertical angle to 40°? | Adjacent angle to 115°? | Triangle has angles 50° and x, the third is 2x. Find x |

### Problem pool spec

- About **15 problems per tier per topic**, pre-written, no runtime generation.
- MVP total: 2 topics × 3 tiers × 15 = **90 problems** (+45 for the stretch zone).
- **Wrong options (distractors) must come from real mistakes:** sign error, forgetting to distribute, adding exponents instead of multiplying, and so on. Never random numbers.
- No repeats until the tier's pool is used up (shuffle-bag). A "second chance" always draws a different problem.
- Numbers stay small, and answers are integers where possible.

### Problem JSON schema

```json
{
  "id": "lin_t2_004",
  "topic": "linear_equations",
  "tier": 2,
  "question": { "uk": "Розв'яжіть рівняння: 3x − 4 = 11", "en": "Solve: 3x − 4 = 11" },
  "options": ["5", "7/3", "−5", "15"],
  "answer_index": 0,
  "solution": { "uk": "3x = 15 → x = 5", "en": "3x = 15 → x = 5" },
  "distractor_notes": ["", "subtracted 4 instead of adding", "sign error", "forgot to divide by 3"]
}
```

Shuffle the `options` order at runtime and remap `answer_index`. `distractor_notes` are for dev and QA only and are never shown to the player.

---

## 7. Zones

| Id | Name (UA / EN) | Mood | Topic | Unlock | MVP? |
|---|---|---|---|---|---|
| `lake` | Тихе озеро / Still Lake | Calm, golden hour, reeds | `powers_like_terms` | Start | ✅ |
| `river` | Туманна річка / Misty River | Fog, lanterns, blue-grey | `linear_equations` | **Boat** upgrade | ✅ |
| `bay` | Глибока затока / Deep Bay | Night, bioluminescence | `angles_triangles` | **Lantern** upgrade | Stretch |

Final moods and colors follow `ART_STYLE.md` (§9). The descriptions above are starting points.

### `zones.json` schema

```json
{ "id": "river", "name_key": "ZONE_RIVER", "topic": "linear_equations",
  "background": "res://art/backgrounds/river.png",
  "unlock": { "upgrade": "boat", "level": 1 },
  "fish": ["fog_catfish", "x_eel", "balanced_sturgeon", "great_null"] }
```

---

## 8. Fish and Encyclopedia

### 8.1 Fish roster

v2 fills the rarity gaps, so each MVP zone has Common, Uncommon and Rare fish, and the river adds a Legendary.

| Id | UA | EN | Zone | Rarity | Avg size |
|---|---|---|---|---|---|
| `zero_perch` | Окунь-Нулик | Zero Perch | lake | Common | 25 cm |
| `square_carp` | Квадратний карась | Square Carp | lake | Common | 30 cm |
| `mirror_bream` | Дзеркальний лящ | Mirror Bream | lake | Uncommon | 40 cm |
| `power_pike` | Степенева щука | Power Pike | lake | Rare | 80 cm |
| `fog_catfish` | Туманний сом | Fog Catfish | river | Common | 60 cm |
| `x_eel` | Ікс-вугор | X-Eel | river | Uncommon | 70 cm |
| `balanced_sturgeon` | Врівноважений осетер | Balanced Sturgeon | river | Rare | 120 cm |
| `great_null` | Велика Нуль-Сомиха | The Great Null | river | Legendary | 200 cm |
| `anglejaw` | Кутозуб | Anglejaw | bay *(stretch)* | Uncommon | 50 cm |
| `triangle_ray` | Трикутний скат | Triangle Ray | bay *(stretch)* | Legendary | 150 cm |

Sizes are rolled from `avg × 0.6` to `avg × 1.4` (the result gives "New record!" moments and feeds the sell price).

### 8.2 Encyclopedia (Енциклопедія)

This replaces the Fishdex. It's the main place in the game for learning outside the problems themselves.

**List view:** a grid of all species. Uncaught fish show a dark silhouette with "???". The header shows how many are discovered (`5 / 8`).

**Detail page, unlocked on first catch:**

- Sprite (large), UA/EN name, rarity, zone
- **Records:** times caught, biggest size, best sell price
- **Flavor line:** a short, funny description
- **Цікавий факт / Math fact:** a real fact from math history or ideas, linked to the fish's motif
- **Спробуй / Try it:** a single mini-question with the answer revealed on tap (no reward, just for curiosity)
- **Deeper fact:** unlocked after catching **5** of that species. It's a second fact, so there's a reason to keep catching common fish.

**Completion reward:** discovering every fish in a zone gives a one-time **+50 coins** and a small badge on the zone card.

### 8.3 Encyclopedia content (EN drafts; Ukrainian should be written natively, not translated word for word)

| Fish | Flavor | Math fact | Try it | Deeper fact (5 catches) |
|---|---|---|---|---|
| Zero Perch | "Worth nothing, it insists. Multiply it by anything and see." | The Indian mathematician Brahmagupta wrote rules for calculating with zero in 628 CE, one of the earliest known. | 0 · 999 = ? → 0 | You can't divide by zero: no number times 0 gives 5. |
| Square Carp | "Its scales grow in perfect squares: 1, 4, 9…" | Adding odd numbers in order gives perfect squares: 1 + 3 + 5 = 9 = 3². | 1 + 3 + 5 + 7 = ? → 16 = 4² | That's why x² is called "x squared": it's the area of a square with side x. |
| Mirror Bream | "Left side, right side: always the same." | (a + b)(a − b) = a² − b². This lets you do 21 · 19 in your head: 400 − 1 = 399. | 31 · 29 = ? → 899 | Many multiplication shortcuts come from this kind of symmetry. |
| Power Pike | "Each year its bite doubles. Its bite doubles too." | In the old wheat-and-chessboard legend, one grain doubles on each of 64 squares. The total is 2⁶⁴ − 1, more wheat than the world has ever grown. | 2¹⁰ = ? → 1024 | When multiplying powers with the same base, add the exponents: 2³ · 2⁴ = 2⁷. |
| Fog Catfish | "Only the whiskers are sure. The rest is x." | A variable is a name for a number we don't know yet, like a fish hidden in fog. | If x = 3, what is 2x + 1? → 7 | The same expression can give many values: that's how a formula works. |
| X-Eel | "Slippery. Isolate it before it slips to the other side." | René Descartes popularized using x, y, z for unknowns in *La Géométrie* (1637). | x + 4 = 10 → x = 6 | To "isolate" x, undo each operation in reverse order. |
| Balanced Sturgeon | "Whatever you do to one side, do to the other." | The word "algebra" comes from al-jabr, "restoring", in the title of al-Khwarizmi's 9th-century book on solving equations. | 5x = 35 → x = 7 | An equation is like a balance scale: equal changes on both sides keep it level. |
| The Great Null | "Nobody has seen all of her. Everyone has seen her reflection." | A linear equation can have one solution, no solutions (x = x + 1) or infinitely many (x = x). | How many solutions does 2x = 2x have? → infinitely many | The same idea returns in systems of equations, where lines can cross, run parallel or overlap. |
| Anglejaw *(stretch)* | "Its jaw opens at exactly 90°. Never more." | We likely use 360° for a full turn because of the ancient Babylonians' base-60 number system. | A right angle + 45° = ? → 135° | Vertical angles are always equal. |
| Triangle Ray *(stretch)* | "Three fins, 180 degrees of pure menace." | A triangle's angles add up to 180° on a flat surface, but on a sphere (like a globe) they add up to more. | 60° + 70° + ? = 180° → 50° | A globe triangle can even have three 90° angles. |

> Have a Ukrainian teacher check the facts and wording before release. The facts above are well established, but short phrasings can accidentally become inaccurate.

### `fish.json` schema

```json
{ "id": "x_eel", "zone": "river", "rarity": "uncommon",
  "avg_size_cm": 70, "sprite": "res://art/fish/x_eel.png",
  "name_key": "FISH_X_EEL",
  "flavor_key": "FISH_X_EEL_FLAVOR",
  "fact_key": "FISH_X_EEL_FACT",
  "try_q_key": "FISH_X_EEL_TRY_Q", "try_a_key": "FISH_X_EEL_TRY_A",
  "deep_fact_key": "FISH_X_EEL_DEEP", "deep_fact_unlock": 5 }
```

---

## 9. Art direction: based on the reference folder

### 9.1 Source of truth

The developer will provide a folder of inspiration images: **`art_reference/*.jpg`**. **The game's art must follow the style of these images.** Everything in this section that describes a specific look is a fallback, used only for what the references don't cover.

### 9.2 Step 0 for Claude Code: write `ART_STYLE.md`

Before making any art assets, Claude Code should look at every image in `art_reference/` and write `ART_STYLE.md` with:

1. **Medium and rendering:** pixel art, painterly, flat vector, hand-drawn, 3D-render or other. If pixel art, estimate the native resolution and pixel size.
2. **Palette:** 16–32 hex colors, extracted with `tools/extract_palette.py` (k-means over all images) and then cleaned up by hand. Note which colors are for shadows, highlights and accents.
3. **Line work:** outlines yes/no, color (black or darker version of the fill), thickness.
4. **Shading and light:** flat, cel, soft gradients; light direction; use of glow or fog.
5. **Shapes and proportions:** how creatures and objects are stylized (big eyes? exaggerated silhouettes?).
6. **Composition and camera:** side view, top-down, isometric; how much empty space.
7. **Mood words:** 5–8 adjectives.
8. **Do / Don't list** with filename references (e.g. "Do: fog layers like `ref_03.jpg`").
9. **Filled-in prompt templates** for fish, backgrounds and UI (fill in the §9.4 templates below with the findings).
10. **Godot import settings** that match the style (nearest-neighbour + no mipmaps for pixel art; linear filtering for painterly styles).

`ART_STYLE.md` becomes the style guide for every asset. If an asset doesn't match it, regenerate or edit the asset.

### 9.3 Rules

- **Don't ship or trace the references.** They define the style only. Keep `art_reference/` out of the Godot export (add it to the exclude filter).
- **One palette for everything.** Run every AI output through palette reduction to the `ART_STYLE.md` colors, so AI images from different batches look like one set.
- **Tone:** "eerie-cute", fitting for 12–13 year olds, even if the references are darker.
- **Readability first:** fish must be recognizable at their in-game size. Math text is always on a solid panel, never directly on the art.
- **UI:** a ready-made UI pack (e.g. Kenney, CC0), recolored to the palette, unless the references suggest a specific UI style.

### 9.4 Prompt templates (Claude Code fills the brackets from `ART_STYLE.md`)

**Fish:**
```
[MEDIUM from ART_STYLE] of a [FISH DESCRIPTION], side view facing right,
[MATH MOTIF, e.g. "scales shaped like small squares" / "body curved into an x"],
eerie but cute, [SHAPE LANGUAGE], [LINE WORK], [SHADING],
palette: [PALETTE WORDS], plain background, game asset, single subject, no text
```

**Background:**
```
[MEDIUM from ART_STYLE] landscape, [ZONE DESCRIPTION],
[CAMERA/COMPOSITION], wooden dock in foreground, [LIGHTING + FOG],
palette: [PALETTE WORDS], [MOOD WORDS], 16:9, no characters, no text
```

Asset list for the MVP: 8 fish sprites + 8 silhouettes (auto-generated by filling the sprite with a single dark color), 2 zone backgrounds, 1 dock background, 1 map, 6 upgrade icons, and UI frames and buttons.

---

## 10. UI (wireframes)

```
ZONE
┌──────────────────────────────────────────────────────────────┐
│ [Map] Тихе озеро     🪙 120   🧺 4/6   🎣Lv2 🪱Lv1   [📖] [UA|EN] │
│                                                              │
│                    (background art)                          │
│                        ~~~ 🎣 ~~~                             │
│                                                              │
│  [🐟][🐟][🐟][🐟][  ][  ]             [ ЗАКИНУТИ / CAST ]     │
└──────────────────────────────────────────────────────────────┘

PROBLEM PANEL (modal)             CATCH CARD
┌──────────────────────────┐      ┌──────────────────────────┐
│ ★★★ Rare bite!    ⏱ 48   │      │   [ fish sprite ]        │
│ Спростіть: (2x²)³         │      │ Степенева щука · RARE    │
│ [ 8x⁶ ]  [ 6x⁵ ]          │      │ 74 см · ≈37 🪙 · NEW! 📖 │
│ [ 2x⁶ ]  [ 8x⁵ ]          │      │ → В трюм / To hold       │
└──────────────────────────┘      └──────────────────────────┘

DOCK
┌──────────────────────────────────────────────────────────────┐
│  [ Ринок / Market ]   [ Майстерня / Workshop ]     🪙 120      │
│ ─────────────────────────────────────────────────────────── │
│ Market:  [🐟 12🪙][🐟 5🪙][🐟 41🪙][🐟 16🪙]   [Sell all: 74🪙] │
│ Workshop:                                                    │
│  Трюм     Lv1 → Lv2   6 → 8 slots          [ 100 🪙 ]         │
│  Вудка    Lv0 → Lv1   Timer 45 s → 55 s    [  50 🪙 ]         │
│  Наживка  Lv0 → Lv1   Rare ×1 → ×1.5       [  60 🪙 ]         │
│  Човен    Unlocks Misty River               [  80 🪙 ]         │
└──────────────────────────────────────────────────────────────┘

ENCYCLOPEDIA DETAIL
┌──────────────────────────────────────────────────────────────┐
│ [large sprite]  Ікс-вугор / X-Eel · UNCOMMON · Misty River    │
│ Caught: 3   Biggest: 84 cm   Best price: 19 🪙                 │
│ "Slippery. Isolate it before it slips to the other side."    │
│ 💡 Цікавий факт: René Descartes popularized x, y, z …         │
│ ✏️ Спробуй: x + 4 = 10   [Show answer]                        │
│ 🔒 Deeper fact: catch 5 (3/5)                                 │
└──────────────────────────────────────────────────────────────┘
```

**Rules:**
- Minimum font size 20 px. Use a Cyrillic-capable font (e.g. **Nunito** or **PT Sans**, both OFL), or one that matches `ART_STYLE.md` and supports Cyrillic.
- Every visible string goes through `tr()`. There are no hardcoded strings.
- Leave about 30% extra space in text areas, because Ukrainian strings run longer than English.
- Rarity colors: Common grey · Uncommon green · Rare blue · Legendary gold (adjust to the palette).
- Unaffordable upgrades are greyed out with the missing amount shown ("need 30 more 🪙").

---

## 11. Localization

- `res://i18n/strings.csv` with columns `keys,uk,en`. Import it as a translation in Project Settings.
- The default locale is `uk`. The language toggle calls `TranslationServer.set_locale()` and is saved in `save.json`.
- Problem text lives in the problem JSONs (`{uk, en}`). Everything else, including encyclopedia text, is in the CSV.
- Key naming: `UI_*`, `ZONE_*`, `FISH_<ID>`, `FISH_<ID>_FLAVOR / _FACT / _TRY_Q / _TRY_A / _DEEP`, `UPG_<ID> / _DESC`, `RARITY_*`.
- Math terms to keep consistent: рівняння (equation), спростіть (simplify), розв'яжіть (solve), степінь (power), подібні доданки (like terms), суміжні / вертикальні кути (adjacent / vertical angles), трюм (hold), наживка (bait), вудка (rod).
- Have a Ukrainian speaker or teacher proofread the math wording and the encyclopedia before release.

---

## 12. Save data

```json
{ "version": 2, "locale": "uk", "coins": 120,
  "hold": [ { "species": "x_eel", "size_cm": 84, "value": 18 },
            { "species": "fog_catfish", "size_cm": 52, "value": 4 } ],
  "upgrades": { "hold": 1, "rod": 2, "bait": 0, "boat": 1, "line": 0, "lantern": 0 },
  "encyclopedia": { "x_eel": { "count": 3, "best_cm": 84, "best_value": 19 } },
  "zone_complete_rewarded": ["lake"],
  "trophy": null }
```

Save automatically after every catch, sale and purchase.

---

## 13. Sprint plan (7 days)

The new systems are data-driven and small, but they add about a day of work. To make room, **Deep Bay, Strong Line and Lantern are firmly stretch goals.**

| Day | Focus | Done when |
|---|---|---|
| **1** | Curriculum check · Godot project + structure · **Claude Code analyses `art_reference/` and writes `ART_STYLE.md`** · `strings.csv` stub | Empty project exports; `ART_STYLE.md` exists with palette + templates |
| **2** | Problem pools (90) + validator · `fish.json`, `zones.json`, `upgrades.json` · encyclopedia text · **start art batches** from `ART_STYLE.md` | All JSONs load; validator passes |
| **3** | `FishingLoop`, `ProblemBank`, `FishTable` with placeholders | One full loop: cast → problem → catch |
| **4** | Hold (inventory), catch card, escape + solution, Dock/Market selling, save/load | Full trip works: fill hold → sell → coins |
| **5** | Workshop upgrades (Hold, Rod, Bait, Boat), zone unlock, Encyclopedia screens | Can buy the boat and reach the river |
| **6** | Art integration · UA/EN pass · **playtest with a real 7th grader** · balance prices | Tester buys the boat within about 8 minutes without help |
| **7** | Bug fixes, desktop exports (+HTML5), itch.io page | Public or unlisted itch.io link works |

**Stretch, only if ahead:** Strong Line, Lantern + Deep Bay, trophy slot, sound (splash, reel, coin, catch jingle), grid inventory.

---

## 14. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Art takes longer than expected | `ART_STYLE.md` on Day 1, batches from Day 2, placeholders until Day 5 |
| AI art doesn't match the references | Palette reduction + fixed templates; compare each asset against the Do/Don't list |
| Players grind easy fish and avoid hard problems | Rare fish are worth 8× commons; bait pushes toward harder problems; deeper facts reward variety |
| Economy too slow or too fast | All numbers in JSON; balance target in §5.2; tune after the Day 6 playtest |
| Upgrades feel like "pay to skip math" | Principle in §1: upgrades never answer or simplify problems |
| Math or fact errors | Validation script for answers; teacher review of facts and wording |
| Wrong curriculum level | Day 1 check against the МОН program |
| Scope creep | Stretch list in §13 is explicit and final for this sprint |

---

## 15. Handoff notes for Claude Code

Suggested order of prompts:

0. "Read `DESIGN.md`. Then analyse every image in `art_reference/`, write `tools/extract_palette.py`, and create `ART_STYLE.md` following §9.2."
1. "Set up a Godot 4 project with the structure in §2, autoload `GameState`, exclude `art_reference/` from exports, and create `strings.csv` with keys from §8, §10 and §11."
2. "Generate `problems/linear_equations.json` and `problems/powers_like_terms.json`, 15 per tier, following §6. Distractors must come from real student mistakes. Write `tools/validate_problems.py`, which checks every `answer_index` by computing the answer."
3. "Create `fish.json`, `zones.json` and `upgrades.json` from §5, §7 and §8, and fill the encyclopedia strings in `strings.csv` (native Ukrainian, not a literal translation)."
4. "Implement `FishingLoop.gd` (§3), `FishTable.gd` (weights × bait) and `ProblemBank.gd` (shuffle-bag, locale-aware) with placeholder visuals."
5. "Implement the hold (§4), `Economy.gd` and the Dock scene with Market and Workshop (§5, §10)."
6. "Build `ProblemPanel`, `ReelMinigame`, `CatchCard`, `HoldPanel` and `Encyclopedia` scenes following the §10 wireframes, styled per `ART_STYLE.md`."
7. "Add save/load (§12), upgrade-based zone unlocking (§7) and discovery/completion rewards (§8.2)."
8. "Write a quick economy simulation: 60 minutes of play at 70% accuracy. Report when each upgrade is bought and suggest tuning."
9. "Configure export presets for Windows, macOS, Linux and HTML5."

Keep this file in the repo root as `DESIGN.md` so every Claude Code session can read it.
