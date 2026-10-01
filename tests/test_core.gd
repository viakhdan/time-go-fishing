extends TestSuite
## Core loop tests (step 4): fish table, problem bank, catches, FishingLoop, Zone.


# --- FishTable --------------------------------------------------------------

func _rarity_shares(zone_id: String, n: int) -> Dictionary:
	var counts := {}
	for i in n:
		var r: String = GameData.fish(FishTable.roll(zone_id, rng)).rarity
		counts[r] = counts.get(r, 0) + 1
	for r in counts:
		counts[r] = counts[r] / float(n)
	return counts


func test_fish_table_weights() -> void:
	# Lake has no legendary: 60/28/10 renormalized over 98.
	var s := _rarity_shares("lake", 20000)
	check(absf(s.common - 60.0 / 98) < 0.015, "lake common share %.3f" % s.common)
	check(absf(s.uncommon - 28.0 / 98) < 0.015, "lake uncommon share %.3f" % s.uncommon)
	check(absf(s.rare - 10.0 / 98) < 0.01, "lake rare share %.3f" % s.rare)
	check("legendary" not in s, "lake rolled a legendary")
	# Two commons share the common weight rather than doubling it.
	var perch := 0
	for i in 10000:
		if FishTable.roll("lake", rng) == "zero_perch":
			perch += 1
	check(absf(perch / 10000.0 - 30.0 / 98) < 0.015, "zero_perch share %.3f" % (perch / 10000.0))


func test_bait_multiplier() -> void:
	GameState.upgrades.bait = 3  # ×3 on rare and legendary
	var w := FishTable.rarity_weights("river")
	check(w.rare == 30.0 and w.legendary == 6.0 and w.common == 60.0, "bait L3 weights %s" % w)
	var s := _rarity_shares("river", 20000)
	check(absf(s.rare - 30.0 / 124) < 0.015, "river rare share with bait %.3f" % s.rare)


func test_roll_size() -> void:
	for i in 500:
		var size := FishTable.roll_size("power_pike", rng)
		check(size >= 48 and size <= 112, "pike size %d outside 0.6–1.4 × 80" % size)


# --- ProblemBank ------------------------------------------------------------

func test_problem_bank_shuffle_bag() -> void:
	var seen := {}
	for i in 15:
		seen[ProblemBank.draw("linear_equations", 2).id] = true
	check(seen.size() == 15, "15 draws gave %d unique problems" % seen.size())
	# The refilled bag must not start with the problem just drawn.
	var last := ""
	for i in 300:
		var id: String = ProblemBank.draw("powers_like_terms", 3).id
		check(id != last, "same problem twice in a row: %s" % id)
		last = id


func test_problem_bank_exclude() -> void:
	var prev: String = ProblemBank.draw("linear_equations", 1).id
	for i in 100:
		var p := ProblemBank.draw("linear_equations", 1, prev)
		check(p.id != prev, "second chance repeated %s" % prev)
		prev = p.id


func test_problem_options_shuffle() -> void:
	var originals := {}
	for topic in ["linear_equations", "powers_like_terms"]:
		for p in JSON.parse_string(FileAccess.get_file_as_string("res://data/problems/%s.json" % topic)):
			originals[p.id] = p.options[int(p.answer_index)]
	var positions := {}
	for i in 400:
		var p := ProblemBank.draw("powers_like_terms", 1 + i % 3)
		check(p.options[p.answer_index] == originals[p.id], "%s: correct answer lost in shuffle" % p.id)
		check(p.options.size() == 4, "%s: option count" % p.id)
		positions[p.answer_index] = true
	check(positions.size() == 4, "answer only ever at positions %s" % [positions.keys()])


# --- Economy / GameState ----------------------------------------------------

func test_sell_price() -> void:
	check(Economy.sell_price("x_eel", 70) == 15, "avg-size uncommon should sell for 15")
	check(Economy.sell_price("power_pike", 120) == 60, "1.5× size pike should sell for 60")
	check(Economy.sell_price("zero_perch", 1) == 1, "minimum price is 1")


