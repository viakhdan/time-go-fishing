class_name FishPicture
extends Control
## Draws a fish: its sprite if the art exists, otherwise a faceted placeholder
## fish in the rarity colour (flat 2-tone shading, ART_STYLE.md §4). Unknown
## fish are drawn as a solid silhouette (DESIGN.md §8.2, §9.4).

const SIDES := 10  # Low-poly body outline
const SILHOUETTE_SHADER := preload("res://art/ui/silhouette.gdshader")

@export var silhouette_color := Palette.INK_SOFT

var fish_id := ""
var known := true
var _texture: Texture2D


func setup(id: String, is_known := true) -> void:
	fish_id = id
	known = is_known
	var sprite: String = GameData.fish(id).sprite
	_texture = load(sprite) if ResourceLoader.exists(sprite) else null
	# A shader, not modulate: multiplying would leave the markings faintly visible.
	if _texture and not known:
		var mat := ShaderMaterial.new()
		mat.shader = SILHOUETTE_SHADER
		mat.set_shader_parameter("fill_color", silhouette_color)
		material = mat
	else:
		material = null
	queue_redraw()


func _draw() -> void:
	if fish_id.is_empty():
		return
	# Fit a 2:1 box, centred.
	var w := minf(size.x, size.y * 2.0)
	var h := w / 2.0
	var rect := Rect2((size - Vector2(w, h)) / 2.0, Vector2(w, h))
	if _texture:
		draw_texture_rect(_texture, rect, false)
		return
	var base := Color(GameData.rarity_of(fish_id).color) if known else silhouette_color
	_draw_placeholder(rect, base)


func _draw_placeholder(rect: Rect2, base: Color) -> void:
	var c := rect.position + Vector2(rect.size.x * 0.56, rect.size.y * 0.5)
	var rx := rect.size.x * 0.38
	var ry := rect.size.y * 0.36
	var body := PackedVector2Array()
	for i in SIDES:
		var a := TAU * i / SIDES
		body.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	var shade := base.darkened(0.3) if known else base
	var light := base.lightened(0.15) if known else base

	# Tail (fish faces right) and dorsal fin.
	var tail_root := c - Vector2(rx * 0.85, 0)
	var tail_x := rect.position.x + rect.size.x * 0.04
	draw_colored_polygon(PackedVector2Array([tail_root, Vector2(tail_x, c.y - ry * 0.95), Vector2(tail_x + rx * 0.2, c.y), Vector2(tail_x, c.y + ry * 0.95)]), shade)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-rx * 0.35, -ry * 0.8), c + Vector2(rx * 0.05, -ry * 1.45), c + Vector2(rx * 0.35, -ry * 0.85)]), shade)

	# Body: lit upper half, shaded lower half (flat planes, no gradient).
	draw_colored_polygon(body, base)
	var lower := PackedVector2Array([body[0]])
	for i in range(1, SIDES / 2):
		lower.append(body[i])
	lower.append(body[SIDES / 2])
	draw_colored_polygon(lower, shade)
	draw_colored_polygon(PackedVector2Array([body[SIDES / 2 + 1], body[SIDES / 2 + 2], c + Vector2(0, -ry * 0.2)]), light)
	if not known:
		return
	# Big round eye (eerie-cute, §5) and a gill line.
	var eye := c + Vector2(rx * 0.55, -ry * 0.2)
	draw_circle(eye, ry * 0.26, Palette.PAPER_LIGHT)
	draw_circle(eye + Vector2(ry * 0.05, 0), ry * 0.14, Palette.INK_SOFT)
	draw_line(c + Vector2(rx * 0.25, -ry * 0.55), c + Vector2(rx * 0.15, ry * 0.55), shade, maxf(2.0, ry * 0.06))
	draw_polyline(body + PackedVector2Array([body[0]]), shade.darkened(0.3), maxf(1.5, ry * 0.04))
