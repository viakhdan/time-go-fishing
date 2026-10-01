extends Control
## Contact sheet for art review: every fish on dark and parchment, as a
## silhouette and at hold-slot size, plus the backgrounds. Needs a window:
##   <godot_console> --path . res://tests/ArtPreview.tscn -- --out=C:/some/dir

const COLUMNS := 2
const CELL := Vector2(900, 190)
## Fish per sheet page (the window fits 5 rows of 2).
const PER_PAGE := 10


func _ready() -> void:
	var out := "user://art_preview"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1920, 1080)
	var bg := ColorRect.new()
	bg.color = Palette.INK_SOFT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var ids: Array = GameData._fish.keys()
	for page in ceili(ids.size() / float(PER_PAGE)):
		for c in get_children():
			if c != bg:
				c.queue_free()
		for j in PER_PAGE:
			var i := page * PER_PAGE + j
			if i >= ids.size():
				break
			var cell := Vector2(40 + (j % COLUMNS) * (CELL.x + 40), 30 + (j / COLUMNS) * (CELL.y + 20))
			_add_fish(ids[i], cell)
		await _capture("%s/fish_sheet_%d.png" % [out, page + 1])

	for zone_id in ["lake", "river", "sea", "harbour"]:
		bg.color = Palette.INK
		for c in get_children():
			if c != bg:
				c.queue_free()
		var path: String = GameData.zone(zone_id).background if GameData.has_zone(zone_id) else "res://art/backgrounds/%s.svg" % zone_id
		if ResourceLoader.exists(path):
			var tex := TextureRect.new()
			tex.texture = load(path)
			tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			add_child(tex)
			await _capture("%s/bg_%s.png" % [out, zone_id])
	get_tree().quit()


func _add_fish(id: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = id
	label.position = at + Vector2(0, -4)
	add_child(label)
	for j in 3:
		var backdrop := ColorRect.new()
		backdrop.color = [Palette.INK, Palette.PAPER_DARK, Palette.PAPER_DARK][j]
		backdrop.position = at + Vector2(j * 270, 26)
		backdrop.size = Vector2(260, 140)
		add_child(backdrop)
		var pic := FishPicture.new()
		pic.position = backdrop.position + Vector2(5, 5)
		pic.size = Vector2(250, 130)
		add_child(pic)
		pic.setup(id, j != 2)
	var slot := ColorRect.new()
	slot.color = Palette.MAROON_DARK
	slot.position = at + Vector2(810, 96)
	slot.size = Vector2(88, 70)
	add_child(slot)
	var small := FishPicture.new()
	small.position = slot.position + Vector2(2, 10)
	small.size = Vector2(84, 46)
	add_child(small)
	small.setup(id)


func _capture(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