func test_hold_capacity() -> void:
	check(GameState.hold_capacity() == 6, "base hold is 6")
	GameState.upgrades.hold = 2
	check(GameState.hold_capacity() == 11, "hold L2 is 11")
	GameState.upgrades.line = 3  # disabled upgrade: always base value
	GameState.start_trip()
	check(GameState.trip_second_chances == 0, "disabled Strong line must give 0 second chances")


func test_record_catch() -> void:
	var r := GameState.record_catch("zero_perch", 25, 5)
	check(r.is_new and r.discovery_bonus == 10 and GameState.coins == 10, "first catch gives +10")
	r = GameState.record_catch("zero_perch", 30, 6)
	check(not r.is_new and r.new_record and r.discovery_bonus == 0, "second, bigger catch is a record")
	check(GameState.encyclopedia.zero_perch == {"count": 2, "best_cm": 30, "best_value": 6}, "encyclopedia entry")
	GameState.record_catch("square_carp", 30, 5)
	GameState.record_catch("mirror_bream", 40, 15)
	r = GameState.record_catch("power_pike", 80, 40)
	check(r.zone_complete_bonus == 50, "last lake species gives +50")
	check(GameState.coins == 40 + 50, "coins after 4 discoveries + completion: %d" % GameState.coins)
	check(GameState.hold.size() == 5, "all catches in the hold")
	r = GameState.record_catch("power_pike", 90, 45)
	check(r.zone_complete_bonus == 0, "completion bonus is one-time")


# --- FishingLoop ------------------------------------------------------------

func _new_loop() -> FishingLoop:
	var loop := FishingLoop.new()
	loop.rng.seed = rng.randi()
	add_child(loop)
	loop.set_process(false)  # tests drive time with advance()
	return loop


## Casts and advances to the problem. Optionally forces the bitten fish.
func _to_problem(loop: FishingLoop, force_fish := "") -> void:
	loop.cast()
	loop.advance(10.0)
	if force_fish:
		loop.fish_id = force_fish
	loop.advance(10.0)


func _wrong_index(loop: FishingLoop) -> int:
	return (loop.problem.answer_index + 1) % 4


func test_loop_happy_path() -> void:
	var loop := _new_loop()
	check(loop.state == FishingLoop.State.IDLE, "starts idle")
	loop.cast()
	check(loop.state == FishingLoop.State.WAITING, "cast → waiting")
	loop.advance(10.0)
	check(loop.state == FishingLoop.State.BITE, "wait → bite")
	loop.advance(10.0)
	check(loop.state == FishingLoop.State.PROBLEM, "bite → problem")
	var tier: int = GameData.rarity_of(loop.fish_id).tier
	check(loop.problem.tier == tier, "problem tier matches fish rarity")
	loop.submit_answer(loop.problem.answer_index)
	check(loop.state == FishingLoop.State.REEL, "correct → reel")
	loop.reel_result(false)
	check(loop.state == FishingLoop.State.REEL, "first reel miss gives a retry")
	loop.reel_result(true)
	check(loop.state == FishingLoop.State.CAUGHT, "reel hit → caught")
	check(GameState.hold.size() == 1 and GameState.hold[0].species == loop.fish_id, "fish in hold")
	loop.acknowledge()
	check(loop.state == FishingLoop.State.IDLE, "acknowledge → idle")
	loop.queue_free()


func test_loop_wrong_answer() -> void:
	var loop := _new_loop()
	var reasons := []
	loop.escaped.connect(func(reason, _p): reasons.append(reason))
	_to_problem(loop)
	loop.submit_answer(_wrong_index(loop))
	check(loop.state == FishingLoop.State.ESCAPED and reasons == [FishingLoop.Escape.WRONG], "wrong → escaped")
	check(GameState.hold.is_empty(), "escaped fish not in hold")
	loop.queue_free()


