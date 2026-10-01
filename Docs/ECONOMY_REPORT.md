# Economy simulation report (DESIGN.md §15 step 8)

**Date:** 2026-09-30 · **Data:** `data/*.json` as of the step 7 commit · **Tool:** `tests/EconomySim.tscn`

## Summary

> **Out of date since v3 (2026-09-30):** the Boat is gone and zones now open by beating bosses, so the tables below no longer match the game. Rerun `tests/EconomySim.tscn` (it models boss fights now; there's no `--strategy` option any more). A first 90-minute run showed the river opening around minute 37 (P90 ≈ 64), mostly because the lake's legendary fish must be caught before the boss appears.

> **Applied (2026-09-30):** suggestions 1 and 2. The Boat now costs 80 and is listed first in the Workshop. The "Current data" tables below are the *before* numbers.

- **The boat comes far too late for a typical player.** A player who always buys the cheapest affordable upgrade gets the boat at **minute 37 (52 catches)**. The §5.2 target is **5–8 minutes (10–12 catches)** so that every tester sees zone 2. Only a player who deliberately saves for the boat hits the target (minute 9, 12 catches).
- **Recommended fix: Boat 150 → 80 coins.** Cheapest-first players then reach the river at **minute 12 (14 catches)**, and boat-first players at **minute 5.5 (6 catches)**. More players also finish every upgrade within the hour (47 % instead of 22 %), because the river pays better and brings 4 new discoveries plus a completion bonus.
- **The overall pace is on target.** At 70 % accuracy the median player earns about **1,240–1,340 coins an hour**, against 1,350–1,420 for every upgrade, so "all upgrades ≈ one hour" (§5.2) holds.
- **Accuracy matters a lot, as intended.** At 50 % accuracy a player earns about 840–920 coins an hour. At 90 % it's about 1,630. The math stays the gate.
- **Timers almost never run out** in this model. Rare fish (45 s) never time out. Legendary fish (30 s) time out 0–6 % of the time, because Rod upgrades usually arrive before the river. The real solve times from the playtest will tell whether that holds.

## Method

The simulation plays 500 independent 60-minute sessions per scenario using the **game's own code**: `FishTable.roll` (rarity weights × bait), `FishTable.roll_size`, `Economy.sell_price`, `GameState.record_catch` (discovery +10, zone completion +50), `Economy.sell_all` and `Economy.buy`. A change to the data files or the economy code is reflected on the next run.

On top of that code sits a time model. **Every number in it is an assumption, not a measurement**:

| Step | Seconds |
|---|---|
| Click Cast | 1 |
| Wait for a bite | 2–5 (from `fish.json`) + 1 "Bite!" |
| Read and solve a problem | tier 1: 8 · tier 2: 16 · tier 3: 28, each × random 0.6–1.5 |
| Timeout | the rarity's timer (+ Rod bonus); counts as a miss |
| Reel attempt | 2.5; hit chance 0.35 + 1.75 × green-zone width (0.70 at the base 20 %) |
| Catch card | 3 |
| Reading the answer and solution after a miss | 7 |
| Dock visit (walk, sell, shop, walk back) | 45 |

**Player behaviour:**
- The player fishes until the hold is full, then sells everything and shops.
- The player fishes the river as soon as it's unlocked.
- Shopping follows one of two strategies:
  - **cheapest:** keep buying the cheapest affordable next level (the likely habit of a 12-year-old).
  - **boat_first:** save for the boat, then buy the cheapest.
- Accuracy is the same for every problem (50 / 70 / 90 %), or **tiered** at 85 / 70 / 55 % for tiers 1 / 2 / 3.

## Results

### Current data, 70 % accuracy, cheapest-first

| Purchase | Reached | Minute (P10 / median / P90) | Catches (median) |
|---|---|---|---|
| hold L1 (40) | 100 % | 3.5 / 4.5 / 6.2 | 6 |
| rod L1 (50) | 100 % | 3.8 / 6.1 / 11.3 | 6 |
| bait L1 (60) | 100 % | 4.4 / 10.0 / 14.9 | 14 |
| hold L2 (100) | 100 % | 9.7 / 13.9 / 18.8 | 22 |
| rod L2 (120) | 100 % | 16.7 / 21.2 / 27.1 | 25 |
| bait L2 (150) | 100 % | 24.0 / 29.4 / 36.0 | 44 |
| **boat L1 (150)** | 100 % | 31.2 / **37.1** / 44.4 | **52** |
| hold L3 (200) | 99 % | 39.5 / 45.9 / 53.0 | 66 |
| rod L3 (250) | 71 % | 46.0 / 53.7 / 59.0 | 73 |
| bait L3 (300) | 22 % | 51.5 / 57.3 / 60.1 | 81 |

| Metric | Median (P10–P90) |
|---|---|
| All 10 levels bought (1,420 coins) | 22 % of runs; minute 57.3 |
| Catches in 60 min | 84 (77–91) |
| Coins earned (sales + bonuses) | 1,239 (987–1,501) |
| Coins per catch | 14.8 |
| Seconds per cast (including misses and dock) | 28.7 |
| Casts that end in a catch | 66 % |
| Dock visits | 8 |
| Catch mix | common 56 %, uncommon 27 %, rare 16 %, legendary 1.4 % |

### With Boat = 80, 70 % accuracy, cheapest-first

| Purchase | Reached | Minute (P10 / median / P90) | Catches (median) |
|---|---|---|---|
| hold L1 (40) | 100 % | 3.5 / 4.6 / 6.1 | 6 |
| rod L1 (50) | 100 % | 3.9 / 6.5 / 11.7 | 6 |
| bait L1 (60) | 100 % | 4.5 / 9.8 / 14.8 | 14 |
| **boat L1 (80)** | 100 % | 9.3 / **12.3** / 19.1 | **14** |
| hold L2 (100) | 100 % | 14.2 / 17.9 / 24.2 | 22 |
| rod L2 (120) | 100 % | 17.9 / 24.8 / 30.9 | 33 |
| bait L2 (150) | 100 % | 23.1 / 30.7 / 38.3 | 44 |
| hold L3 (200) | 100 % | 30.2 / 38.2 / 48.3 | 52 |
| rod L3 (250) | 90 % | 40.8 / 48.5 / 56.4 | 67 |
| bait L3 (300) | 47 % | 48.6 / 55.6 / 59.7 | 74 |

| Metric | Median (P10–P90) |
|---|---|
| All 10 levels bought (1,350 coins) | 47 % of runs; minute 55.6 |
| Coins earned (sales + bonuses) | 1,337 (1,054–1,606) |
| Coins per catch | 16.0 |
| Timeouts: rare / legendary | 0 % / 2 % |

### All scenarios (500 sessions each)

| Scenario | Boat bought: minute (catches) | Coins / hour | All upgrades within 60 min | Legendary timeouts |
|---|---|---|---|---|
| Current, 70 %, cheapest | 37.1 (52) | 1,239 | 22 % | 0 % |
| Current, 70 %, boat-first | **9.0 (12)** | 1,297 | 27 % | 6 % |
| Current, 50 %, cheapest | 50.2 (47); 10 % never | 839 | 0 % | 0 % |
| Current, 90 %, cheapest | 30.0 (55) | 1,630 | 88 % | 0 % |
| Current, tiered, cheapest | 38.9 (58) | 1,135 | 6 % | 0 % |
| **Boat 80, 70 %, cheapest** | **12.3 (14)** | 1,337 | 47 % | 2 % |
| Boat 80, 70 %, boat-first | **5.5 (6)** | 1,287 | 40 % | 3 % |
| Boat 80, tiered, cheapest | 13.3 (22) | 1,236 | 32 % | 2 % |
| Boat 80, 50 %, cheapest | 16.1 (14) | 922 | 2 % | 3 % |

## Suggested tuning

1. **Boat: 150 → 80 coins** (`data/upgrades.json`). This is the one change the numbers clearly call for. It meets the §5.2 goal for players who save up, and gets close for players who don't. The total for all MVP upgrades drops from 1,420 to 1,350, which is still about one hour.
2. **List the Boat first in the Workshop** until it's bought, by moving it to the top of `upgrades.json`. The simulation can't model this, but children tend to buy what they see first, and that pushes behaviour toward the boat-first row above (minute 5.5).
3. **Keep the other prices as they are.** Hold, Rod and Bait spread nicely across the hour. Bait L3 (300) is a late goal that about half of players reach, which is a good "one more trip" reason.
4. **Watch struggling players during the playtest; don't change anything yet.** At 50 % accuracy a player still reaches the river by minute 16 with the cheaper boat, but earns about ⅔ as much. If they look discouraged, the gentlest fix is **common fish 5 → 6 coins**. Commons come with tier-1 problems, so it helps without weakening the math gate. Don't cut prices across the board.
5. **Keep the timers until there's real data.** They rarely trigger in this model, but the solve times (8 / 16 / 28 s) are guesses. If real tier-3 solves take closer to 40 s, legendary fish at 30 s will time out often before Rod L2.

## To measure in the Day 6 playtest

These are the model's weakest assumptions. Plug the real values into the constants at the top of `tests/economy_sim.gd` and rerun:

- Seconds to answer a tier 1 / 2 / 3 problem, and accuracy per tier
- Reel hit rate on the first attempt
- Time spent at the dock per visit
- Which upgrade each tester buys first

## Rerunning

```bash
<godot_console> --headless --path . res://tests/EconomySim.tscn -- --runs=500
<godot_console> --headless --path . res://tests/EconomySim.tscn -- --runs=500 --strategy=boat_first --tiered
<godot_console> --headless --path . res://tests/EconomySim.tscn -- --set=upgrades.boat.levels.0.cost=80 --out=Docs/sim.md
```

`--set` overrides any data value for one run only (e.g. `--set=rarities.legendary.timer_s=40`), so changes can be tried out before editing the JSON. The simulation never writes a save file.
