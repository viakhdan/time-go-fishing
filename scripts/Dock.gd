extends Control
## Dock: Market (sell fish) and Workshop (buy upgrades) tabs (DESIGN.md §5, §10).

const MAP_SCENE := "res://scenes/Map.tscn"

@onready var coins_label: CoinCounter = %Coins
@onready var go_fishing_button: Button = %GoFishingButton
@onready var tabs: TabContainer = %Tabs
@onready var hold_panel: HBoxContainer = %HoldPanel
@onready var market_info: Label = %MarketInfo
@onready var sell_button: Button = %SellButton
@onready var sell_all_button: Button = %SellAllButton
@onready var upgrade_rows: VBoxContainer = %UpgradeRows

## upgrade id -> { "level": Label, "effects": Label, "buy": Button, "missing": RichTextLabel }
var _rows := {}


func _ready() -> void:
	go_fishing_button.pressed.connect(_go_fishing)
	hold_panel.selection_changed.connect(_refresh.unbind(1))
	sell_button.pressed.connect(func(): Economy.sell(hold_panel.selected))
	sell_all_button.pressed.connect(func(): Economy.sell_all())
	GameState.coins_changed.connect(_refresh.unbind(1))
	GameState.hold_changed.connect(_refresh)
	GameState.upgrades_changed.connect(_refresh)
	for u in GameData.upgrades():
		upgrade_rows.add_child(_make_row(u))
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


## Leaving the dock starts a new trip (refills strong-line charges, §5.2).
func _go_fishing() -> void:
	GameState.start_trip()
	get_tree().change_scene_to_file(MAP_SCENE)


func _make_row(upgrade: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Card"
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.texture = load(upgrade.icon)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(64, 64)
	row.add_child(icon)

	var names := VBoxContainer.new()
	names.custom_minimum_size.x = 400
	row.add_child(names)
	var name_label := Label.new()
	name_label.theme_type_variation = &"TitleLabel"
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.text = upgrade.name_key
	names.add_child(name_label)
	var desc := Label.new()
	desc.text = upgrade.desc_key
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.theme_type_variation = &"MutedLabel"
	desc.add_theme_font_size_override("font_size", 22)
	names.add_child(desc)

	var level := _dynamic_label(28)
	level.custom_minimum_size.x = 180
	row.add_child(level)
	var effects := _dynamic_label(28)
	effects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(effects)

	var buy_box := VBoxContainer.new()
	buy_box.custom_minimum_size.x = 260
	buy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buy_box)
	var buy := Button.new()
	buy.theme_type_variation = &"PrimaryButton"
	buy.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buy.custom_minimum_size.y = 72
	buy.add_theme_font_size_override("font_size", 32)
	buy.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	buy.pressed.connect(func(): Economy.buy(upgrade.id))
	buy_box.add_child(buy)
	var missing := RichTextLabel.new()
	missing.bbcode_enabled = true
	missing.fit_content = true
	missing.scroll_active = false
	missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	missing.add_theme_color_override("default_color", Palette.ALARM)
	missing.add_theme_font_size_override("normal_font_size", 22)
	missing.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	buy_box.add_child(missing)

	_rows[upgrade.id] = {"level": level, "effects": effects, "buy": buy, "missing": missing}
	return panel


func _dynamic_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _refresh() -> void:
	tabs.set_tab_title(0, tr("UI_MARKET"))
	tabs.set_tab_title(1, tr("UI_WORKSHOP"))
	_refresh_market()
	_refresh_workshop()


func _refresh_market() -> void:
	var empty := GameState.hold.is_empty()
	var selected: int = hold_panel.selected
	if empty:
		market_info.text = tr("UI_HOLD_EMPTY")
	elif selected < 0:
		market_info.text = tr("UI_SELECT_FISH")
	else:
		var fish: Dictionary = GameState.hold[selected]
		market_info.text = "%s · %s" % [tr(GameData.fish(fish.species).name_key), tr("UI_SIZE_CM").format({"n": fish.size_cm})]
	sell_button.disabled = selected < 0
	sell_button.text = tr("UI_SELL") if selected < 0 else "%s: %d" % [tr("UI_SELL"), GameState.hold[selected].value]
	sell_button.icon = null if selected < 0 else UIText.COIN_TEXTURE
	sell_all_button.disabled = empty
	sell_all_button.text = "%s: %d" % [tr("UI_SELL_ALL"), Economy.hold_value()]


func _refresh_workshop() -> void:
	for id in _rows:
		var row: Dictionary = _rows[id]
		var level := GameState.upgrade_level(id)
		var maxed := Economy.is_max_level(id)
		var lv := tr("UI_LEVEL")
		row.level.text = "%s %d" % [lv, level] if maxed else "%s %d → %d" % [lv, level, level + 1]
		row.effects.text = "" if maxed else "\n".join(UIText.upgrade_effects(id, level, level + 1))
		var buy: Button = row.buy
		buy.text = tr("UI_MAX_LEVEL") if maxed else str(Economy.next_cost(id))
		buy.icon = null if maxed else UIText.COIN_TEXTURE
		buy.disabled = not Economy.can_buy(id)
		var missing := Economy.missing_coins(id)
		row.missing.text = UIText.rich("UI_NEED_MORE", {"n": missing}, 22) if missing > 0 else ""
