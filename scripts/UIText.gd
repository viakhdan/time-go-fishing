class_name UIText
## Shared formatting for player-facing numbers and upgrade effects.

## No bundled font has 🪙; this renders through the system emoji font on desktop.
## TODO(step 6): replace with a coin icon (see ART_STYLE.md §10).
const COIN := "🪙"


static func coins(amount: int) -> String:
	return "%d %s" % [amount, COIN]


## Decimal number in the current language's style: 1,5 in Ukrainian, 1.5 in English.
static func number(value: float) -> String:
	var text := str(snappedf(value, 0.01))
	if text.ends_with(".0"):
		text = text.trim_suffix(".0")
	return text.replace(".", ",") if GameState.locale == "uk" else text


## "Before → after" lines for buying the next level of an upgrade (§5.2),
## e.g. ["Slots: 6 → 8"] or ["Timer: 45 s → 55 s", "Green zone: +0% → +15%"].
static func upgrade_effects(id: String, from_level: int, to_level: int) -> Array[String]:
	var u := GameData.upgrade(id)
	var before: Dictionary = u.base if from_level == 0 else u.levels[from_level - 1]
	var after: Dictionary = u.levels[to_level - 1]
	var lines: Array[String] = []
	for key in u.base:
		lines.append(_effect_line(key, before.get(key, u.base[key]), after[key]))
	for z in GameData.zones():
		if z.unlock != null and z.unlock.upgrade == id and int(z.unlock.level) == to_level:
			lines.append(_t("UI_UNLOCKS").format({"zone": _t(z.name_key)}))
	return lines


static func _effect_line(key: String, before: float, after: float) -> String:
	match key:
		"slots":
			return "%s: %d → %d" % [_t("STAT_SLOTS"), before, after]
		"timer_bonus_s":
			# Shown on the rare-fish timer, the one players meet first (§10 wireframe).
			var base: float = GameData.rarity("rare").timer_s
			var fmt := _t("UI_TIMER_S")
			return "%s: %s → %s" % [_t("STAT_TIMER"), fmt.format({"n": roundi(base + before)}), fmt.format({"n": roundi(base + after)})]
		"reel_zone_bonus":
			return "%s: +%d%% → +%d%%" % [_t("STAT_REEL_ZONE"), roundi(before * 100), roundi(after * 100)]
		"rare_weight_multiplier":
			return "%s: ×%s → ×%s" % [_t("STAT_RARE_CHANCE"), number(before), number(after)]
		"second_chances":
			return "%s: %d → %d" % [_t("STAT_SECOND_CHANCES"), before, after]
	return "%s: %s → %s" % [key, number(before), number(after)]


## tr() for static code (no Object to call it on).
static func _t(key: String) -> String:
	return String(TranslationServer.translate(key))
