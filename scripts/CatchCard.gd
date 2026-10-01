extends PanelContainer
## Fish reveal: sprite, name, rarity, size, value (DESIGN.md §10). Until the fish
## art exists (step 6), a block in the rarity colour stands in for the sprite.

signal closed

@onready var sprite: TextureRect = %Sprite
@onready var sprite_placeholder: ColorRect = %SpritePlaceholder
@onready var name_label: Label = %NameLabel
@onready var rarity_label: Label = %RarityLabel
@onready var info_label: Label = %InfoLabel
@onready var bonus_label: Label = %BonusLabel
@onready var to_hold_button: Button = %ToHoldButton

var _result := {}


func _ready() -> void:
	to_hold_button.pressed.connect(closed.emit)


func show_catch(result: Dictionary) -> void:
	_result = result
	var fish := GameData.fish(result.species)
	var color := Color(GameData.rarity(fish.rarity).color)
	var has_sprite := ResourceLoader.exists(fish.sprite)
	sprite.visible = has_sprite
	sprite_placeholder.visible = not has_sprite
	if has_sprite:
		sprite.texture = load(fish.sprite)
	sprite_placeholder.color = color
	rarity_label.add_theme_color_override("font_color", color)
	_refresh_text()
	show()
	to_hold_button.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_text()


func _refresh_text() -> void:
	if _result.is_empty():
		return
	var fish := GameData.fish(_result.species)
	name_label.text = tr(fish.name_key)
	rarity_label.text = tr(GameData.rarity(fish.rarity).name_key).to_upper()
	var info := "%s · ≈%s" % [tr("UI_SIZE_CM").format({"n": _result.size_cm}), UIText.coins(_result.value)]
	if _result.is_new:
		info += " · " + tr("UI_NEW")
	elif _result.new_record:
		info += " · " + tr("UI_NEW_RECORD")
	info_label.text = info
	var bonuses: Array[String] = []
	if _result.discovery_bonus > 0:
		bonuses.append(tr("UI_DISCOVERY_BONUS").format({"n": _result.discovery_bonus}))
	if _result.zone_complete_bonus > 0:
		bonuses.append(tr("UI_ZONE_COMPLETE").format({"n": _result.zone_complete_bonus}))
	bonus_label.text = "\n".join(bonuses)
	bonus_label.visible = not bonuses.is_empty()
