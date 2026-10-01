extends Control
## Shared zone scene, configured by GameState.current_zone (DESIGN.md §2, §10).
## Connects FishingLoop to the modal panels. Placeholder visuals until step 6.

const MAP_SCENE := "res://scenes/Map.tscn"
const DOCK_SCENE := "res://scenes/Dock.tscn"
const PLACEHOLDER_BG := {"lake": Color("#a68554"), "river": Color("#62878f"), "bay": Color("#0a1426")}
const STATUS_KEYS := {FishingLoop.State.WAITING: "UI_WAITING", FishingLoop.State.BITE: "UI_BITE"}
const MODAL_STATES := [FishingLoop.State.PROBLEM, FishingLoop.State.REEL, FishingLoop.State.CAUGHT, FishingLoop.State.ESCAPED]

@onready var loop: FishingLoop = $FishingLoop
@onready var background: ColorRect = $Background
@onready var zone_label: Label = %ZoneLabel
@onready var coins_label: Label = %CoinsLabel
@onready var hold_label: Label = %HoldLabel
@onready var map_button: Button = %MapButton
@onready var status_label: Label = %StatusLabel
@onready var cast_button: Button = %CastButton
@onready var hold_full_box: Control = %HoldFullBox
@onready var return_button: Button = %ReturnButton
@onready var release_button: Button = %ReleaseButton
@onready var release_box: Control = %ReleaseBox
@onready var confirm_release_button: Button = %ConfirmReleaseButton
@onready var cancel_release_button: Button = %CancelReleaseButton
@onready var hold_panel: HBoxContainer = %HoldPanel
@onready var modal: Control = %Modal
@onready var problem_panel: PanelContainer = %ProblemPanel
@onready var reel: PanelContainer = %ReelMinigame
@onready var catch_card: PanelContainer = %CatchCard


func _ready() -> void:
	var zone := GameData.zone(GameState.current_zone)
	loop.zone_id = zone.id
	background.color = PLACEHOLDER_BG.get(zone.id, Color.BLACK)
	zone_label.text = zone.name_key

	cast_button.pressed.connect(loop.cast)
	map_button.pressed.connect(_leave.bind(MAP_SCENE))
	return_button.pressed.connect(_leave.bind(DOCK_SCENE))
	release_button.pressed.connect(_set_release_mode.bind(true))
	cancel_release_button.pressed.connect(_set_release_mode.bind(false))
	confirm_release_button.pressed.connect(_release_selected)
	hold_panel.selection_changed.connect(func(i): confirm_release_button.disabled = i < 0)

	loop.state_changed.connect(_on_state_changed)
	loop.problem_started.connect(_on_problem_started)
	loop.reel_started.connect(func(zone_fraction, retry): reel.start(zone_fraction, retry, loop.rng))
	loop.caught.connect(catch_card.show_catch)
	loop.escaped.connect(_on_escaped)
	problem_panel.answered.connect(loop.submit_answer)
	problem_panel.continue_pressed.connect(loop.acknowledge)
	reel.finished.connect(loop.reel_result)
	catch_card.closed.connect(loop.acknowledge)

	GameState.coins_changed.connect(_update_hud.unbind(1))
	GameState.hold_changed.connect(_update_hud)
	_update_hud()
	_on_state_changed(loop.state)


func _process(_delta: float) -> void:
	if loop.state == FishingLoop.State.PROBLEM and loop.time_limit > 0.0:
		problem_panel.set_time_left(loop.time_left)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_hud()


func _on_state_changed(state: FishingLoop.State) -> void:
	var idle := state == FishingLoop.State.IDLE
	var full := GameState.is_hold_full()
	var releasing: bool = hold_panel.selectable
	cast_button.visible = idle and not full
	hold_full_box.visible = idle and full and not releasing
	release_box.visible = idle and releasing
	map_button.disabled = not idle
	status_label.text = STATUS_KEYS.get(state, "")
	# Each panel is shown by its own signal handler; here we only hide stale ones.
	if state not in [FishingLoop.State.PROBLEM, FishingLoop.State.ESCAPED]:
		problem_panel.hide()
	if state != FishingLoop.State.REEL:
		reel.hide()
	if state != FishingLoop.State.CAUGHT:
		catch_card.hide()
	modal.visible = state in MODAL_STATES


func _on_problem_started(problem: Dictionary, time_limit: float, second_chance: bool) -> void:
	problem_panel.show_problem(problem, GameData.fish(loop.fish_id).rarity, time_limit, second_chance)


func _on_escaped(reason: FishingLoop.Escape, _problem: Dictionary) -> void:
	if reason == FishingLoop.Escape.REEL:
		problem_panel.show_reel_escape()
	else:
		problem_panel.show_miss(reason)


## Hold full: pick a slot to free it, with no coins (§4).
func _set_release_mode(on: bool) -> void:
	hold_panel.selectable = on
	confirm_release_button.disabled = true
	_on_state_changed(loop.state)


func _release_selected() -> void:
	if hold_panel.selected >= 0:
		GameState.release_fish(hold_panel.selected)
	_set_release_mode(false)


func _update_hud() -> void:
	coins_label.text = UIText.coins(GameState.coins)
	hold_label.text = "%s %d/%d" % [tr("UI_HOLD"), GameState.hold.size(), GameState.hold_capacity()]


func _leave(scene: String) -> void:
	GameState.save_game()
	get_tree().change_scene_to_file(scene)
