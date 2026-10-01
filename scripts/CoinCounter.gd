class_name CoinCounter
extends HBoxContainer
## The player's coins with the coin icon; updates itself.

@export var font_size := 36

var amount_label := Label.new()


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	alignment = BoxContainer.ALIGNMENT_END
	amount_label.add_theme_font_size_override("font_size", font_size)
	amount_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(amount_label)
	var icon := TextureRect.new()
	icon.texture = UIText.COIN_TEXTURE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(font_size, font_size)
	add_child(icon)
	GameState.coins_changed.connect(_update.unbind(1))
	_update()


func _update() -> void:
	amount_label.text = str(GameState.coins)
