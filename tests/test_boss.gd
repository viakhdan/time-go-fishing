extends TestSuite
## Boss fights: availability, 3 hearts, 2 misses, reel, unlocks, UI.


func _catch_all_but_boss(zone_id: String) -> void:
	for id in GameData.zone(zone_id).fish:
		if not GameData.is_boss(id):
			GameState.record_catch(id, 30, 5)
	GameState.hold.clear()


func _new_loop(zone_id := "lake") -> FishingLoop:
	var loop := FishingLoop.new()
	loop.zone_id = zone_id
	loop.rng.seed = rng.randi()
	add_child(loop)
	loop.set_process(false)
	return loop


func _wrong(loop: FishingLoop) -> int:
	return (loop.problem.answer_index + 1) % 4


func test_boss_appears_after_nine_species() -> void:
	check(not GameData.is_boss_available("lake"), "no boss at the start")
	var ids: Array = GameData.zone("lake").fish.filter(func(id): return not GameData.is_boss(id))
	var r := {}
	for i in ids.size():
		r = GameState.record_catch(ids[i], 30, 5)
		if i < ids.size() - 1:
			check(not r.boss_appeared, "boss not yet after %d species" % (i + 1))
	check(r.boss_appeared and GameData.is_boss_available("lake"), "9th species makes the boss appear")
	r = GameState.record_catch(ids[0], 30, 5)
	check(not r.boss_appeared, "appears only once")


func test_boss_win() -> void:
	_catch_all_but_boss("lake")
	var loop := _new_loop()
	var updates := []
	loop.boss_updated.connect(func(h, m, hit): updates.append([h, m, hit]))
	check(loop.can_challenge_boss(), "boss can be challenged")
	loop.challenge_boss()
	check(loop.state == FishingLoop.State.PROBLEM and loop.fish_id == "great_polynomial", "fight starts with a problem")
	check(loop.problem.tier == 3 and loop.time_limit == 45.0, "tier-3 problem with the boss timer")
	var ids := {}
	for hit in 3:
		ids[loop.problem.id] = true
		loop.submit_answer(loop.problem.answer_index)
	check(ids.size() == 3, "each hit is a new problem")
	check(updates == [[3, 2, false], [2, 2, true], [1, 2, true], [0, 2, true]], "hearts count down: %s" % [updates])
	check(loop.state == FishingLoop.State.REEL, "third hit → reel")
	loop.reel_result(false)
	loop.reel_result(false)
	check(loop.state == FishingLoop.State.REEL, "boss gets 3 reel attempts")
	loop.reel_result(true)
	check(loop.state == FishingLoop.State.CAUGHT and not loop.boss_fight, "boss caught")
	check("lake" in GameState.bosses_defeated and GameData.is_zone_unlocked("river"), "river unlocked")
	check(GameState.hold.size() == 1 and GameState.hold[0].species == "great_polynomial", "boss goes into the hold")
	loop.queue_free()


func test_boss_escapes_after_two_misses() -> void:
	_catch_all_but_boss("lake")
	var loop := _new_loop()
	var missed := []
	var escaped := []
	loop.boss_missed.connect(func(reason, _p): missed.append(reason))
	loop.escaped.connect(func(reason, _p): escaped.append(reason))
	loop.challenge_boss()
	loop.submit_answer(loop.problem.answer_index)  # one hit
	var first_id: String = loop.problem.id
	loop.submit_answer(_wrong(loop))
	check(loop.state == FishingLoop.State.BOSS_MISS and missed.size() == 1, "first miss keeps the fight going")
	check(loop.boss_hearts == 2 and loop.boss_misses_left() == 1, "hearts kept, one miss left")
	loop.acknowledge()
	check(loop.state == FishingLoop.State.PROBLEM and loop.problem.id != first_id, "next problem after reading the solution")
	loop.advance(999.0)  # a timeout counts as a miss
	check(loop.state == FishingLoop.State.ESCAPED and escaped == [FishingLoop.Escape.TIMEOUT], "second miss: the boss escapes")
	check(not loop.boss_fight and GameState.bosses_defeated.is_empty(), "nothing unlocked")
	loop.acknowledge()
	check(loop.can_challenge_boss(), "can try again straight away")
	loop.queue_free()


func test_boss_needs_room_and_idle() -> void:
	_catch_all_but_boss("lake")
	var loop := _new_loop()
	for i in GameState.hold_capacity():
		GameState.hold.append({"species": "zero_perch", "size_cm": 25, "value": 5})
	check(not loop.can_challenge_boss(), "full hold blocks the boss")
	GameState.hold.clear()
	loop.cast()
	check(not loop.can_challenge_boss(), "no boss while a cast is out")
	loop.queue_free()
	var river := _new_loop("river")
	check(not river.can_challenge_boss(), "river boss needs the river species")
	river.queue_free()


func test_boss_ui() -> void:
	_catch_all_but_boss("lake")
	GameState.current_zone = "lake"
	var zone: Control = load("res://scenes/Zone.tscn").instantiate()
	add_child(zone)
	await get_tree().process_frame
	var loop: FishingLoop = zone.loop
	loop.set_process(false)
	check(zone.boss_button.visible, "boss button shown when the boss is available")
	zone.boss_button.pressed.emit()
	var panel = zone.problem_panel
	check(panel.visible and panel.boss_label.visible and panel.boss_label.text == "♥♥♥", "hearts shown: %s" % panel.boss_label.text)
	check(panel.rarity_label.text.contains(tr("UI_BOSS_FIGHT")), "header says boss fight")
	panel.answered.emit(loop.problem.answer_index)
	check(panel.boss_label.text == "♥♥♡" and panel.notice_label.text == tr("UI_BOSS_HIT"), "a hit is shown")
	panel.answered.emit(_wrong(loop))
	check(panel.feedback.visible and panel.notice_label.text.contains("1"), "miss shows the solution and misses left")
	panel.continue_pressed.emit()
	check(panel.answers.visible and zone.modal.visible, "fight continues")
	panel.answered.emit(loop.problem.answer_index)
	panel.answered.emit(loop.problem.answer_index)
	zone.reel.finished.emit(true)
	check(zone.catch_card.visible and zone.catch_card.bonus_label.text.contains(tr("ZONE_RIVER")), "catch card announces the river")
	zone.catch_card.closed.emit()
	check(not panel.boss_label.visible or panel._boss.is_empty(), "boss status cleared after the fight")
	check(not zone.boss_button.visible or GameState.is_hold_full() or loop.can_challenge_boss(), "boss button follows availability")
	zone.queue_free()
