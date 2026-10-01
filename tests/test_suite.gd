class_name TestSuite
extends Node
## Base for test suites: every method named test_* runs with a fresh GameState.

var failures: Array[String] = []
var checks := 0
var rng := RandomNumberGenerator.new()


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [get_script().resource_path.get_file(), what])


func run() -> void:
	rng.seed = 12345
	for method in get_method_list():
		if method.name.begins_with("test_"):
			GameState.reset()
			await call(method.name)
