extends Node
## Autoload: persistent player state (DESIGN.md §12). Everything that must
## survive a restart lives here and is written to user://save.json.

signal coins_changed(coins: int)
signal hold_changed
signal upgrades_changed
signal locale_changed(locale: String)

const SAVE_VERSION := 2
const LOCALES: Array[String] = ["uk", "en"]

## Tests point this elsewhere so they never touch the player's save.
var save_path := "user://save.json"

var locale := "uk"
var coins := 0
## Each entry: { "species": String, "size_cm": int, "value": int }
var hold: Array[Dictionary] = []
var upgrades := _default_upgrades()
## species id -> { "count": int, "best_cm": int, "best_value": int }
var encyclopedia := {}
var zone_complete_rewarded: Array[String] = []
var trophy = null
## Strong-line second chances left this trip (§5.2). Refilled by start_trip().
var trip_second_chances := 0

## Zone the player is fishing in. Not saved: a restart begins at the menu.
var current_zone := "lake"
## Where the Encyclopedia's Back button goes. Not saved.
var return_scene := "res://scenes/Main.tscn"


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


func hold_capacity() -> int:
	return int(GameData.upgrade_effect("hold", "slots"))


func is_hold_full() -> bool:
	return hold.size() >= hold_capacity()


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


## Removes a fish from the hold (sold or released). Caller saves.
func remove_fish(index: int) -> Dictionary:
	var fish: Dictionary = hold.pop_at(index)
	hold_changed.emit()
	return fish


## Releasing gives no coins (§4).
func release_fish(index: int) -> void:
	remove_fish(index)
	save_game()


func set_upgrade_level(id: String, level: int) -> void:
	upgrades[id] = level
	upgrades_changed.emit()
	# A bigger hold changes the slot count shown everywhere.
	hold_changed.emit()


## Called when a trip starts at the dock.
func start_trip() -> void:
	trip_second_chances = int(GameData.upgrade_effect("line", "second_chances"))
	save_game()


## Stores a caught fish in the hold and updates the encyclopedia, discovery
## bonus and zone completion reward (§3.1, §8.2). Saves.
func record_catch(species: String, size_cm: int, value: int) -> Dictionary:
	hold.append({"species": species, "size_cm": size_cm, "value": value})

	var is_new := species not in encyclopedia
	var entry: Dictionary = encyclopedia.get_or_add(species, {"count": 0, "best_cm": 0, "best_value": 0})
	var new_record: bool = not is_new and size_cm > entry.best_cm
	entry.count += 1
	entry.best_cm = maxi(entry.best_cm, size_cm)
	entry.best_value = maxi(entry.best_value, value)

	var discovery := GameData.discovery_bonus if is_new else 0
	var zone_bonus := 0
	var zone_id: String = GameData.fish(species).zone
	if is_new and zone_id not in zone_complete_rewarded \
			and GameData.zone(zone_id).fish.all(func(id): return id in encyclopedia):
		zone_complete_rewarded.append(zone_id)
		zone_bonus = GameData.zone_complete_bonus

	hold_changed.emit()
	if discovery + zone_bonus > 0:
		add_coins(discovery + zone_bonus)
	save_game()
	return {
		"species": species, "size_cm": size_cm, "value": value,
		"is_new": is_new, "new_record": new_record,
		"discovery_bonus": discovery, "zone_complete_bonus": zone_bonus,
	}


func reset() -> void:
	coins = 0
	hold.clear()
	upgrades = _default_upgrades()
	encyclopedia.clear()
	zone_complete_rewarded.clear()
	trophy = null
	trip_second_chances = 0
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
		"trip_second_chances": trip_second_chances,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
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
	trip_second_chances = int(data.get("trip_second_chances", 0))


static func _default_upgrades() -> Dictionary:
	return {"hold": 0, "rod": 0, "bait": 0, "boat": 0, "line": 0, "lantern": 0}
