extends Node
## Headless test runner. Run:
##   Godot_console.exe --headless --path . res://tests/TestRunner.tscn
## Exits with code 1 if anything fails. Uses its own save file.

const SUITES := [
	preload("res://tests/test_core.gd"),
	preload("res://tests/test_economy.gd"),
]


func _ready() -> void:
	GameState.save_path = "user://test_save.json"
	ProblemBank.rng.seed = 12345
	var failures: Array[String] = []
	var checks := 0
	for script in SUITES:
		var suite: TestSuite = script.new()
		add_child(suite)
		await suite.run()
		failures.append_array(suite.failures)
		checks += suite.checks
		suite.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	for f in failures:
		print("  FAIL ", f)
	print("%d checks, %d failed" % [checks, failures.size()])
	get_tree().quit(1 if failures else 0)
