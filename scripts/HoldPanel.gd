extends HBoxContainer
## The hold (DESIGN.md §4): one slot per unit of capacity, 1 fish = 1 slot.
## Used in the Zone (pick a fish to release) and the Dock (sell with prices).
## Placeholder look until step 6: a rarity-coloured block stands in for the sprite.

signal selection_changed(index: int)  ## -1 when nothing is selected

@export var slot_size := 104
@export var show_prices := false
## When true, a filled slot can be picked (one at a time; click again to unpick).
@export var selectable := false:
	set(value):
		selectable = value
		if is_node_ready():
			_rebuild()

var selected := -1


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	GameState.hold_changed.connect(_rebuild)
	_rebuild()


func _notification(what: int) -> void:
	# Deferred: children can't be removed while the notification is propagating.
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_rebuild.call_deferred()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for i in GameState.hold_capacity():
		add_child(_make_slot(i, group))
	if selected != -1:
		selected = -1
		selection_changed.emit(-1)


func _make_slot(index: int, group: ButtonGroup) -> Button:
	var fish: Dictionary = GameState.hold[index] if index < GameState.hold.size() else {}
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(slot_size, slot_size + (32 if show_prices else 0))
	slot.toggle_mode = true
	slot.button_group = group
	slot.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if fish.is_empty():
		slot.disabled = true
	elif not selectable:
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.focus_mode = Control.FOCUS_NONE
	if fish.is_empty():
		return slot

	var data := GameData.fish(fish.species)
	slot.tooltip_text = tr(data.name_key)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(box)

	var picture: Control
	if ResourceLoader.exists(data.sprite):
		picture = TextureRect.new()
		picture.texture = load(data.sprite)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		picture = ColorRect.new()
		picture.color = Color(GameData.rarity(data.rarity).color)
	picture.custom_minimum_size = Vector2(slot_size * 0.7, slot_size * 0.4)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(picture)

	var label := Label.new()
	label.text = UIText.coins(fish.value) if show_prices else tr("UI_SIZE_CM").format({"n": fish.size_cm})
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	slot.toggled.connect(_on_slot_toggled.bind(index))
	return slot


func _on_slot_toggled(pressed: bool, index: int) -> void:
	if pressed:
		selected = index
	elif selected == index:
		selected = -1
	else:
		return
	selection_changed.emit(selected)
