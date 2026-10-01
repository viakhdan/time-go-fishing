extends SceneTree
## Builds art/ui/theme.tres from Palette colours and the bundled fonts
## (Docs/ART_STYLE.md §2, §3, §8, §10). Edit this file, not the .tres. Run:
##   <godot_console> --headless --path . -s <absolute path to this file>
##
## Theme type variations it defines (set `theme_type_variation` on a node):
##   Buttons:  PrimaryButton, AnswerButton, HoldSlot, PaperTile, IconButton
##   Panels:   ModalPanel, Card, HudBar, Banner, PaperPanel, PaperInset
##   Labels:   TitleLabel, OverlayLabel, SerifLabel, PaperLabel, PaperTitle,
##             PaperHeading, FlavorLabel, MutedLabel, WarningLabel
##   Rich:     PaperRichText

const OUT := "res://art/ui/theme.tres"
const FONTS := "res://art/fonts/"

var theme := Theme.new()
var fonts := {}


func _init() -> void:
	_load_fonts()
	theme.default_font = fonts.body
	theme.default_font_size = 24
	_labels()
	_buttons()
	_panels()
	_tabs()
	_misc()
	var err := ResourceSaver.save(theme, OUT)
	print("Saved %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


func _load_fonts() -> void:
	fonts.body = _font("PT_Sans-Web-Regular.ttf")
	fonts.body_bold = _font("PT_Sans-Web-Bold.ttf")
	fonts.heading = _font("Oswald[wght].ttf", 600)
	fonts.serif = _font("PT_Serif-Web-Regular.ttf")
	fonts.serif_bold = _font("PT_Serif-Web-Bold.ttf")
	fonts.serif_italic = _font("PT_Serif-Web-Italic.ttf")


## Every font falls back to Noto Sans (superscripts) then Noto Sans Math (→ √ ≤ ≥ ★).
func _font(file: String, weight := 0) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(FONTS + file)
	var fallbacks: Array[Font] = [load(FONTS + "NotoSans[wdth,wght].ttf"), load(FONTS + "NotoSansMath-Regular.ttf")]
	f.fallbacks = fallbacks
	if weight:
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


static func box(bg: Color, border := Color.TRANSPARENT, border_w := 0, margin_h := -1, margin_v := -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(2)
	s.anti_aliasing = false
	if margin_h >= 0:
		s.content_margin_left = margin_h
		s.content_margin_right = margin_h
	if margin_v >= 0:
		s.content_margin_top = margin_v
		s.content_margin_bottom = margin_v
	return s


func _variation(name: String, base: String) -> void:
	theme.set_type_variation(name, base)


func _labels() -> void:
	theme.set_color("font_color", "Label", Palette.PAPER_LIGHT)

	_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", fonts.heading)
	theme.set_color("font_color", "TitleLabel", Palette.WHITE)

	# Text drawn straight over art (zone status): outlined for readability (§9.3).
	_variation("OverlayLabel", "Label")
	theme.set_font("font", "OverlayLabel", fonts.heading)
	theme.set_color("font_color", "OverlayLabel", Palette.WHITE)
	theme.set_color("font_outline_color", "OverlayLabel", Palette.INK_SOFT)
	theme.set_constant("outline_size", "OverlayLabel", 12)

	_variation("SerifLabel", "Label")
	theme.set_font("font", "SerifLabel", fonts.serif)

	_variation("MutedLabel", "Label")
	theme.set_color("font_color", "MutedLabel", Palette.FOAM)

	_variation("WarningLabel", "Label")
	theme.set_color("font_color", "WarningLabel", Palette.ALARM)

	# Encyclopedia book: dark ink on parchment.
	_variation("PaperLabel", "Label")
	theme.set_color("font_color", "PaperLabel", Palette.WOOD_DARK)
	_variation("PaperTitle", "Label")
	theme.set_font("font", "PaperTitle", fonts.serif_bold)
	theme.set_color("font_color", "PaperTitle", Palette.INK_SOFT)
	_variation("PaperHeading", "Label")
	theme.set_font("font", "PaperHeading", fonts.heading)
	theme.set_color("font_color", "PaperHeading", Palette.MAROON)
	_variation("FlavorLabel", "Label")
	theme.set_font("font", "FlavorLabel", fonts.serif_italic)
	theme.set_color("font_color", "FlavorLabel", Palette.UMBER)

	theme.set_font("normal_font", "RichTextLabel", fonts.body)
	theme.set_font("bold_font", "RichTextLabel", fonts.body_bold)
	theme.set_color("default_color", "RichTextLabel", Palette.PAPER_LIGHT)
	_variation("PaperRichText", "RichTextLabel")
	theme.set_color("default_color", "PaperRichText", Palette.WOOD_DARK)


func _button_styles(type: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox, disabled: StyleBox) -> void:
	theme.set_stylebox("normal", type, normal)
	theme.set_stylebox("hover", type, hover)
	theme.set_stylebox("pressed", type, pressed)
	theme.set_stylebox("hover_pressed", type, pressed)
	theme.set_stylebox("disabled", type, disabled)
	var focus := box(Color.TRANSPARENT, Palette.PAPER_LIGHT, 2)
	focus.draw_center = false
	theme.set_stylebox("focus", type, focus)


func _button_colors(type: String, normal: Color, disabled: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, type, normal)
	theme.set_color("font_disabled_color", type, disabled)
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		theme.set_color(state, type, Color.WHITE)
	theme.set_color("icon_disabled_color", type, Color(1, 1, 1, 0.35))


func _buttons() -> void:
	theme.set_font("font", "Button", fonts.heading)
	theme.set_constant("icon_max_width", "Button", 32)
	theme.set_constant("h_separation", "Button", 10)
	_button_styles("Button",
		box(Palette.WOOD_DARK, Palette.WOOD, 2, 20, 8),
		box(Palette.WOOD, Palette.OCHRE_DARK, 2, 20, 8),
		box(Palette.MAROON, Palette.SAND, 2, 20, 8),
		box(Palette.INK_SOFT, Palette.WOOD_DARK, 2, 20, 8))
	_button_colors("Button", Palette.PAPER_LIGHT, Palette.STONE)

	# The main action on a screen: cast, reel, buy, sell (green like upgrades_inspo).
	_variation("PrimaryButton", "Button")
	_button_styles("PrimaryButton",
		box(Palette.KELP, Palette.GO, 3, 24, 8),
		box(Palette.JADE, Palette.GO, 3, 24, 8),
		box(Palette.KELP.darkened(0.3), Palette.PAPER_LIGHT, 3, 24, 8),
		box(Palette.INK_SOFT, Palette.WOOD_DARK, 2, 24, 8))
	_button_colors("PrimaryButton", Palette.WHITE, Palette.STONE)

	# Math answers: readable body font on a cool slate panel.
	_variation("AnswerButton", "Button")
	theme.set_font("font", "AnswerButton", fonts.body)
	_button_styles("AnswerButton",
		box(Palette.SLATE, Palette.STEEL, 3, 20, 8),
		box(Palette.STEEL, Palette.MIST, 3, 20, 8),
		box(Palette.SEA, Palette.FOAM, 3, 20, 8),
		box(Palette.INK_SOFT, Palette.WOOD_DARK, 2, 20, 8))
	_button_colors("AnswerButton", Palette.WHITE, Palette.STONE)

	# Hold slots: maroon cells like inventory_inspo; the picked one gets a lantern frame.
	_variation("HoldSlot", "Button")
	theme.set_font("font", "HoldSlot", fonts.body)
	_button_styles("HoldSlot",
		box(Palette.MAROON_DARK, Palette.WOOD_DARK, 2, 4, 4),
		box(Palette.MAROON, Palette.WOOD, 2, 4, 4),
		box(Palette.MAROON, Palette.LANTERN, 4, 4, 4),
		box(Palette.INK_SOFT, Palette.WOOD_DARK, 2, 4, 4))
	_button_colors("HoldSlot", Palette.PAPER_LIGHT, Palette.STONE)

	# Encyclopedia list entries on parchment.
	_variation("PaperTile", "Button")
	theme.set_font("font", "PaperTile", fonts.body)
	_button_styles("PaperTile",
		box(Palette.PAPER_DARK, Palette.OCHRE, 2, 8, 8),
		box(Palette.PAPER_LIGHT, Palette.OCHRE_DARK, 2, 8, 8),
		box(Palette.PAPER_LIGHT, Palette.MAROON, 4, 8, 8),
		box(Palette.PAPER_DARK, Palette.OCHRE, 2, 8, 8))
	_button_colors("PaperTile", Palette.WOOD_DARK, Palette.WOOD_DARK)

	# Square icon-only buttons in top bars.
	_variation("IconButton", "Button")
	_button_styles("IconButton",
		box(Palette.WOOD_DARK, Palette.WOOD, 2, 12, 8),
		box(Palette.WOOD, Palette.OCHRE_DARK, 2, 12, 8),
		box(Palette.MAROON, Palette.SAND, 2, 12, 8),
		box(Palette.INK_SOFT, Palette.WOOD_DARK, 2, 12, 8))
	theme.set_constant("icon_max_width", "IconButton", 40)


func _panels() -> void:
	# Dark UI panel with a wood frame (upgrades_inspo).
	theme.set_stylebox("panel", "PanelContainer", box(Palette.INK_SOFT, Palette.WOOD, 3))
	theme.set_stylebox("panel", "Panel", box(Palette.INK_SOFT, Palette.WOOD, 3))

	_variation("ModalPanel", "PanelContainer")
	var modal := box(Color(Palette.INK, 0.94), Palette.WOOD, 6)
	modal.shadow_color = Color(Palette.INK, 0.5)
	modal.shadow_size = 16
	theme.set_stylebox("panel", "ModalPanel", modal)

	_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", box(Color(Palette.INK, 0.85), Palette.WOOD_DARK, 3))

	_variation("HudBar", "PanelContainer")
	theme.set_stylebox("panel", "HudBar", box(Color(Palette.INK, 0.6)))

	# Maroon header strip (upgrades_inspo "Select an upgrade…" bar).
	_variation("Banner", "PanelContainer")
	theme.set_stylebox("panel", "Banner", box(Palette.MAROON, Palette.MAROON_DARK, 0, 24, 8))

	_variation("PaperPanel", "PanelContainer")
	var paper := box(Palette.PAPER, Palette.WOOD, 8)
	paper.shadow_color = Color(Palette.INK, 0.6)
	paper.shadow_size = 20
	theme.set_stylebox("panel", "PaperPanel", paper)

	_variation("PaperInset", "PanelContainer")
	theme.set_stylebox("panel", "PaperInset", box(Palette.PAPER_DARK, Palette.OCHRE, 2, 16, 12))


func _tabs() -> void:
	theme.set_font("font", "TabContainer", fonts.heading)
	theme.set_font_size("font_size", "TabContainer", 32)
	theme.set_stylebox("panel", "TabContainer", box(Palette.INK_SOFT, Palette.WOOD, 4))
	theme.set_stylebox("tab_selected", "TabContainer", box(Palette.MAROON, Palette.SAND, 0, 32, 10))
	theme.set_stylebox("tab_unselected", "TabContainer", box(Palette.WOOD_DARK, Palette.WOOD, 0, 32, 10))
	theme.set_stylebox("tab_hovered", "TabContainer", box(Palette.WOOD, Palette.WOOD, 0, 32, 10))
	theme.set_color("font_selected_color", "TabContainer", Palette.WHITE)
	theme.set_color("font_unselected_color", "TabContainer", Palette.ASH)
	theme.set_color("font_hovered_color", "TabContainer", Palette.PAPER_LIGHT)
	theme.set_constant("side_margin", "TabContainer", 0)


func _misc() -> void:
	theme.set_stylebox("panel", "TooltipPanel", box(Palette.INK_SOFT, Palette.WOOD, 2, 12, 6))
	theme.set_color("font_color", "TooltipLabel", Palette.PAPER_LIGHT)
	var grabber := box(Palette.WOOD)
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", box(Palette.OCHRE_DARK))
	theme.set_stylebox("grabber_pressed", "VScrollBar", box(Palette.OCHRE))
	theme.set_stylebox("scroll", "VScrollBar", box(Color(Palette.INK, 0.2), Color.TRANSPARENT, 0, 6, 0))
