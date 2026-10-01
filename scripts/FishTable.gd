class_name FishTable
## Weighted fish roll per zone (DESIGN.md §3.3, §5.2 bait, §8.1 sizes).

const BAIT_RARITIES := ["rare", "legendary"]


## Rarity weights for a zone, with the bait bonus applied. Rarities the zone has
## no fish for are dropped, which renormalizes the rest.
static func rarity_weights(zone_id: String) -> Dictionary:
	var bait := GameData.upgrade_effect("bait", "rare_weight_multiplier")
	var weights := {}
	for fish_id in GameData.zone(zone_id).fish:
		var rarity_id: String = GameData.fish(fish_id).rarity
		var w: float = GameData.rarity(rarity_id).weight
		weights[rarity_id] = w * bait if rarity_id in BAIT_RARITIES else w
	return weights


## Picks a rarity by weight, then a fish of that rarity uniformly, so two common
## fish share the common weight instead of doubling it.
static func roll(zone_id: String, rng: RandomNumberGenerator) -> String:
	var weights := rarity_weights(zone_id)
	var total := 0.0
	for w in weights.values():
		total += w
	var r := rng.randf() * total
	var picked: String = weights.keys()[-1]
	for rarity_id in weights:
		r -= weights[rarity_id]
		if r < 0.0:
			picked = rarity_id
			break
	var candidates: Array = GameData.zone(zone_id).fish.filter(
		func(id): return GameData.fish(id).rarity == picked)
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func roll_size(fish_id: String, rng: RandomNumberGenerator) -> int:
	var avg: float = GameData.fish(fish_id).avg_size_cm
	return roundi(avg * rng.randf_range(GameData.size_range[0], GameData.size_range[1]))
