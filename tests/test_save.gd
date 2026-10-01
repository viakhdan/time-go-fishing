extends TestSuite
## Step 7 tests: save/load (§12), corrupt-save recovery, stale-data cleanup,
## zone completion badge (§8.2) and resetting progress.


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _set_up_progress() -> void:
	GameState.coins = 123
	GameState.hold.assign([{"species": "x_eel", "size_cm": 84, "value": 18}, {"species": "zero_perch", "size_cm": 20, "value": 4}])
	GameState.upgrades.rod = 2
	GameState.upgrades.boat = 1
	GameState.encyclopedia["x_eel"] = {"count": 3, "best_cm": 84, "best_value": 19}
	GameState.zone_complete_rewarded.assign(["lake"])
	GameState.set_locale("en")
	GameState.save_game()


func test_round_trip() -> void:
	_set_up_progress()
	check(not FileAccess.file_exists(GameState.save_path + ".tmp"), "no temp file left behind")
	# Scramble memory, then load.
	GameState.coins = 0
	GameState.hold.clear()
	GameState.upgrades.rod = 0
	GameState.encyclopedia.clear()
	GameState.zone_complete_rewarded.clear()
	GameState.locale = "uk"
	GameState.load_game()
	check(GameState.coins == 123, "coins")
	check(GameState.hold == [{"species": "x_eel", "size_cm": 84, "value": 18}, {"species": "zero_perch", "size_cm": 20, "value": 4}], "hold (ints, order)")
	check(GameState.upgrades.rod == 2 and GameState.upgrades.boat == 1, "upgrades")
	check(GameState.encyclopedia.x_eel == {"count": 3, "best_cm": 84, "best_value": 19}, "encyclopedia")
	check(GameState.zone_complete_rewarded == ["lake"], "completion rewards")
	check(GameState.locale == "en", "language")
	check(typeof(GameState.coins) == TYPE_INT and typeof(GameState.hold[0].size_cm) == TYPE_INT, "numbers load as ints")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.save_path))
	check(int(saved.version) == 2, "save version 2 (§12)")
	GameState.set_locale("uk")


func test_corrupt_save_uses_backup() -> void:
	_set_up_progress()
	GameState.load_game()  # a good load refreshes the backup
	check(FileAccess.file_exists(GameState.save_path + ".bak"), "backup written after a good load")
	_write(GameState.save_path, "{ this is not json")
	GameState.coins = 0
	GameState.load_game()
	check(GameState.coins == 123 and GameState.upgrades.rod == 2, "corrupt save falls back to the backup")
	_write(GameState.save_path + ".bak", "also broken")
	_write(GameState.save_path, "")
	GameState.coins = 7
	GameState.load_game()
	check(GameState.coins == 7, "both broken: keeps the fresh state instead of crashing")
	GameState.set_locale("uk")


func test_stale_data_is_dropped() -> void:
	_write(GameState.save_path, JSON.stringify({
		"version": 2, "locale": "fr", "coins": -50,
		"hold": [{"species": "old_fish", "size_cm": 10, "value": 3}, {"species": "x_eel", "size_cm": 70, "value": 15}, "garbage"],
		"upgrades": {"hold": 9, "rod": 1, "jetpack": 2},
		"encyclopedia": {"old_fish": {"count": 1}, "x_eel": {"count": 2, "best_cm": 70, "best_value": 15}},
		"zone_complete_rewarded": ["lake", "atlantis"],
	}))
	GameState.load_game()
	check(GameState.locale == "uk", "unknown language falls back to Ukrainian")
	check(GameState.coins == 0, "negative coins clamped")
	check(GameState.hold.size() == 1 and GameState.hold[0].species == "x_eel", "unknown fish dropped from the hold")
	check(GameState.upgrades.hold == 3, "upgrade level clamped to max")
	check(GameState.upgrades.rod == 1 and "jetpack" not in GameState.upgrades, "unknown upgrade ignored")
	check(GameState.encyclopedia.keys() == ["x_eel"], "unknown species dropped from the encyclopedia")
	check(GameState.zone_complete_rewarded == ["lake"], "unknown zone dropped")


func test_saving_can_be_disabled() -> void:
	GameState.coins = 5
	GameState.save_game()
	GameState.saving_enabled = false
	GameState.coins = 999
	GameState.save_game()
	GameState.saving_enabled = true
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.save_path))
	check(int(saved.coins) == 5, "disabled saving leaves the file alone")


func test_autosave_after_catch_sale_purchase() -> void:
	var saved_coins := func() -> int:
		return int(JSON.parse_string(FileAccess.get_file_as_string(GameState.save_path)).coins)
	GameState.record_catch("zero_perch", 25, 5)
	check(saved_coins.call() == 10, "catch saved (discovery bonus)")
	Economy.sell(0)
	check(saved_coins.call() == 15, "sale saved")
	GameState.coins = 50
	Economy.buy("hold")
	check(saved_coins.call() == 10, "purchase saved")


func test_map_badge() -> void:
	GameState.zone_complete_rewarded.assign(["lake"])
	var map: Control = load("res://scenes/Map.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	check(map._cards.lake.badge.visible and map._cards.lake.badge_label.visible, "completed zone has a badge")
	check(not map._cards.river.badge.visible, "other zones don't")
	map.queue_free()


func test_completion_through_play() -> void:
	for id in ["zero_perch", "square_carp", "mirror_bream"]:
		GameState.record_catch(id, 30, 5)
	check("lake" not in GameState.zone_complete_rewarded, "not complete with 3 of 4")
	var r := GameState.record_catch("power_pike", 80, 40)
	check(r.zone_complete_bonus == 50 and "lake" in GameState.zone_complete_rewarded, "4th species completes the lake")


func test_reset_from_menu() -> void:
	_set_up_progress()
	GameState.set_locale("uk")
	var main: Control = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.reset_button.pressed.emit()
	check(main.reset_dialog.visible and main.reset_dialog.dialog_text == tr("UI_RESET_CONFIRM"), "reset asks first")
	main.reset_dialog.hide()
	check(GameState.coins == 123, "closing the dialog changes nothing")
	main.reset_dialog.confirmed.emit()
	check(GameState.coins == 0 and GameState.hold.is_empty() and GameState.encyclopedia.is_empty(), "confirmed reset wipes progress")
	check(GameState.upgrade_level("rod") == 0 and GameState.zone_complete_rewarded.is_empty(), "upgrades and badges reset")
	check(GameState.locale == "uk", "language is kept")
	main.queue_free()
