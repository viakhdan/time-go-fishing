extends Control
## Main menu: play, encyclopedia, language (DESIGN.md §2), resetting progress
## so a shared classroom PC can start fresh for the next student, and restoring
## progress (marking zones 1…n as completed) after a lost save.

const MAP_SCENE := "res://scenes/Map.tscn"
const ENCYCLOPEDIA_SCENE := "res://scenes/Encyclopedia.tscn"
const SCENE_PATH := "res://scenes/Main.tscn"

@onready var play_button: Button = %PlayButton
@onready var encyclopedia_button: Button = %EncyclopediaButton
@onready var reset_button: Button = %ResetButton
@onready var reset_dialog: ConfirmationDialog = %ResetDialog
@onready var restore_button: Button = %RestoreButton
@onready var restore_dialog: AcceptDialog = %RestoreDialog
@onready var restore_done_dialog: AcceptDialog = %RestoreDoneDialog

## One "Zones 1–n" button per zone, rebuilt each time so the language is current.
var _restore_buttons: Array[Button] = []


func _ready() -> void:
	play_button.pressed.connect(_open.bind(MAP_SCENE))
	encyclopedia_button.pressed.connect(func():
		GameState.return_scene = SCENE_PATH
		_open(ENCYCLOPEDIA_SCENE))
	reset_button.pressed.connect(_ask_reset)
	reset_dialog.confirmed.connect(GameState.reset)
	restore_button.pressed.connect(_ask_restore)
	restore_dialog.custom_action.connect(_restore)
	play_button.grab_focus()


func _ask_reset() -> void:
	reset_dialog.title = tr("UI_RESET")
	reset_dialog.dialog_text = tr("UI_RESET_CONFIRM")
	reset_dialog.ok_button_text = tr("UI_RESET_OK")
	reset_dialog.cancel_button_text = tr("UI_CANCEL")
	reset_dialog.popup_centered()
	reset_dialog.get_cancel_button().grab_focus()


func _ask_restore() -> void:
	restore_dialog.title = tr("UI_RESTORE")
	restore_dialog.dialog_text = tr("UI_RESTORE_INFO")
	restore_dialog.ok_button_text = tr("UI_CANCEL")
	for b in _restore_buttons:
		restore_dialog.remove_button(b)
		b.queue_free()
	_restore_buttons.clear()
	# add_button() puts each new button to the left of the others, so add them
	# last-first to read "Zone 1, Zones 1–2, Zones 1–3, Cancel".
	var zones := GameData.zones()
	for i in range(zones.size() - 1, -1, -1):
		var label := tr("UI_RESTORE_ZONE_1") if i == 0 else tr("UI_RESTORE_ZONES").format({"n": i + 1})
		_restore_buttons.push_front(restore_dialog.add_button(label, false, zones[i].id))
	restore_dialog.popup_centered()
	restore_dialog.get_ok_button().grab_focus()


## custom_action carries the id of the last zone to complete.
func _restore(last_zone_id: StringName) -> void:
	restore_dialog.hide()
	GameState.complete_zones_through(last_zone_id)
	var count := GameData.zones().map(func(z): return z.id).find(String(last_zone_id)) + 1
	restore_done_dialog.title = tr("UI_RESTORE")
	restore_done_dialog.dialog_text = tr("UI_RESTORE_DONE").format({"n": count})
	restore_done_dialog.ok_button_text = "OK"
	restore_done_dialog.popup_centered()


func _open(path: String) -> void:
	get_tree().change_scene_to_file(path)
