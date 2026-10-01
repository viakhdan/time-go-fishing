class_name UIText
## Shared formatting for player-facing numbers.

## No bundled font has 🪙; this renders through the system emoji font on desktop.
## TODO(step 6): replace with a coin icon (see ART_STYLE.md §10).
const COIN := "🪙"


static func coins(amount: int) -> String:
	return "%d %s" % [amount, COIN]
