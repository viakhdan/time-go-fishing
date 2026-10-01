extends PanelContainer
## Timing bar (DESIGN.md §3.3): a marker bounces along the bar, the player stops
## it inside the green zone. It's for feel, not difficulty.

signal finished(hit: bool)

@onready var title_label: Label = %TitleLabel
@onready var bar: Control = %Bar
@onready var zone: ColorRect = %GreenZone
@onready var marker: ColorRect = %Marker
@onready var reel_button: Button = %ReelButton

var _running := false
var _t := 0.0
var _speed := 1.0
var _zone_start := 0.0
var _zone_len := 0.2
var _retry := false


func _ready() -> void:
	reel_button.pressed.connect(_stop)


## zone_fraction: green zone width as a fraction of the bar.
func start(zone_fraction: float, retry: bool, rng: RandomNumberGenerator) -> void:
	_retry = retry
	_zone_len = zone_fraction
	_zone_start = rng.randf_range(0.0, 1.0 - zone_fraction)
	_speed = GameData.fishing.reel_speed
	_t = 0.0
	_running = true
	_refresh_text()
	show()
	reel_button.grab_focus()


func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta * _speed
	_layout()


func _unhandled_input(event: InputEvent) -> void:
	# The focused Reel button already handles ui_accept; this catches clicks elsewhere.
	if _running and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_stop()


func _marker_fraction() -> float:
	return pingpong(_t, 1.0)


func _layout() -> void:
	var w := bar.size.x
	zone.position = Vector2(_zone_start * w, 0)
	zone.size = Vector2(_zone_len * w, bar.size.y)
	marker.size.y = bar.size.y
	marker.position = Vector2(_marker_fraction() * w - marker.size.x / 2.0, 0)


func _stop() -> void:
	if not _running:
		return
	_running = false
	var m := _marker_fraction()
	finished.emit(m >= _zone_start and m <= _zone_start + _zone_len)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_text()


func _refresh_text() -> void:
	title_label.text = tr("UI_REEL_RETRY") if _retry else "%s %s" % [tr("UI_CORRECT"), tr("UI_REEL")]
