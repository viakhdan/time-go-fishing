extends Node
## Economy simulation (DESIGN.md §15 step 8): plays many 60-minute sessions with
## the real FishTable / Economy / GameState code and a simple time model, then
## reports when each upgrade gets bought. Run (headless is fine):
##   <godot_console> --headless --path . res://tests/EconomySim.tscn -- [options]
## Options:
##   --runs=300 --minutes=60 --accuracy=0.7 --seed=1
##   --tiered            accuracy by tier 0.85 / 0.70 / 0.55 instead of flat
##   The player buys the cheapest affordable upgrade, fishes the newest open
##   zone, and fights its boss (at most once per trip) once it appears.
##   --out=<file.md>     also write the markdown report there
##   --set=<path>=<value>  override game data for this run only (repeatable), e.g.
##                       --set=upgrades.hold.levels.0.cost=60
##                       --set=rarities.legendary.timer_s=40
## Never saves: GameState.saving_enabled is switched off.

# --- Time model (seconds). Assumptions, not measurements: tune after the playtest.
const CAST_CLICK_S := 1.0
## Reading + solving time per problem tier, multiplied by a random 0.6–1.5.
const SOLVE_S := {1: 8.0, 2: 16.0, 3: 28.0}
const REEL_ATTEMPT_S := 2.5
const CATCH_CARD_S := 3.0
## Reading the correct answer and the solution after a miss.
const MISS_FEEDBACK_S := 7.0
## Map → Dock, selling, browsing the Workshop, Dock → Map → zone.
const DOCK_VISIT_S := 45.0
## Chance to stop the reel marker in the green zone: 0.70 at the base 20 %
## zone, rising with the rod's wider zone.
const REEL_HIT_BASE := 0.35
const REEL_HIT_PER_ZONE := 1.75
const TIERED_ACCURACY := {1: 0.85, 2: 0.70, 3: 0.55}

var runs := 300
var minutes := 60.0
var accuracy := 0.7
var tiered := false
var out_path := ""
var overrides: Array[String] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	_parse_args()
	GameState.saving_enabled = false
	var results := []
	for i in runs:
		results.append(_simulate_session())
	var report := _report(results)
	print(report)
	if out_path:
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(report)
		f.close()
	get_tree().quit()


func _parse_args() -> void:
	var seed_value := 1
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		var value := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"runs": runs = int(value)
			"minutes": minutes = float(value)
			"accuracy": accuracy = float(value)
			"tiered": tiered = true
			"seed": seed_value = int(value)
			"out": out_path = value
			"set": overrides.append(value)
	rng.seed = seed_value
	for o in overrides:
		_apply_override(o)


## "upgrades.hold.levels.0.cost=60" → GameData._upgrades.hold.levels[0].cost = 60
func _apply_override(spec: String) -> void:
	var parts := spec.split("=", true, 1)
	var path := parts[0].split(".")
	var roots := {"upgrades": GameData._upgrades, "rarities": GameData._rarities,
		"fish": GameData._fish, "zones": GameData._zones, "fishing": GameData.fishing}
	var node = roots[path[0]]
	for i in range(1, path.size() - 1):
		node = node[int(path[i])] if node is Array else node[path[i]]
	var key = int(path[-1]) if node is Array else path[-1]
	node[key] = float(parts[1])


# --- One session ----------------------------------------------------------------

func _simulate_session() -> Dictionary:
	GameState.reset()
	var s := {
		"t": 0.0, "catches": 0, "attempts": 0, "correct": 0, "timeouts": 0,
		"reel_losses": 0, "trips": 0, "earned": 0, "purchases": [],
		"timed_attempts": {"rare": 0, "legendary": 0}, "timed_timeouts": {"rare": 0, "legendary": 0},
		"rarity_catches": {}, "bosses": [], "boss_attempts": 0,
	}
	var limit := minutes * 60.0
	while s.t < limit:
		GameState.start_trip()
		s.trips += 1
		var zone := _newest_open_zone()
		var fought := false
		while not GameState.is_hold_full() and s.t < limit:
			if not fought and GameData.is_boss_available(zone) and zone not in GameState.bosses_defeated:
				fought = true
				_boss_fight(zone, s)
				continue
			_attempt(zone, s)
		if s.t >= limit:
			break
		s.t += DOCK_VISIT_S
		s.earned += Economy.sell_all()
		_shop(s)
	return s


func _newest_open_zone() -> String:
	var newest := "lake"
	for z in GameData.zones():
		if GameData.is_zone_unlocked(z.id):
			newest = z.id
	return newest


