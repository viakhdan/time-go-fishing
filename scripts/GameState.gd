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
## The economy simulation turns this off; the game always saves.
var saving_enabled := true

var locale := "uk"
var coins := 0
## Each entry: { "species": String, "size_cm": int, "value": int }
var hold: Array[Dictionary] = []
var upgrades := _default_upgrades()
## species id -> { "count": int, "best_cm": int, "best_value": int }
var encyclopedia := {}
var zone_complete_rewarded: Array[String] = []
## Zone ids whose boss has been beaten; each one opens the next zone.
var bosses_defeated: Array[String] = []
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

	var zone_id: String = GameData.fish(species).zone
	var boss_was_available := GameData.is_boss_available(zone_id)
	var is_new := species not in encyclopedia
	var entry: Dictionary = encyclopedia.get_or_add(species, {"count": 0, "best_cm": 0, "best_value": 0})
	var new_record: bool = not is_new and size_cm > entry.best_cm
	entry.count += 1
	entry.best_cm = maxi(entry.best_cm, size_cm)
	entry.best_value = maxi(entry.best_value, value)

	var discovery := GameData.discovery_bonus if is_new else 0
	var zone_bonus := 0
	if is_new and zone_id not in zone_complete_rewarded \
			and GameData.zone(zone_id).fish.all(func(id): return id in encyclopedia):
		zone_complete_rewarded.append(zone_id)
		zone_bonus = GameData.zone_complete_bonus

	# Boss: the first win opens the next zone; the 9th species makes the boss appear.
	var boss_defeated := GameData.is_boss(species) and zone_id not in bosses_defeated
	if boss_defeated:
		bosses_defeated.append(zone_id)
	var boss_appeared := not boss_was_available and GameData.is_boss_available(zone_id) 			and zone_id not in bosses_defeated

	hold_changed.emit()
	if discovery + zone_bonus > 0:
		add_coins(discovery + zone_bonus)
	save_game()
	return {
		"species": species, "size_cm": size_cm, "value": value,
		"is_new": is_new, "new_record": new_record,
		"discovery_bonus": discovery, "zone_complete_bonus": zone_bonus,
		"boss_defeated": boss_defeated,
		"unlocked_zone": GameData.zone_after(zone_id) if boss_defeated else "",
		"boss_appeared": boss_appeared,
	}


func reset() -> void:
	coins = 0
	hold.clear()
	upgrades = _default_upgrades()
	encyclopedia.clear()
	zone_complete_rewarded.clear()
	bosses_defeated.clear()
	trophy = null
	trip_second_chances = 0
	save_game()
	coins_changed.emit(coins)
	hold_changed.emit()
	upgrades_changed.emit()


## Writes to a temp file first and then swaps it in, so a crash mid-write
## can't leave a half-written save behind.
func save_game() -> void:
	if not saving_enabled:
		return
	var data := {
		"version": SAVE_VERSION,
		"locale": locale,
		"coins": coins,
		"hold": hold,
		"upgrades": upgrades,
		"encyclopedia": encyclopedia,
		"zone_complete_rewarded": zone_complete_rewarded,
		"bosses_defeated": bosses_defeated,
		"trophy": trophy,
		"trip_second_chances": trip_second_chances,
	}
	var tmp_path := save_path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(tmp_path, save_path)
	if err != OK:
		push_error("Could not replace save: %s" % error_string(err))


## Loads the save; if it's unreadable, falls back to the last good copy
## (save.json.bak, refreshed after every successful load).
func load_game() -> void:
	var backup_path := save_path + ".bak"
	var data = _read_save(save_path)
	if data == null and FileAccess.file_exists(save_path):
		push_warning("Save file is corrupt, trying the backup.")
		data = _read_save(backup_path)
	if data == null:
		return
	_apply_save(data)
	if saving_enabled and _read_save(save_path) != null:
		DirAccess.copy_absolute(save_path, backup_path)


func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	# A JSON instance reports bad input through its return code instead of
	# logging an engine error, so a corrupt save fails quietly.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data if json.data is Dictionary else null


## Applies saved data, dropping anything the current game data no longer has
## (a renamed fish, a removed upgrade) so an old save can never crash the game.
## JSON numbers load as floats, so everything is cast back to int.
func _apply_save(data: Dictionary) -> void:
	if int(data.get("version", SAVE_VERSION)) > SAVE_VERSION:
		push_warning("Save is from a newer version of the game; loading what we can.")
	locale = data.get("locale") if data.get("locale") in LOCALES else "uk"
	coins = maxi(0, int(data.get("coins", 0)))
	hold.clear()
	for fish in data.get("hold", []):
		if fish is Dictionary and GameData.has_fish(str(fish.get("species", ""))):
			hold.append({
				"species": str(fish.species),
				"size_cm": int(fish.get("size_cm", 0)),
				"value": int(fish.get("value", 0)),
			})
	upgrades = _default_upgrades()
	var saved_upgrades: Dictionary = data.get("upgrades", {})
	for id in saved_upgrades:
		if GameData.has_upgrade(id):
			upgrades[id] = clampi(int(saved_upgrades[id]), 0, GameData.upgrade(id).levels.size())
	encyclopedia.clear()
	var saved_entries: Dictionary = data.get("encyclopedia", {})
	for id in saved_entries:
		var entry = saved_entries[id]
		if entry is Dictionary and GameData.has_fish(id):
			encyclopedia[id] = {
				"count": int(entry.get("count", 0)),
				"best_cm": int(entry.get("best_cm", 0)),
				"best_value": int(entry.get("best_value", 0)),
			}
	zone_complete_rewarded.clear()
	for id in data.get("zone_complete_rewarded", []):
		if GameData.has_zone(str(id)):
			zone_complete_rewarded.append(str(id))
	bosses_defeated.clear()
	for id in data.get("bosses_defeated", []):
		if GameData.has_zone(str(id)):
			bosses_defeated.append(str(id))
	trophy = data.get("trophy")
	trip_second_chances = int(data.get("trip_second_chances", 0))


static func _default_upgrades() -> Dictionary:
	return {"hold": 0, "rod": 0, "bait": 0, "line": 0}
