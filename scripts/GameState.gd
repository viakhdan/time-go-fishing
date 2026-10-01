extends Node
## Autoload: persistent player state (DESIGN.md §12). Everything that must
## survive a restart lives here and is written to user://save.json.

signal coins_changed(coins: int)
signal hold_changed
signal upgrades_changed
signal locale_changed(locale: String)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
const LOCALES: Array[String] = ["uk", "en"]

var locale := "uk"
var coins := 0
## Each entry: { "species": String, "size_cm": int, "value": int }
var hold: Array[Dictionary] = []
var upgrades := _default_upgrades()
## species id -> { "count": int, "best_cm": int, "best_value": int }
var encyclopedia := {}
var zone_complete_rewarded: Array[String] = []
var trophy = null


func _ready() -> void:
	load_game()
	TranslationServer.set_locale(locale)


func set_locale(new_locale: String) -> void:
	if new_locale not in LOCALES or new_locale == locale:
		return
	locale = new_locale
	TranslationServer.set_locale(locale)
	locale_changed.emit(locale)
	save_game()


func upgrade_level(id: String) -> int:
	return upgrades.get(id, 0)


func reset() -> void:
	coins = 0
	hold.clear()
	upgrades = _default_upgrades()
	encyclopedia.clear()
	zone_complete_rewarded.clear()
	trophy = null
	save_game()
	coins_changed.emit(coins)
	hold_changed.emit()
	upgrades_changed.emit()


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"locale": locale,
		"coins": coins,
		"hold": hold,
		"upgrades": upgrades,
		"encyclopedia": encyclopedia,
		"zone_complete_rewarded": zone_complete_rewarded,
		"trophy": trophy,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Save file is corrupt, starting fresh.")
		return
	# JSON numbers load as floats, so cast everything back to int.
	locale = data.get("locale", "uk") if data.get("locale") in LOCALES else "uk"
	coins = int(data.get("coins", 0))
	hold.clear()
	for fish in data.get("hold", []):
		hold.append({
			"species": str(fish.species),
			"size_cm": int(fish.size_cm),
			"value": int(fish.value),
		})
	for id in data.get("upgrades", {}):
		upgrades[id] = int(data.upgrades[id])
	encyclopedia.clear()
	for id in data.get("encyclopedia", {}):
		var entry: Dictionary = data.encyclopedia[id]
		encyclopedia[id] = {
			"count": int(entry.get("count", 0)),
			"best_cm": int(entry.get("best_cm", 0)),
			"best_value": int(entry.get("best_value", 0)),
		}
	zone_complete_rewarded.assign(data.get("zone_complete_rewarded", []))
	trophy = data.get("trophy")


static func _default_upgrades() -> Dictionary:
	return {"hold": 0, "rod": 0, "bait": 0, "boat": 0, "line": 0, "lantern": 0}