func test_loop_timer_and_rod() -> void:
	var loop := _new_loop()
	_to_problem(loop, "zero_perch")
	check(loop.time_limit == 0.0, "common fish has no timer")
	loop.advance(999.0)
	check(loop.state == FishingLoop.State.PROBLEM, "untimed problem never times out")
	loop.submit_answer(_wrong_index(loop))
	loop.acknowledge()

	GameState.upgrades.rod = 1
	_to_problem(loop, "power_pike")
	check(loop.time_limit == 55.0, "rare 45 s + rod L1 10 s = %s" % loop.time_limit)
	loop.advance(54.0)
	check(loop.state == FishingLoop.State.PROBLEM, "still time left")
	loop.advance(2.0)
	check(loop.state == FishingLoop.State.ESCAPED, "timeout → escaped")
	check(is_equal_approx(loop.reel_zone_fraction(), 0.2 * 1.15), "rod L1 widens reel zone 15%")
	loop.queue_free()


func test_loop_second_chance() -> void:
	var loop := _new_loop()
	var second := []
	loop.problem_started.connect(func(_p, _t, sc): second.append(sc))
	GameState.trip_second_chances = 1
	_to_problem(loop)
	var first_id: String = loop.problem.id
	loop.submit_answer(_wrong_index(loop))
	check(loop.state == FishingLoop.State.PROBLEM, "second chance keeps the fish on")
	check(loop.problem.id != first_id, "second chance draws a new problem")
	check(second == [false, true], "second_chance flag %s" % [second])
	check(GameState.trip_second_chances == 0, "charge used")
	loop.submit_answer(_wrong_index(loop))
	check(loop.state == FishingLoop.State.ESCAPED, "no charges left → escaped")
	loop.queue_free()


func test_loop_reel_escape() -> void:
	var loop := _new_loop()
	var reasons := []
	loop.escaped.connect(func(reason, _p): reasons.append(reason))
	_to_problem(loop)
	loop.submit_answer(loop.problem.answer_index)
	loop.reel_result(false)
	loop.reel_result(false)
	check(reasons == [FishingLoop.Escape.REEL], "two reel misses → escaped (reel)")
	loop.queue_free()


func test_loop_hold_full() -> void:
	var loop := _new_loop()
	for i in GameState.hold_capacity():
		GameState.hold.append({"species": "zero_perch", "size_cm": 25, "value": 5})
	check(not loop.can_cast(), "full hold blocks casting")
	loop.cast()
	check(loop.state == FishingLoop.State.IDLE, "cast ignored when full")
	loop.queue_free()


# --- Zone scene smoke test ----------------------------------------------------

func test_zone_scene() -> void:
	GameState.current_zone = "river"
	var zone: Control = load("res://scenes/Zone.tscn").instantiate()
	add_child(zone)
	await get_tree().process_frame
	var loop: FishingLoop = zone.loop
	loop.set_process(false)
	check(zone.cast_button.visible and not zone.modal.visible, "zone idle UI")
	check(tr(zone.zone_label.text) == tr("ZONE_RIVER"), "zone name")

	_to_problem(loop, "great_null")
	check(zone.modal.visible and zone.problem_panel.visible, "problem panel shown")
	check(zone.problem_panel.question_label.text == ProblemBank.text(loop.problem.question), "question text")
	check(zone.problem_panel.timer_label.visible, "legendary problem shows the timer")

	zone.problem_panel.answered.emit(loop.problem.answer_index)
	check(zone.reel.visible and not zone.problem_panel.visible, "reel shown after correct answer")
	zone.reel.finished.emit(true)
	check(zone.catch_card.visible, "catch card shown")
	check(zone.catch_card.name_label.text == tr("FISH_GREAT_NULL"), "catch card name")
	check(zone.hold_label.text.ends_with("1/6"), "HUD hold count: %s" % zone.hold_label.text)
	zone.catch_card.closed.emit()
	check(not zone.modal.visible and loop.state == FishingLoop.State.IDLE, "back to idle")

	_to_problem(loop)
	zone.problem_panel.answered.emit(_wrong_index(loop))
	check(zone.problem_panel.feedback.visible, "miss shows feedback")
	check(zone.problem_panel.solution_label.text.contains(ProblemBank.text(loop.problem.solution)), "miss shows the solution")

	GameState.set_locale("en")
	await get_tree().process_frame
	check(zone.problem_panel.question_label.text == loop.problem.question.en, "language switch updates the open problem")
	GameState.set_locale("uk")
	zone.queue_free()
