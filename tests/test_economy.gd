extends TestSuite
## Step 5 tests: selling, upgrades, zone unlock, releasing, Dock / Map / Zone UI.


func _fill_hold(fish: Array) -> void:
	for f in fish:
		GameState.hold.append({"species": f[0], "size_cm": f[1], "value": f[2]})
	GameState.hold_changed.emit()


# --- Economy ------------------------------------------------------------------

func test_sell_one() -> void:
	_fill_hold([["zero_perch", 25, 5], ["power_pike", 80, 40]])
	GameState.encyclopedia["power_pike"] = {"count": 1, "best_cm": 80, "best_value": 40}
	check(Economy.hold_value() == 45, "hold value")
	check(Economy.sell(1) == 40, "sell returns value")
	check(GameState.coins == 40 and GameState.hold.size() == 1, "coins up, fish gone")
	check(GameState.hold[0].species == "zero_perch", "the right fish was sold")
	check("power_pike" in GameState.encyclopedia, "selling never removes the encyclopedia entry")


func test_sell_all() -> void:
	_fill_hold([["zero_perch", 25, 5], ["x_eel", 84, 18], ["fog_catfish", 52, 4]])
	check(Economy.sell_all() == 27, "sell all total")
	check(GameState.coins == 27 and GameState.hold.is_empty(), "hold emptied")
	check(Economy.sell_all() == 0, "selling an empty hold gives 0")


func test_release_gives_nothing() -> void:
	_fill_hold([["power_pike", 80, 40]])
	GameState.release_fish(0)
	check(GameState.hold.is_empty() and GameState.coins == 0, "release frees the slot with no coins")


func test_buy_upgrades() -> void:
	GameState.coins = 30
	check(not Economy.can_buy("hold") and Economy.missing_coins("hold") == 10, "hold L1 needs 10 more")
	check(not Economy.buy("hold") and GameState.coins == 30, "failed purchase changes nothing")
	GameState.coins = 45
	check(Economy.buy("hold"), "buy hold L1")
	check(GameState.coins == 5 and GameState.upgrade_level("hold") == 1, "coins spent, level up")
	check(GameState.hold_capacity() == 8, "hold L1 has 8 slots")
	check(Economy.next_cost("hold") == 100, "next hold level costs 100")
	GameState.coins = 10000
	check(Economy.buy("hold") and Economy.buy("hold"), "buy hold L2, L3")
	check(GameState.hold_capacity() == 15 and Economy.is_max_level("hold"), "hold maxed at 15")
	check(not Economy.buy("hold") and Economy.next_cost("hold") == -1, "can't buy past max")
	check(Economy.missing_coins("hold") == 0, "maxed upgrade needs nothing")


func test_disabled_upgrades_cannot_be_bought() -> void:
	GameState.coins = 10000
	check(not Economy.buy("line") and not Economy.buy("lantern"), "stretch upgrades are off")
	check(GameData.upgrades().map(func(u): return u.id) == ["boat", "hold", "rod", "bait"], "workshop lists MVP upgrades, boat first")


func test_boat_unlocks_river() -> void:
	check(GameData.is_zone_unlocked("lake") and not GameData.is_zone_unlocked("river"), "river starts locked")
	GameState.coins = 79
	check(not Economy.buy("boat"), "boat costs 80")
	GameState.coins = 80
	check(Economy.buy("boat"), "buy the boat")
	check(GameData.is_zone_unlocked("river"), "boat unlocks the river")
	check(not GameData.is_zone_unlocked("bay"), "bay stays off (stretch)")
	check(GameData.zones().size() == 2, "only enabled zones are listed")


func test_all_upgrades_cost() -> void:
	var total := 0
	for u in GameData.upgrades():
		while not Economy.is_max_level(u.id):
			total += Economy.next_cost(u.id)
			GameState.coins = Economy.next_cost(u.id)
			Economy.buy(u.id)
	check(total == 1350, "all MVP upgrades cost %d, design says 1350" % total)


# --- Upgrade effect text (§5.2 "before → after") --------------------------------

func test_effect_lines() -> void:
	GameState.set_locale("uk")
	check(UIText.upgrade_effects("hold", 0, 1) == ["Місць: 6 → 8"], "hold uk %s" % [UIText.upgrade_effects("hold", 0, 1)])
	check(UIText.upgrade_effects("rod", 0, 1) == ["Таймер: 45 с → 55 с", "Зелена зона: +0% → +15%"], "rod uk %s" % [UIText.upgrade_effects("rod", 0, 1)])
	check(UIText.upgrade_effects("bait", 0, 1) == ["Рідкісні: ×1 → ×1,5"], "bait uk uses a decimal comma")
	check(UIText.upgrade_effects("boat", 0, 1) == ["Відкриває: Туманна річка"], "boat uk %s" % [UIText.upgrade_effects("boat", 0, 1)])
	GameState.set_locale("en")
	check(UIText.upgrade_effects("bait", 1, 2) == ["Rare: ×1.5 → ×2"], "bait en %s" % [UIText.upgrade_effects("bait", 1, 2)])
	check(UIText.upgrade_effects("hold", 2, 3) == ["Slots: 11 → 15"], "hold en L2→L3")
	GameState.set_locale("uk")


