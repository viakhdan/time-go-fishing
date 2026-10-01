extends Node
## Autoload: read-only game content from data/*.json (DESIGN.md §5, §7, §8).
## Balance numbers live in the JSON files, never in code.

var fishing: Dictionary
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


func is_zone_unlocked(id: String) -> bool:
	var z: Dictionary = _zones[id]
	if not z.enabled:
		return false
	if z.unlock == null:
		return true
	return GameState.upgrade_level(z.unlock.upgrade) >= int(z.unlock.level)


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
