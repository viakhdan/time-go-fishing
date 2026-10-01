extends Node
## Saves PNGs of the zone scene in each loop state, for visual review.
## Needs a real window (not --headless):
##   Godot_console.exe --path . res://tests/Screenshots.tscn -- --out=C:/some/dir
## Uses its own save file and seeds, so shots are repeatable.

var _out := "user://screenshots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	GameState.save_path = "user://screenshot_save.json"
	GameState.reset()
	GameState.coins = 120
	ProblemBank.rng.seed = 7

	for locale in ["uk", "en"]:
		GameState.set_locale(locale)
		await _shoot_zone(locale)
		await _shoot_meta(locale)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	get_tree().quit()


func _shoot_zone(locale: String) -> void:
	GameState.hold.clear()
	GameState.current_zone = "lake"
	var zone: Control = load("res://scenes/Zone.tscn").instantiate()
	add_child(zone)
	var loop: FishingLoop = zone.loop
	loop.set_process(false)
	loop.rng.seed = 3
	await _save("%s_1_idle" % locale)

	loop.cast()
	await _save("%s_2_waiting" % locale)

	loop.advance(10.0)
	loop.fish_id = "power_pike"
	loop.advance(10.0)
	await _save("%s_3_problem" % locale)

	loop.submit_answer(loop.problem.answer_index)
	loop.advance(0.0)
	await _save("%s_4_reel" % locale)

	zone.reel.finished.emit(true)
	await _save("%s_5_catch" % locale)
	loop.acknowledge()

	loop.cast()
	loop.advance(10.0)
	loop.fish_id = "mirror_bream"
	loop.advance(10.0)
	loop.submit_answer((loop.problem.answer_index + 1) % 4)
	await _save("%s_6_miss" % locale)
	zone.queue_free()
	await get_tree().process_frame


## Full hold + release, Map, Dock market and workshop (step 5).
func _shoot_meta(locale: String) -> void:
	GameState.coins = 85
	GameState.upgrades.rod = 1
	GameState.hold.clear()
	for f in [["zero_perch", 31, 6], ["square_carp", 22, 4], ["mirror_bream", 52, 20],
			["zero_perch", 18, 4], ["power_pike", 94, 47], ["square_carp", 35, 6]]:
		GameState.hold.append({"species": f[0], "size_cm": f[1], "value": f[2]})

	var zone: Control = load("res://scenes/Zone.tscn").instantiate()
	add_child(zone)
	zone.loop.set_process(false)
	await _save("%s_7_hold_full" % locale)
	zone.release_button.pressed.emit()
	zone.hold_panel.get_child(1).button_pressed = true
	await _save("%s_8_release" % locale)
	zone.queue_free()

	var map: Control = load("res://scenes/Map.tscn").instantiate()
	add_child(map)
	await _save("%s_9_map" % locale)
	map.queue_free()

	var dock: Control = load("res://scenes/Dock.tscn").instantiate()
	add_child(dock)
	await get_tree().process_frame
	dock.hold_panel.get_child(4).button_pressed = true
	await _save("%s_10_market" % locale)
	dock.tabs.current_tab = 1
	await _save("%s_11_workshop" % locale)
	dock.queue_free()
	await get_tree().process_frame


func _save(name: String) -> void:
	# Two frames so containers finish laying out before the capture.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
