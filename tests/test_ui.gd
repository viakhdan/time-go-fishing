extends TestSuite
## Step 6 tests: theme, shared components, Encyclopedia, HUD.


func _open(path: String) -> Control:
	var scene: Control = load(path).instantiate()
	add_child(scene)
	return scene


func test_theme_variations() -> void:
	var theme: Theme = load("res://art/ui/theme.tres")
	for v in ["PrimaryButton", "AnswerButton", "HoldSlot", "PaperTile", "IconButton"]:
		check(theme.get_type_variation_base(v) == &"Button", "%s is a Button variation" % v)
	for v in ["ModalPanel", "Card", "HudBar", "PaperPanel", "PaperInset"]:
		check(theme.get_type_variation_base(v) == &"PanelContainer", "%s is a PanelContainer variation" % v)
	check(theme.get_color("font_color", "PaperLabel") == Palette.WOOD_DARK, "paper labels use dark ink")
	check(ProjectSettings.get_setting("gui/theme/custom") == "res://art/ui/theme.tres", "theme is the project default")


func test_coin_text() -> void:
	GameState.set_locale("en")
	var text := UIText.rich("UI_NEED_MORE", {"n": 30})
	check(text.begins_with("Need 30 more [img=") and text.contains(UIText.COIN_PATH), "{coin} becomes the icon: %s" % text)
	check(not text.contains("{coin}") and not text.contains("🪙"), "no placeholder or emoji left")
	check(UIText.coins(47, 20) == "47 [img=20x20]%s[/img]" % UIText.COIN_PATH, "coins() BBCode")
	GameState.set_locale("uk")


func test_fish_picture_all_species() -> void:
	for id in GameData._fish:
		var pic := FishPicture.new()
		pic.size = Vector2(200, 100)
		add_child(pic)
		pic.setup(id, id != "great_null")
		check(pic.fish_id == id, "picture set up for %s" % id)
		pic.queue_free()
	await get_tree().process_frame


func test_lang_toggle() -> void:
	var main := _open("res://scenes/Main.tscn")
	var toggle: LangToggle = main.get_node("Center/Menu/LangToggle")
	check(toggle._buttons.uk.button_pressed, "UA pressed by default")
	toggle._buttons.en.pressed.emit()
	check(GameState.locale == "en" and toggle._buttons.en.button_pressed, "EN switches the language")
	toggle._buttons.uk.pressed.emit()
	check(GameState.locale == "uk", "back to UA")
	main.queue_free()


func test_encyclopedia_empty() -> void:
	var enc := _open("res://scenes/Encyclopedia.tscn")
	await get_tree().process_frame
	check(enc.discovered_label.text.ends_with("0 / 30"), "0 / 30 discovered: %s" % enc.discovered_label.text)
	check(enc._tiles.size() == 30, "30 species listed")
	check(enc.selected == "zero_perch", "first fish selected")
	check(enc.name_label.text == tr("UI_UNKNOWN") and enc.locked_label.visible and not enc.known_box.visible, "uncaught fish is ???")
	check(not enc._tiles.zero_perch.picture.known, "tile shows a silhouette")
	enc.queue_free()


func test_encyclopedia_entry() -> void:
	GameState.encyclopedia["x_eel"] = {"count": 3, "best_cm": 84, "best_value": 19}
	var enc := _open("res://scenes/Encyclopedia.tscn")
	await get_tree().process_frame
	check(enc.selected == "x_eel", "opens on the first caught fish")
	check(enc.discovered_label.text.ends_with("1 / 30"), "1 / 30 discovered")
	check(enc.name_label.text == tr("FISH_X_EEL") and enc.known_box.visible, "caught fish page")
	check(enc.records.text.contains("[b]3[/b]") and enc.records.text.contains("84"), "records: %s" % enc.records.text)
	check(enc.flavor_label.text == "«%s»" % tr("FISH_X_EEL_FLAVOR"), "Ukrainian quotes around flavour")
	check(enc.fact_label.text == tr("FISH_X_EEL_FACT"), "math fact")
	check(enc.deep_label.text.contains("3/5"), "deeper fact locked at 3/5: %s" % enc.deep_label.text)
	check(not enc.try_answer.visible, "try-it answer hidden")
	enc.show_answer_button.pressed.emit()
	check(enc.try_answer.visible and enc.try_answer.text == tr("FISH_X_EEL_TRY_A"), "answer revealed on tap")

	GameState.encyclopedia.x_eel.count = 5
	enc.select("x_eel")
	check(enc.deep_label.text == tr("FISH_X_EEL_DEEP"), "deeper fact unlocked at 5")
	check(not enc.try_answer.visible, "answer hidden again after reselecting")

	enc._tiles.great_null.tile.pressed.emit()
	check(enc.selected == "great_null" and not enc.known_box.visible, "tile click selects an uncaught fish")
	var pressed: Array = enc._tiles.keys().filter(func(id): return enc._tiles[id].tile.button_pressed)
	check(pressed == ["great_null"], "exactly one tile highlighted: %s" % [pressed])

	GameState.set_locale("en")
	enc.select("x_eel")
	check(enc.flavor_label.text == "“%s”" % tr("FISH_X_EEL_FLAVOR"), "English quotes")
	GameState.set_locale("uk")
	enc.queue_free()


func test_zone_hud_rig() -> void:
	GameState.current_zone = "lake"
	var zone := _open("res://scenes/Zone.tscn")
	await get_tree().process_frame
	zone.loop.set_process(false)
	check(zone._rig_labels.rod.text == "%s 0" % tr("UI_LEVEL"), "rod level shown: %s" % zone._rig_labels.rod.text)
	GameState.set_upgrade_level("rod", 2)
	check(zone._rig_labels.rod.text.ends_with("2"), "rig level updates after an upgrade")
	check(zone.hold_label.text == "0/6", "hold count")
	zone.loop.cast()
	check(zone.encyclopedia_button.disabled, "no leaving mid-catch")
	zone.queue_free()
