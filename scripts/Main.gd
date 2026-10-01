extends Control
## Main menu: play, encyclopedia, language (DESIGN.md §2).

const MAP_SCENE := "res://scenes/Map.tscn"
const ENCYCLOPEDIA_SCENE := "res://scenes/Encyclopedia.tscn"
const SCENE_PATH := "res://scenes/Main.tscn"

@onready var play_button: Button = %PlayButton
@onready var encyclopedia_button: Button = %EncyclopediaButton


func _ready() -> void:
	play_button.pressed.connect(_open.bind(MAP_SCENE))
	encyclopedia_button.pressed.connect(func():
		GameState.return_scene = SCENE_PATH
		_open(ENCYCLOPEDIA_SCENE))
	play_button.grab_focus()


func _open(path: String) -> void:
	get_tree().change_scene_to_file(path)