# --- Scenes ---------------------------------------------------------------------

func _pick_slot(hold_panel: Node, index: int) -> void:
	var slot: Button = hold_panel.get_child(index)
	slot.button_pressed = true


func test_dock_market() -> void:
	_fill_hold([["zero_perch", 25, 5], ["power_pike", 80, 40]])
	var dock: Control = load("res://scenes/Dock.tscn").instantiate()
	add_child(dock)
	await get_tree().process_frame
	check(dock.hold_panel.get_child_count() == 6, "6 slots shown")
	check(dock.sell_button.disabled, "sell needs a selection")
	check(dock.sell_all_button.text.contains("45"), "sell all shows the total: %s" % dock.sell_all_button.text)
	_pick_slot(dock.hold_panel, 1)
	check(not dock.sell_button.disabled and dock.sell_button.text.contains("40"), "sell shows the fish price")
	dock.sell_button.pressed.emit()
	check(GameState.coins == 40 and GameState.hold.size() == 1, "sold through the Market")
	check(dock.coins_label.amount_label.text == "40", "coins label updated")
	dock.sell_all_button.pressed.emit()
	check(GameState.hold.is_empty() and dock.sell_all_button.disabled, "sell all empties the hold")
	check(dock.market_info.text == tr("UI_HOLD_EMPTY"), "empty hold message")
	dock.queue_free()


func test_dock_workshop() -> void:
	GameState.coins = 20
	var dock: Control = load("res://scenes/Dock.tscn").instantiate()
	add_child(dock)
	await get_tree().process_frame
	var hold_row: Dictionary = dock._rows["hold"]
	check(hold_row.buy.disabled and hold_row.missing.text.contains("20"), "unaffordable: greyed with missing amount")
	GameState.add_coins(30)
	check(not hold_row.buy.disabled and hold_row.missing.text == "", "affordable after earning coins")
	hold_row.buy.pressed.emit()
	check(GameState.upgrade_level("hold") == 1 and GameState.coins == 10, "bought through the Workshop")
	check(hold_row.level.text.contains("1 → 2") and hold_row.effects.text.contains("8 → 11"), "row shows next level")
	check(dock.hold_panel.get_child_count() == 8, "market hold grew to 8 slots")
	check(dock._rows.size() == 4, "4 upgrade rows")
	dock.queue_free()


func test_map_locks() -> void:
	var map: Control = load("res://scenes/Map.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	check(not map._cards.lake.button.disabled, "lake open")
	check(map._cards.river.button.disabled and map._cards.river.button.text.contains(tr("UPG_BOAT")), "river names the boat")
	map.queue_free()
	GameState.upgrades.boat = 1
	map = load("res://scenes/Map.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	check(not map._cards.river.button.disabled, "river open with the boat")
	map.queue_free()


func test_zone_release_flow() -> void:
	GameState.current_zone = "lake"
	_fill_hold([["zero_perch", 25, 5], ["zero_perch", 20, 4], ["square_carp", 30, 5],
		["mirror_bream", 40, 15], ["zero_perch", 22, 4], ["power_pike", 80, 40]])
	var zone: Control = load("res://scenes/Zone.tscn").instantiate()
	add_child(zone)
	await get_tree().process_frame
	zone.loop.set_process(false)
	check(not zone.cast_button.visible and zone.hold_full_box.visible, "hold full offers return / release")
	zone.release_button.pressed.emit()
	check(zone.release_box.visible and zone.confirm_release_button.disabled, "release mode waits for a pick")
	_pick_slot(zone.hold_panel, 3)
	check(not zone.confirm_release_button.disabled, "pick enables release")
	zone.confirm_release_button.pressed.emit()
	check(GameState.hold.size() == 5 and GameState.coins == 0, "one fish released, no coins")
	check(GameState.hold.all(func(f): return f.species != "mirror_bream"), "the picked fish was released")
	check(zone.cast_button.visible and not zone.release_box.visible, "can cast again")
	check(zone.hold_label.text.ends_with("5/6"), "HUD updated: %s" % zone.hold_label.text)
	zone.queue_free()
