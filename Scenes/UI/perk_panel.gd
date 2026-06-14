extends Control
## Renders the perk selection cards. Reads state from its parent (perk_select.gd),
## mirroring the ammo_hud/ammo_bar pattern.

var _font: Font


func _ready() -> void:
	_font = load(
		"res://Sprites/Active_Sprites/ui/font/CyberpunkCraftpixPixel.otf"
	)
	_build_icons()


## Create one TextureRect per card for the perk icon. We use real nodes instead of
## draw_texture_rect (which renders these imported textures as blank white squares).
## Layout matches _draw exactly; cards never move, so this only runs once.
func _build_icons() -> void:
	var parent := get_parent()
	var perks: Array = parent.perks
	if perks.is_empty():
		return
	var vp := get_viewport_rect().size
	var cy := vp.y / 2.0
	var count := perks.size()
	var gap := 6.0
	var total_w := vp.x - 20.0
	var card_w := (total_w - gap * (count - 1)) / count
	var card_y := cy + 40.0
	var start_x := 10.0
	for i in range(count):
		var perk: Dictionary = perks[i]
		var path: String = perk.get("icon", "")
		if path == "":
			continue
		var tex: Texture2D = load(path)
		if not tex:
			continue
		var cx := start_x + i * (card_w + gap)
		var ic := TextureRect.new()
		ic.texture = tex
		ic.position = Vector2(cx + card_w / 2.0 - 12.0, card_y + 8.0)
		ic.size = Vector2(24.0, 24.0)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ic)


func _draw() -> void:
	var parent := get_parent()
	var perks: Array = parent.perks
	if perks.is_empty():
		return
	var selected: int = parent.selected
	var vp := get_viewport_rect().size
	var cy := vp.y / 2.0

	# Header
	var header := "CHOOSE AN UPGRADE"
	var hsize := _font.get_string_size(header, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	var hx := (vp.x - hsize.x) / 2.0
	var hy := cy + 26.0
	draw_string(_font, Vector2(hx + 1, hy + 1), header, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(0, 0, 0, 0.8))
	draw_string(_font, Vector2(hx, hy), header, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 1, 1))

	# Cards
	var count := perks.size()
	var gap := 6.0
	var total_w := vp.x - 20.0
	var card_w := (total_w - gap * (count - 1)) / count
	var card_h := 120.0
	var start_x := 10.0
	var card_y := cy + 40.0

	for i in range(count):
		var perk: Dictionary = perks[i]
		var cx := start_x + i * (card_w + gap)
		var rect := Rect2(cx, card_y, card_w, card_h)
		var is_sel := i == selected
		var perk_color: Color = perk["color"]

		# Card background
		var bg := Color(0.12, 0.12, 0.16, 0.95) if is_sel else Color(0.06, 0.06, 0.09, 0.9)
		draw_rect(rect, bg)
		# Border — bright + thick when selected
		var border := perk_color if is_sel else Color(0.3, 0.3, 0.35, 0.9)
		draw_rect(rect, border, false, 2.0 if is_sel else 1.0)
		if is_sel:
			# Selection glow strip at top
			draw_rect(Rect2(cx, card_y, card_w, 4.0), perk_color)

		# (Icons are drawn as TextureRect child nodes — see _build_icons — because
		# draw_texture_rect renders these imported textures as blank white squares.)

		# Title (wrapped, colored)
		var title: String = perk["title"]
		draw_multiline_string(
			_font,
			Vector2(cx + 4, card_y + 46),
			title,
			HORIZONTAL_ALIGNMENT_CENTER,
			card_w - 8,
			9,
			3,
			perk_color
		)
		# Description (wrapped, grey/white)
		var desc: String = perk["desc"]
		var desc_color := Color(0.85, 0.85, 0.85) if is_sel else Color(0.55, 0.55, 0.6)
		draw_multiline_string(
			_font,
			Vector2(cx + 4, card_y + 84),
			desc,
			HORIZONTAL_ALIGNMENT_CENTER,
			card_w - 8,
			8,
			4,
			desc_color
		)

	# Prompt
	var prompt := "< >  SELECT      JUMP  CONFIRM"
	var psize := _font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_CENTER, -1, 8)
	var px := (vp.x - psize.x) / 2.0
	var py := card_y + card_h + 16.0
	draw_string(_font, Vector2(px, py), prompt, HORIZONTAL_ALIGNMENT_CENTER, -1, 8, Color(0.7, 0.7, 0.7))
