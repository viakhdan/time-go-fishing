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


func _save(name: String) -> void:
	# Two frames so containers finish laying out before the capture.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
