extends Control
## Shared zone scene, configured by GameState.current_zone (DESIGN.md §2, §10).
## Connects FishingLoop to the modal panels. The zone art sits over flat
## fallback colours, which only show if the background file is missing.

const MAP_SCENE := "res://scenes/Map.tscn"
const DOCK_SCENE := "res://scenes/Dock.tscn"
const ENCYCLOPEDIA_SCENE := "res://scenes/Encyclopedia.tscn"
const SCENE_PATH := "res://scenes/Zone.tscn"
## Upgrades shown as rig levels in the HUD (§5.2, §10).
const RIG := ["rod", "bait"]
const STATUS_KEYS := {FishingLoop.State.WAITING: "UI_WAITING", FishingLoop.State.BITE: "UI_BITE"}
const MODAL_STATES := [FishingLoop.State.PROBLEM, FishingLoop.State.REEL, FishingLoop.State.CAUGHT, FishingLoop.State.ESCAPED]

@onready var loop: FishingLoop = $FishingLoop
@onready var background: ColorRect = $Background
@onready var water: ColorRect = $Water
@onready var art: TextureRect = %Art
@onready var zone_label: Label = %ZoneLabel
@onready var coins_label: CoinCounter = %Coins
@onready var hold_label: Label = %HoldLabel
@onready var rig: HBoxContainer = %Rig
@onready var map_button: Button = %MapButton
@onready var encyclopedia_button: Button = %EncyclopediaButton
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

var _rig_labels := {}


func _ready() -> void:
	var zone := GameData.zone(GameState.current_zone)
	loop.zone_id = zone.id
	background.color = Palette.ZONE_BG.get(zone.id, Palette.NIGHT)
	water.color = Palette.ZONE_WATER.get(zone.id, Palette.DEEP_TEAL)
	if ResourceLoader.exists(zone.background):
		art.texture = load(zone.background)
	zone_label.text = zone.name_key
	_build_rig()

	cast_button.pressed.connect(loop.cast)
	map_button.pressed.connect(_leave.bind(MAP_SCENE))
	return_button.pressed.connect(_leave.bind(DOCK_SCENE))
	encyclopedia_button.pressed.connect(_open_encyclopedia)
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

	GameState.hold_changed.connect(_update_hud)
	GameState.upgrades_changed.connect(_update_hud)
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
	# Leaving mid-catch would lose the fish, so the exits only work when idle.
	map_button.disabled = not idle
	encyclopedia_button.disabled = not idle
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


## Rig icons with their upgrade level, e.g. [rod] Lv 2 [bait] Lv 1.
func _build_rig() -> void:
	for id in RIG:
		var icon := TextureRect.new()
		icon.texture = load(GameData.upgrade(id).icon)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(32, 32)
		icon.tooltip_text = GameData.upgrade(id).name_key
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		rig.add_child(icon)
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 28)
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		rig.add_child(label)
		_rig_labels[id] = label


func _update_hud() -> void:
	hold_label.text = "%d/%d" % [GameState.hold.size(), GameState.hold_capacity()]
	for id in _rig_labels:
		_rig_labels[id].text = "%s %d" % [tr("UI_LEVEL"), GameState.upgrade_level(id)]


func _open_encyclopedia() -> void:
	GameState.return_scene = SCENE_PATH
	_leave(ENCYCLOPEDIA_SCENE)


func _leave(scene: String) -> void:
	GameState.save_game()
	get_tree().change_scene_to_file(scene)
