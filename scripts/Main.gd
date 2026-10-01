extends Control
## Main menu: play, encyclopedia, language (DESIGN.md §2).

const MAP_SCENE := "res://scenes/Map.tscn"
const ZONE_SCENE := "res://scenes/Zone.tscn"
const ENCYCLOPEDIA_SCENE := "res://scenes/Encyclopedia.tscn"

@onready var play_button: Button = %PlayButton
@onready var encyclopedia_button: Button = %EncyclopediaButton
@onready var lang_uk: Button = %LangUK
@onready var lang_en: Button = %LangEN


func _ready() -> void:
	play_button.pressed.connect(_play)
	encyclopedia_button.pressed.connect(_open.bind(ENCYCLOPEDIA_SCENE))
	lang_uk.pressed.connect(GameState.set_locale.bind("uk"))
	lang_en.pressed.connect(GameState.set_locale.bind("en"))
	GameState.locale_changed.connect(_refresh_lang_buttons)
	_refresh_lang_buttons(GameState.locale)
	# Scenes that don't exist yet stay disabled until they're built.
	encyclopedia_button.disabled = not ResourceLoader.exists(ENCYCLOPEDIA_SCENE)


## Until the Map exists (step 5), Play goes straight to the first zone.
func _play() -> void:
	if ResourceLoader.exists(MAP_SCENE):
		_open(MAP_SCENE)
	else:
		GameState.current_zone = "lake"
		_open(ZONE_SCENE)


func _open(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _refresh_lang_buttons(locale: String) -> void:
	lang_uk.button_pressed = locale == "uk"
	lang_en.button_pressed = locale == "en"
