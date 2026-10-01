extends PanelContainer
## Fish reveal: picture, name, rarity, size, value (DESIGN.md §10).

signal closed

const STARS: Dictionary = preload("res://scripts/ProblemPanel.gd").STARS

@onready var picture: FishPicture = %Picture
@onready var name_label: Label = %NameLabel
@onready var rarity_label: Label = %RarityLabel
@onready var info_label: RichTextLabel = %InfoLabel
@onready var bonus_label: RichTextLabel = %BonusLabel
@onready var to_hold_button: Button = %ToHoldButton

var _result := {}


func _ready() -> void:
	to_hold_button.pressed.connect(closed.emit)


func show_catch(result: Dictionary) -> void:
	_result = result
	var fish := GameData.fish(result.species)
	picture.setup(result.species)
	rarity_label.add_theme_color_override("font_color", Color(GameData.rarity(fish.rarity).color))
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
	rarity_label.text = "%s  %s" % [STARS[fish.rarity], tr(GameData.rarity(fish.rarity).name_key).to_upper()]
	var info := "%s  ·  ≈%s" % [tr("UI_SIZE_CM").format({"n": _result.size_cm}), UIText.coins(_result.value, 30)]
	if _result.is_new:
		info += "  ·  [color=%s]%s[/color]" % [Palette.LANTERN.to_html(false), tr("UI_NEW")]
	elif _result.new_record:
		info += "  ·  [color=%s]%s[/color]" % [Palette.LANTERN.to_html(false), tr("UI_NEW_RECORD")]
	info_label.text = info
	var bonuses: Array[String] = []
	if _result.discovery_bonus > 0:
		bonuses.append(UIText.rich("UI_DISCOVERY_BONUS", {"n": _result.discovery_bonus}))
	if _result.zone_complete_bonus > 0:
		bonuses.append(UIText.rich("UI_ZONE_COMPLETE", {"n": _result.zone_complete_bonus}))
	if _result.get("boss_defeated", false):
		var next: String = _result.unlocked_zone
		bonuses.append(tr("UI_BOSS_DEFEATED").format({"zone": tr(GameData.zone(next).name_key)}) if next else tr("UI_BOSS_DEFEATED_LAST"))
	if _result.get("boss_appeared", false):
		bonuses.append(tr("UI_BOSS_APPEARS"))
	bonus_label.text = "\n".join(bonuses)
	bonus_label.visible = not bonuses.is_empty()
