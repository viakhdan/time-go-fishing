extends Node
## Autoload: read-only game content from data/*.json (DESIGN.md §5, §7, §8).
## Balance numbers live in the JSON files, never in code.

var fishing: Dictionary
## Boss fight rules (hearts, misses before it escapes, reel attempts).
var boss_fight: Dictionary
var size_range: Array
var discovery_bonus: int
var zone_complete_bonus: int

var _rarities: Dictionary
var _fish := {}
var _zones := {}
var _zone_order: Array[String] = []
var _upgrades := {}
var _upgrade_order: Array[String] = []


func _ready() -> void:
	var fish_data: Dictionary = _load_json("res://data/fish.json")
	fishing = fish_data.fishing
	boss_fight = fish_data.boss_fight
	size_range = fish_data.size_range
	discovery_bonus = int(fish_data.discovery_bonus)
	zone_complete_bonus = int(fish_data.zone_complete_bonus)
	_rarities = fish_data.rarities
	for f in fish_data.fish:
		_fish[f.id] = f
	for z in _load_json("res://data/zones.json"):
		_zones[z.id] = z
		_zone_order.append(z.id)
	for u in _load_json("res://data/upgrades.json"):
		_upgrades[u.id] = u
		_upgrade_order.append(u.id)


func fish(id: String) -> Dictionary:
	return _fish[id]


func has_fish(id: String) -> bool:
	return id in _fish


func has_zone(id: String) -> bool:
	return id in _zones


func has_upgrade(id: String) -> bool:
	return id in _upgrades


func rarity(id: String) -> Dictionary:
	return _rarities[id]


func rarity_of(fish_id: String) -> Dictionary:
	return _rarities[_fish[fish_id].rarity]


func zone(id: String) -> Dictionary:
	return _zones[id]


## Enabled zones in display order.
func zones() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _zone_order:
		if _zones[id].enabled:
			out.append(_zones[id])
	return out


## A zone opens when the previous zone's boss has been beaten.
func is_zone_unlocked(id: String) -> bool:
	var z: Dictionary = _zones[id]
	if not z.enabled:
		return false
	if z.unlock == null:
		return true
	return z.unlock.boss_of in GameState.bosses_defeated


## The zone that beating this zone's boss opens, or "" for the last one.
func zone_after(id: String) -> String:
	for z in zones():
		if z.unlock != null and z.unlock.boss_of == id:
			return z.id
	return ""


func is_boss(fish_id: String) -> bool:
	return _fish[fish_id].rarity == "boss"


## The boss can be challenged once every other species of its zone is caught.
func is_boss_available(zone_id: String) -> bool:
	var z: Dictionary = _zones[zone_id]
	for fish_id in z.fish:
		if fish_id != z.boss and fish_id not in GameState.encyclopedia:
			return false
	return true


func upgrade(id: String) -> Dictionary:
	return _upgrades[id]


## Enabled upgrades in display order.
func upgrades() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _upgrade_order:
		if _upgrades[id].enabled:
			out.append(_upgrades[id])
	return out


## Effect value at the player's current level (level 0 = `base`).
## Disabled upgrades always give their base value.
func upgrade_effect(id: String, key: String) -> float:
	var u: Dictionary = _upgrades[id]
	var level: int = GameState.upgrade_level(id) if u.enabled else 0
	var values: Dictionary = u.base if level == 0 else u.levels[level - 1]
	return values.get(key, u.base.get(key, 0))


func _load_json(path: String) -> Variant:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(data != null, "Could not parse %s" % path)
	return data
