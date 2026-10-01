extends Control
## Zone picker + way to the dock (DESIGN.md §2, §7). Locked zones name the
## upgrade that opens them; completed zones get a badge (§8.2).

const ZONE_SCENE := "res://scenes/Zone.tscn"
const DOCK_SCENE := "res://scenes/Dock.tscn"
const MAIN_SCENE := "res://scenes/Main.tscn"
const ENCYCLOPEDIA_SCENE := "res://scenes/Encyclopedia.tscn"
const SCENE_PATH := "res://scenes/Map.tscn"
const BADGE: Texture2D = preload("res://art/ui/icons/badge.svg")

@onready var coins_label: CoinCounter = %Coins
@onready var encyclopedia_button: Button = %EncyclopediaButton
@onready var dock_button: Button = %DockButton
@onready var menu_button: Button = %MenuButton
@onready var cards: HBoxContainer = %Cards

## zone id -> { "discovered": Label, "badge": Control, "badge_label": Label, "button": Button }
var _cards := {}


func _ready() -> void:
	dock_button.pressed.connect(_open.bind(DOCK_SCENE))
	menu_button.pressed.connect(_open.bind(MAIN_SCENE))
	encyclopedia_button.pressed.connect(func():
		GameState.return_scene = SCENE_PATH
		_open(ENCYCLOPEDIA_SCENE))
	for zone in GameData.zones():
		cards.add_child(_make_card(zone))
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func _make_card(zone: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	card.custom_minimum_size = Vector2(560, 0)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	var preview := ColorRect.new()
	preview.color = Palette.ZONE_BG.get(zone.id, Palette.NIGHT)
	preview.custom_minimum_size = Vector2(0, 240)
	var water := ColorRect.new()
	water.color = Palette.ZONE_WATER.get(zone.id, Palette.DEEP_TEAL)
	water.anchor_top = 0.62
	water.anchor_right = 1.0
	water.anchor_bottom = 1.0
	preview.add_child(water)
	if ResourceLoader.exists(zone.background):
		var art := TextureRect.new()
		art.texture = load(zone.background)
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		preview.add_child(art)
	var badge := TextureRect.new()
	badge.texture = BADGE
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = -104
	badge.offset_top = 12
	badge.offset_right = -12
	badge.offset_bottom = 104
	preview.add_child(badge)
	box.add_child(preview)

	var name_label := Label.new()
	name_label.theme_type_variation = &"TitleLabel"
	name_label.add_theme_font_size_override("font_size", 44)
	name_label.text = zone.name_key
	box.add_child(name_label)

	var topic_label := Label.new()
	topic_label.text = "TOPIC_" + zone.topic.to_upper()
	topic_label.theme_type_variation = &"MutedLabel"
	topic_label.add_theme_font_size_override("font_size", 26)
	box.add_child(topic_label)

	var discovered := Label.new()
	discovered.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(discovered)

	var badge_label := Label.new()
	badge_label.text = "UI_ZONE_BADGE"
	badge_label.add_theme_color_override("font_color", Palette.LANTERN)
	box.add_child(badge_label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 80)
	button.theme_type_variation = &"PrimaryButton"
	button.add_theme_font_size_override("font_size", 32)
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.pressed.connect(_fish_in.bind(zone.id))
	box.add_child(button)

	_cards[zone.id] = {"discovered": discovered, "badge": badge, "badge_label": badge_label, "button": button}
	return card


func _refresh() -> void:
	for zone in GameData.zones():
		var card: Dictionary = _cards[zone.id]
		var found: int = zone.fish.filter(func(id): return id in GameState.encyclopedia).size()
		card.discovered.text = tr("UI_DISCOVERED").format({"n": found, "total": zone.fish.size()})
		var complete: bool = zone.id in GameState.zone_complete_rewarded
		card.badge.visible = complete
		card.badge_label.visible = complete
		var button: Button = card.button
		button.disabled = not GameData.is_zone_unlocked(zone.id)
		if button.disabled:
			var prev_zone := tr(GameData.zone(zone.unlock.boss_of).name_key)
			button.text = "%s · %s" % [tr("UI_LOCKED"), tr("UI_REQUIRES_BOSS").format({"zone": prev_zone})]
		else:
			button.text = tr("UI_GO_FISHING")


func _fish_in(zone_id: String) -> void:
	GameState.current_zone = zone_id
	_open(ZONE_SCENE)


func _open(path: String) -> void:
	get_tree().change_scene_to_file(path)