## Tier-3 problems until 3 hits (win) or 2 misses (escape), then the reel.
func _boss_fight(zone: String, s: Dictionary) -> void:
	s.boss_attempts += 1
	var boss: String = GameData.zone(zone).boss
	var rules := GameData.boss_fight
	var hearts := int(rules.hearts)
	var misses := 0
	var limit: float = GameData.rarity("boss").timer_s + GameData.upgrade_effect("rod", "timer_bonus_s")
	var p_correct: float = TIERED_ACCURACY[3] if tiered else accuracy
	while hearts > 0:
		var solve: float = SOLVE_S[3] * rng.randf_range(0.6, 1.5)
		if solve > limit or rng.randf() >= p_correct:
			s.t += minf(solve, limit) + MISS_FEEDBACK_S
			misses += 1
			if misses >= int(rules.max_misses):
				return
		else:
			s.t += solve
			hearts -= 1
	var zone_fraction := minf(0.9, GameData.fishing.reel_zone * (1.0 + GameData.upgrade_effect("rod", "reel_zone_bonus")))
	var p_hit := clampf(REEL_HIT_BASE + REEL_HIT_PER_ZONE * zone_fraction, 0.0, 0.95)
	for i in int(rules.reel_attempts):
		s.t += REEL_ATTEMPT_S
		if rng.randf() < p_hit:
			var size := FishTable.roll_size(boss, rng)
			var coins_before := GameState.coins
			GameState.record_catch(boss, size, Economy.sell_price(boss, size))
			s.earned += GameState.coins - coins_before
			s.catches += 1
			s.bosses.append({"zone": zone, "t": s.t, "catches": s.catches})
			s.t += CATCH_CARD_S
			return


func _attempt(zone: String, s: Dictionary) -> void:
	var wait: Array = GameData.fishing.bite_wait_s
	s.t += CAST_CLICK_S + rng.randf_range(wait[0], wait[1]) + GameData.fishing.bite_delay_s
	var fish_id := FishTable.roll(zone, rng)
	var rarity_id: String = GameData.fish(fish_id).rarity
	var rarity := GameData.rarity(rarity_id)
	var tier := int(rarity.tier)
	s.attempts += 1

	var solve: float = SOLVE_S[tier] * rng.randf_range(0.6, 1.5)
	var base_timer: float = rarity.timer_s
	var limit := base_timer + GameData.upgrade_effect("rod", "timer_bonus_s") if base_timer > 0.0 else INF
	if base_timer > 0.0:
		s.timed_attempts[rarity_id] += 1
	if solve > limit:
		s.t += limit + MISS_FEEDBACK_S
		s.timeouts += 1
		s.timed_timeouts[rarity_id] += 1
		return
	s.t += solve
	var p_correct: float = TIERED_ACCURACY[tier] if tiered else accuracy
	if rng.randf() >= p_correct:
		s.t += MISS_FEEDBACK_S
		return
	s.correct += 1

	var zone_fraction := minf(0.9, GameData.fishing.reel_zone * (1.0 + GameData.upgrade_effect("rod", "reel_zone_bonus")))
	var p_hit := clampf(REEL_HIT_BASE + REEL_HIT_PER_ZONE * zone_fraction, 0.0, 0.95)
	var hit := false
	for i in int(GameData.fishing.reel_attempts):
		s.t += REEL_ATTEMPT_S
		if rng.randf() < p_hit:
			hit = true
			break
	if not hit:
		s.reel_losses += 1
		s.t += MISS_FEEDBACK_S / 2.0
		return

	var size := FishTable.roll_size(fish_id, rng)
	var coins_before := GameState.coins
	GameState.record_catch(fish_id, size, Economy.sell_price(fish_id, size))
	s.earned += GameState.coins - coins_before  # discovery + completion bonuses
	s.catches += 1
	s.rarity_catches[rarity_id] = s.rarity_catches.get(rarity_id, 0) + 1
	s.t += CATCH_CARD_S


func _shop(s: Dictionary) -> void:
	while true:
		var options := GameData.upgrades().filter(func(u): return Economy.can_buy(u.id))
		if options.is_empty():
			return
		options.sort_custom(func(a, b): return Economy.next_cost(a.id) < Economy.next_cost(b.id))
		var id: String = options[0].id
		Economy.buy(id)
		s.purchases.append({"id": id, "level": GameState.upgrade_level(id), "t": s.t, "catches": s.catches})


# --- Report -----------------------------------------------------------------------

func _pct(values: Array, p: float) -> float:
	if values.is_empty():
		return NAN
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(round(p * (sorted.size() - 1))), 0, sorted.size() - 1)]


func _fmt(value: float, digits := 1) -> String:
	return "—" if is_nan(value) else String.num(value, digits)


