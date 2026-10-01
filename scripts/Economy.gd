class_name Economy
## Selling fish and buying upgrades (DESIGN.md §5). Every change saves.


## base_price[rarity] × (size_cm / avg_size_cm), rounded, minimum 1.
static func sell_price(fish_id: String, size_cm: int) -> int:
	var fish := GameData.fish(fish_id)
	var base: float = GameData.rarity(fish.rarity).base_price
	return maxi(1, roundi(base * size_cm / float(fish.avg_size_cm)))


static func hold_value() -> int:
	var total := 0
	for fish in GameState.hold:
		total += fish.value
	return total


## Sells one fish from the hold. Returns the coins earned.
static func sell(index: int) -> int:
	var fish := GameState.remove_fish(index)
	GameState.add_coins(fish.value)
	GameState.save_game()
	return fish.value


static func sell_all() -> int:
	var total := hold_value()
	GameState.hold.clear()
	GameState.hold_changed.emit()
	GameState.add_coins(total)
	GameState.save_game()
	return total


static func is_max_level(id: String) -> bool:
	return GameState.upgrade_level(id) >= GameData.upgrade(id).levels.size()


## Cost of the next level, or -1 at max level.
static func next_cost(id: String) -> int:
	if is_max_level(id):
		return -1
	return int(GameData.upgrade(id).levels[GameState.upgrade_level(id)].cost)


## Coins still needed for the next level (0 if affordable or maxed).
static func missing_coins(id: String) -> int:
	var cost := next_cost(id)
	return maxi(0, cost - GameState.coins) if cost >= 0 else 0


static func can_buy(id: String) -> bool:
	return GameData.upgrade(id).enabled and not is_max_level(id) and missing_coins(id) == 0


static func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	GameState.add_coins(-next_cost(id))
	GameState.set_upgrade_level(id, GameState.upgrade_level(id) + 1)
	GameState.save_game()
	return true
