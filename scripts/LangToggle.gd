class_name LangToggle
extends HBoxContainer
## UA | EN switch (DESIGN.md §11). Saved with the game.

@export var button_size := Vector2(72, 56)

var _buttons := {}


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	var group := ButtonGroup.new()
	for locale in GameState.LOCALES:
		var b := Button.new()
		b.text = "UA" if locale == "uk" else locale.to_upper()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = button_size
		b.focus_mode = Control.FOCUS_NONE
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(GameState.set_locale.bind(locale))
		add_child(b)
		_buttons[locale] = b
	GameState.locale_changed.connect(_refresh)
	_refresh(GameState.locale)


func _refresh(locale: String) -> void:
	for l in _buttons:
		_buttons[l].set_pressed_no_signal(l == locale)
