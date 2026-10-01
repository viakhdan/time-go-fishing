extends Control
## Zone picker + way to the dock (DESIGN.md §2, §7). Locked zones name the
## upgrade that opens them. Placeholder look until step 6; badges in step 7.

const ZONE_SCENE := "res://scenes/Zone.tscn"
const DOCK_SCENE := "res://scenes/Dock.tscn"
const MAIN_SCENE := "res://scenes/Main.tscn"
const ZONE_COLORS: Dictionary = preload("res://scripts/Zone.gd").PLACEHOLDER_BG

@onready var coins_label: Label = %CoinsLabel
@onready var dock_button: Button = %DockButton
@onready var menu_button: Button = %MenuButton
@onready var cards: HBoxContainer = %Cards

## zone id -> { "discovered": Label, "button": Button }
var _cards := {}


func _ready() -> void:
	dock_button.pressed.connect(_open.bind(DOCK_SCENE))
	menu_button.pressed.connect(_open.bind(MAIN_SCENE))
	for zone in GameData.zones():
		cards.add_child(_make_card(zone))
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func _make_card(zone: Dictionary) -> Control:
	var card := PanelContainer.new()
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
	preview.color = ZONE_COLORS.get(zone.id, Color.BLACK)
	preview.custom_minimum_size = Vector2(0, 220)
	box.add_child(preview)

	var name_label := Label.new()
	name_label.theme_type_variation = &"TitleLabel"
	name_label.add_theme_font_size_override("font_size", 44)
	name_label.text = zone.name_key
	box.add_child(name_label)

	var topic_label := Label.new()
	topic_label.text = "TOPIC_" + zone.topic.to_upper()
	topic_label.add_theme_color_override("font_color", Color("#a3bdbe"))
	box.add_child(topic_label)

	var discovered := Label.new()
	discovered.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(discovered)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 80)
	button.add_theme_font_size_override("font_size", 32)
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.pressed.connect(_fish_in.bind(zone.id))
	box.add_child(button)

	_cards[zone.id] = {"discovered": discovered, "button": button}
	return card


func _refresh() -> void:
	coins_label.text = UIText.coins(GameState.coins)
	for zone in GameData.zones():
		var card: Dictionary = _cards[zone.id]
		var found: int = zone.fish.filter(func(id): return id in GameState.encyclopedia).size()
		card.discovered.text = tr("UI_DISCOVERED").format({"n": found, "total": zone.fish.size()})
		var button: Button = card.button
		button.disabled = not GameData.is_zone_unlocked(zone.id)
		if button.disabled:
			var upgrade_name := tr(GameData.upgrade(zone.unlock.upgrade).name_key)
			button.text = "%s · %s" % [tr("UI_LOCKED"), tr("UI_REQUIRES").format({"upgrade": upgrade_name})]
		else:
			button.text = tr("UI_GO_FISHING")


func _fish_in(zone_id: String) -> void:
	GameState.current_zone = zone_id
	_open(ZONE_SCENE)


func _open(path: String) -> void:
	get_tree().change_scene_to_file(path)
