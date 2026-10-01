extends Node
## Autoload: problem pools with a shuffle-bag per topic and tier (DESIGN.md §6).
## No problem repeats until its tier's pool is used up.

const POOL_DIR := "res://data/problems/%s.json"

var rng := RandomNumberGenerator.new()

var _pools := {}  # topic -> { tier -> Array[Dictionary] }
var _bags := {}   # "topic:tier" -> Array[int] of pool indices still to draw
var _last := {}   # "topic:tier" -> last drawn problem id


func _ready() -> void:
	rng.randomize()


## Draws the next problem of a tier, never `exclude_id` (used for second chances).
## Returns a copy with options shuffled and `answer_index` remapped.
func draw(topic: String, tier: int, exclude_id := "") -> Dictionary:
	var pool := _pool(topic, tier)
	assert(not pool.is_empty(), "No tier %d problems in %s" % [tier, topic])
	var key := "%s:%d" % [topic, tier]
	var bag: Array = _bags.get(key, [])
	var avoid := [exclude_id, _last.get(key, "")]
	if bag.is_empty():
		bag = range(pool.size())
		_shuffle(bag)
	# Swap an unwanted problem off the top of the bag (keeps it for later).
	for i in bag.size():
		if pool[bag[-1 - i]].id not in avoid:
			if i > 0:
				var pick = bag[-1 - i]
				bag[-1 - i] = bag[-1]
				bag[-1] = pick
			break
	var p: Dictionary = pool[bag.pop_back()]
	_bags[key] = bag
	_last[key] = p.id
	return _shuffled_copy(p)


## Player-facing text of a {"uk": ..., "en": ...} field in the current language.
func text(localized: Dictionary) -> String:
	return localized.get(GameState.locale, localized.get("en", ""))


func _pool(topic: String, tier: int) -> Array:
	if topic not in _pools:
		var by_tier := {}
		var data = JSON.parse_string(FileAccess.get_file_as_string(POOL_DIR % topic))
		assert(data is Array, "Could not load problem pool %s" % topic)
		for p in data:
			by_tier.get_or_add(int(p.tier), []).append(p)
		_pools[topic] = by_tier
	return _pools[topic].get(tier, [])


func _shuffled_copy(p: Dictionary) -> Dictionary:
	var order := [0, 1, 2, 3]
	_shuffle(order)
	var options: Array[String] = []
	for i in order:
		options.append(p.options[i])
	return {
		"id": p.id,
		"tier": int(p.tier),
		"question": p.question,
		"options": options,
		"answer_index": order.find(int(p.answer_index)),
		"solution": p.solution,
	}


## Fisher–Yates with our own rng, so tests can seed it.
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
