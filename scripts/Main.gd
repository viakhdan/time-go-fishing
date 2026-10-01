extends Control
## Main menu: play, encyclopedia, language (DESIGN.md §2), and resetting
## progress so a shared classroom PC can start fresh for the next student.

const MAP_SCENE := "res://scenes/Map.tscn"
const ENCYCLOPEDIA_SCENE := "res://scenes/Encyclopedia.tscn"
const SCENE_PATH := "res://scenes/Main.tscn"

@onready var play_button: Button = %PlayButton
@onready var encyclopedia_button: Button = %EncyclopediaButton
@onready var reset_button: Button = %ResetButton
@onready var reset_dialog: ConfirmationDialog = %ResetDialog


func _ready() -> void:
	play_button.pressed.connect(_open.bind(MAP_SCENE))
	encyclopedia_button.pressed.connect(func():
		GameState.return_scene = SCENE_PATH
		_open(ENCYCLOPEDIA_SCENE))
	reset_button.pressed.connect(_ask_reset)
	reset_dialog.confirmed.connect(GameState.reset)
	play_button.grab_focus()


func _ask_reset() -> void:
	reset_dialog.title = tr("UI_RESET")
	reset_dialog.dialog_text = tr("UI_RESET_CONFIRM")
	reset_dialog.ok_button_text = tr("UI_RESET_OK")
	reset_dialog.cancel_button_text = tr("UI_CANCEL")
	reset_dialog.popup_centered()
	reset_dialog.get_cancel_button().grab_focus()


func _open(path: String) -> void:
	get_tree().change_scene_to_file(path)
