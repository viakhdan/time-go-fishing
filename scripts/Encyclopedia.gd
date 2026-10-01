extends Control
## Encyclopedia (DESIGN.md §8.2): every species of the enabled zones. Uncaught
## fish show a silhouette and "???". A caught fish's page has its records,
## flavour line, a math fact, a "Try it" question (answer on tap) and a deeper
## fact that unlocks after enough catches.

const QUOTES := {"uk": ["«", "»"], "en": ["“", "”"]}

@onready var discovered_label: Label = %DiscoveredLabel
@onready var back_button: Button = %BackButton
@onready var fish_list: VBoxContainer = %FishList
@onready var picture: FishPicture = %Picture
@onready var name_label: Label = %NameLabel
@onready var sub_label: Label = %SubLabel
@onready var locked_label: Label = %LockedLabel
@onready var known_box: Control = %Known
@onready var records: RichTextLabel = %Records
@onready var flavor_label: Label = %FlavorLabel
@onready var fact_label: Label = %FactLabel
@onready var try_question: Label = %TryQuestion
@onready var show_answer_button: Button = %ShowAnswerButton
@onready var try_answer: Label = %TryAnswer
@onready var deep_label: Label = %DeepLabel

## fish id -> { "tile": Button, "picture": FishPicture, "label": Label }
var _tiles := {}
var selected := ""


func _ready() -> void:
	back_button.pressed.connect(func(): get_tree().change_scene_to_file(GameState.return_scene))
	show_answer_button.pressed.connect(_reveal_answer)
	_build_list()
	var ids := _all_fish()
	var caught := ids.filter(func(id): return id in GameState.encyclopedia)
	select(caught[0] if not caught.is_empty() else ids[0])
	back_button.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func select(fish_id: String) -> void:
	selected = fish_id
	# Setting button_pressed (not set_pressed_no_signal) lets the ButtonGroup unpress
	# the previous tile; select() is wired to `pressed`, which this doesn't emit.
	_tiles[fish_id].tile.button_pressed = true
	try_answer.hide()
	show_answer_button.show()
	_refresh()


func _all_fish() -> Array:
	var ids := []
	for zone in GameData.zones():
		ids.append_array(zone.fish)
	return ids


func _build_list() -> void:
	var group := ButtonGroup.new()
	for zone in GameData.zones():
		var heading := Label.new()
		heading.theme_type_variation = &"PaperHeading"
		heading.add_theme_font_size_override("font_size", 32)
		heading.text = zone.name_key
		fish_list.add_child(heading)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 16)
		fish_list.add_child(grid)
		for fish_id in zone.fish:
			grid.add_child(_make_tile(fish_id, group))


func _make_tile(fish_id: String, group: ButtonGroup) -> Button:
	var tile := Button.new()
	tile.theme_type_variation = &"PaperTile"
	tile.toggle_mode = true
	tile.button_group = group
	tile.custom_minimum_size = Vector2(340, 150)
	tile.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tile.pressed.connect(select.bind(fish_id))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(box)
	var pic := FishPicture.new()
	pic.custom_minimum_size = Vector2(0, 90)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pic)
	var label := Label.new()
	label.theme_type_variation = &"PaperLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	_tiles[fish_id] = {"tile": tile, "picture": pic, "label": label}
	return tile


func _refresh() -> void:
	var ids := _all_fish()
	var found := ids.filter(func(id): return id in GameState.encyclopedia).size()
	discovered_label.text = tr("UI_DISCOVERED").format({"n": found, "total": ids.size()})
	for fish_id in _tiles:
		var known: bool = fish_id in GameState.encyclopedia
		_tiles[fish_id].picture.setup(fish_id, known)
		_tiles[fish_id].label.text = tr(GameData.fish(fish_id).name_key) if known else tr("UI_UNKNOWN")
	_refresh_detail()


func _refresh_detail() -> void:
	var fish := GameData.fish(selected)
	var zone_name := tr(GameData.zone(fish.zone).name_key)
	var entry: Dictionary = GameState.encyclopedia.get(selected, {})
	var known := not entry.is_empty()
	picture.setup(selected, known)
	known_box.visible = known
	locked_label.visible = not known
	if not known:
		name_label.text = tr("UI_UNKNOWN")
		sub_label.text = zone_name
		return
	var rarity := GameData.rarity(fish.rarity)
	name_label.text = tr(fish.name_key)
	sub_label.text = "%s · %s" % [tr(rarity.name_key).to_upper(), zone_name]
	records.text = "%s: [b]%d[/b]     %s: [b]%s[/b]     %s: [b]%s[/b]" % [
		tr("UI_CAUGHT"), entry.count,
		tr("UI_BIGGEST"), tr("UI_SIZE_CM").format({"n": entry.best_cm}),
		tr("UI_BEST_PRICE"), UIText.coins(entry.best_value, 24)]
	var q: Array = QUOTES.get(GameState.locale, QUOTES.en)
	flavor_label.text = q[0] + tr(fish.flavor_key) + q[1]
	fact_label.text = tr(fish.fact_key)
	try_question.text = tr(fish.try_q_key)
	try_answer.text = tr(fish.try_a_key)
	var unlock := int(fish.deep_fact_unlock)
	if entry.count >= unlock:
		deep_label.text = tr(fish.deep_fact_key)
	else:
		deep_label.text = tr("UI_DEEP_FACT_LOCKED").format({"n": unlock, "have": entry.count})


func _reveal_answer() -> void:
	show_answer_button.hide()
	try_answer.show()