func _report(results: Array) -> String:
	var acc := "tiered 85/70/55 %" if tiered else "%d %%" % roundi(accuracy * 100)
	var lines: Array[String] = []
	var changes := "" if overrides.is_empty() else ", with " + ", ".join(PackedStringArray(overrides.map(func(o): return "`%s`" % o)))
	lines.append("## Simulation: %d × %d min, accuracy %s%s\n" % [runs, minutes, acc, changes])

	lines.append("| Purchase | Reached | Minute (P10 / median / P90) | Catches (median) |")
	lines.append("|---|---|---|---|")
	for u in GameData.upgrades():
		for level in range(1, u.levels.size() + 1):
			var times := []
			var catches := []
			for r in results:
				for p in r.purchases:
					if p.id == u.id and p.level == level:
						times.append(p.t / 60.0)
						catches.append(p.catches)
			var label := "%s L%d (%d)" % [u.id, level, u.levels[level - 1].cost]
			lines.append("| %s | %d %% | %s / %s / %s | %s |" % [label, roundi(100.0 * times.size() / results.size()),
				_fmt(_pct(times, 0.1)), _fmt(_pct(times, 0.5)), _fmt(_pct(times, 0.9)), _fmt(_pct(catches, 0.5), 0)])

	var total_cost := 0
	for u in GameData.upgrades():
		for lv in u.levels:
			total_cost += int(lv.cost)
	var all_done := []
	var catches := []
	var per_catch := []
	var sec_per_attempt := []
	var success := []
	var earned := []
	var trips := []
	var timeout_rare := [0, 0]
	var timeout_leg := [0, 0]
	var rarity_totals := {}
	for r in results:
		var bought: int = r.purchases.size()
		if bought == _level_count():
			all_done.append(r.purchases[-1].t / 60.0)
		catches.append(r.catches)
		earned.append(r.earned)
		trips.append(r.trips)
		per_catch.append(float(r.earned) / maxi(1, r.catches))
		sec_per_attempt.append(r.t / maxi(1, r.attempts))
		success.append(float(r.catches) / maxi(1, r.attempts))
		timeout_rare[0] += r.timed_timeouts.rare
		timeout_rare[1] += r.timed_attempts.rare
		timeout_leg[0] += r.timed_timeouts.legendary
		timeout_leg[1] += r.timed_attempts.legendary
		for k in r.rarity_catches:
			rarity_totals[k] = rarity_totals.get(k, 0) + r.rarity_catches[k]

	for zone in GameData.zones():
		if zone.unlock == null:
			continue
		var times := []
		var at_catches := []
		for r in results:
			for b in r.bosses:
				if b.zone == zone.unlock.boss_of:
					times.append(b.t / 60.0)
					at_catches.append(b.catches)
		lines.append("| **%s opens** (beat %s) | %d %% | %s / %s / %s | %s |" % [zone.id, GameData.zone(zone.unlock.boss_of).boss,
			roundi(100.0 * times.size() / results.size()), _fmt(_pct(times, 0.1)), _fmt(_pct(times, 0.5)),
			_fmt(_pct(times, 0.9)), _fmt(_pct(at_catches, 0.5), 0)])
	lines.append("")
	lines.append("| Metric | Median (P10–P90) |")
	lines.append("|---|---|")
	lines.append("| All %d levels bought (%d coins) | %d %% of runs; minute %s |" % [_level_count(), total_cost, roundi(100.0 * all_done.size() / results.size()), _fmt(_pct(all_done, 0.5))])
	lines.append("| Catches in %d min | %s (%s–%s) |" % [minutes, _fmt(_pct(catches, 0.5), 0), _fmt(_pct(catches, 0.1), 0), _fmt(_pct(catches, 0.9), 0)])
	lines.append("| Coins earned (sales + bonuses) | %s (%s–%s) |" % [_fmt(_pct(earned, 0.5), 0), _fmt(_pct(earned, 0.1), 0), _fmt(_pct(earned, 0.9), 0)])
	lines.append("| Coins per catch | %s |" % _fmt(_pct(per_catch, 0.5)))
	lines.append("| Seconds per cast (incl. misses, dock) | %s |" % _fmt(_pct(sec_per_attempt, 0.5)))
	lines.append("| Casts that end in a catch | %s %% |" % _fmt(100.0 * _pct(success, 0.5), 0))
	lines.append("| Trips (dock visits) | %s |" % _fmt(_pct(trips, 0.5), 0))
	var attempts := []
	for r in results:
		attempts.append(r.boss_attempts)
	lines.append("| Boss fights started | %s |" % _fmt(_pct(attempts, 0.5), 0))
	lines.append("| Timeouts: rare / legendary | %s %% / %s %% |" % [_fmt(100.0 * timeout_rare[0] / maxi(1, timeout_rare[1]), 0), _fmt(100.0 * timeout_leg[0] / maxi(1, timeout_leg[1]), 0)])
	var total_caught := 0
	for k in rarity_totals:
		total_caught += rarity_totals[k]
	var mix: Array[String] = []
	for k in ["common", "uncommon", "rare", "legendary"]:
		mix.append("%s %s %%" % [k, _fmt(100.0 * rarity_totals.get(k, 0) / maxi(1, total_caught), 1)])
	lines.append("| Catch mix | %s |" % ", ".join(mix))
	return "\n".join(lines) + "\n"


func _level_count() -> int:
	var n := 0
	for u in GameData.upgrades():
		n += u.levels.size()
	return n
