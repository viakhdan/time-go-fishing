class_name Economy
## Sell prices (DESIGN.md §5.1). Purchases are added in step 5.


## base_price[rarity] × (size_cm / avg_size_cm), rounded, minimum 1.
static func sell_price(fish_id: String, size_cm: int) -> int:
	var fish := GameData.fish(fish_id)
	var base: float = GameData.rarity(fish.rarity).base_price
	return maxi(1, roundi(base * size_cm / float(fish.avg_size_cm)))
