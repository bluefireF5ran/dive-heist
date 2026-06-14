extends "res://Scenes/Rooms/base_room.gd"
## Chest room. Picks one of several distinct treasure-room variants at random, each
## with its own theme and mini-challenge, and builds its interior in code on top of
## the shared shell (walls / ceiling / floor / spawn / exit / spike overlay).
##
## The shell scene (money_stance.tscn) still provides: walls, a solid bottom floor,
## a SpikeFloor overlay (toggled per variant), SpawnPoint (bottom-left) and ExitDoor
## (bottom-right). We strip the authored platforms/crate and rebuild per variant.

const GEM_CRATE := preload("res://Scenes/Collectibles/gem_crate.tscn")
const PLAT_TEX := preload("res://Sprites/Active_Sprites/tiles/prison_ground/Tile_02.png")
const FONT := preload("res://Sprites/Active_Sprites/ui/font/CyberpunkCraftpixPixel.otf")

# Variant ids.
enum {VAULT, SPIKE_CROSSING, CRUMBLING, GREED_TOWER, MIMIC, GALLERY}

@onready var spike_floor: Area2D = $SpikeFloor

var _spike_active := false


func _ready() -> void:
	super()
	# Strip the scene's authored interior; we rebuild it per variant.
	for n in ["Plat1", "Plat2", "Plat3", "Plat4", "Plat5", "GemCrate"]:
		var node := get_node_or_null(n)
		if node:
			node.queue_free()
	spike_floor.body_entered.connect(_on_spike_entered)

	# Footing at the entrance and exit so every variant is enterable/exitable.
	_platform(36.0, -24.0, 44.0)
	_platform(290.0, -24.0, 44.0)

	match _rng.randi() % 6:
		VAULT: _build_vault()
		SPIKE_CROSSING: _build_spike_crossing()
		CRUMBLING: _build_crumbling()
		GREED_TOWER: _build_greed_tower()
		MIMIC: _build_mimic()
		GALLERY: _build_gallery()


# --- Variants -----------------------------------------------------------------

## VAULT — generous, easy. Climb a small stair to a big jackpot crate, grab the
## side loot on the way. Safe floor.
func _build_vault() -> void:
	_set_spikes(false)
	_label("VAULT", Color(1.0, 0.85, 0.3))
	_platform(96.0, -54.0, 42.0)
	_platform(160.0, -94.0, 46.0)
	_platform(224.0, -54.0, 42.0)
	_crate(160.0, -112.0, _rng.randi_range(22, 30))  # jackpot on top
	_crate(96.0, -70.0, _rng.randi_range(7, 10))
	_crate(224.0, -70.0, _rng.randi_range(7, 10))
	_crate(60.0, -18.0, _rng.randi_range(6, 9))
	_crate(260.0, -18.0, _rng.randi_range(6, 9))


## SPIKE CROSSING — the floor is lethal; hop a zig-zag of small stones to the
## apex crate and back. Mistime a jump and you eat the spikes.
func _build_spike_crossing() -> void:
	_set_spikes(true)
	_label("CROSSING", Color(1.0, 0.4, 0.3))
	_platform(92.0, -52.0, 26.0)
	_platform(140.0, -86.0, 26.0)
	_platform(190.0, -58.0, 26.0)
	_platform(238.0, -42.0, 26.0)
	_crate(140.0, -104.0, _rng.randi_range(13, 17))
	_crate(238.0, -60.0, _rng.randi_range(6, 9))


## CRUMBLING HOARD — crates sit on platforms that crumble seconds after you land.
## Grab and move before they drop you into the spikes below.
func _build_crumbling() -> void:
	_set_spikes(true)
	_label("CRUMBLING", Color(0.95, 0.7, 0.3))
	var spots := [Vector2(96.0, -52.0), Vector2(150.0, -86.0), Vector2(204.0, -52.0), Vector2(150.0, -120.0)]
	for s in spots:
		_crumble(s.x, s.y, 30.0)
		_crate(s.x, s.y - 18.0, _rng.randi_range(6, 9))


## GREED TOWER — a vertical stack of ledges over a spike pit. Each crate higher is
## worth more; climb as high as you dare, but a fall costs HP.
func _build_greed_tower() -> void:
	_set_spikes(true)
	_label("GREED", Color(0.6, 1.0, 0.5))
	_platform(96.0, -46.0, 32.0)   # step up from spawn ledge
	_platform(210.0, -46.0, 32.0)  # step down to exit ledge
	var rungs := [Vector2(160.0, -50.0), Vector2(160.0, -90.0), Vector2(160.0, -130.0), Vector2(160.0, -166.0)]
	var values := [6, 11, 16, 24]
	for i in range(rungs.size()):
		_platform(rungs[i].x, rungs[i].y, 28.0)
		_crate(rungs[i].x, rungs[i].y - 16.0, values[i])


## MIMIC GAMBLE — a spread of identical chests; one or two bite back. Stomping is
## fast but risky up close; shooting from range is safe. Safe floor.
func _build_mimic() -> void:
	_set_spikes(false)
	_label("MIMIC?", Color(0.9, 0.5, 0.9))
	var spots := [
		Vector2(56.0, -18.0), Vector2(104.0, -18.0), Vector2(152.0, -18.0),
		Vector2(200.0, -18.0), Vector2(248.0, -18.0),
	]
	_platform(152.0, -72.0, 64.0)
	spots.append(Vector2(126.0, -88.0))
	spots.append(Vector2(178.0, -88.0))
	var idx: Array[int] = []
	for i in range(spots.size()):
		idx.append(i)
	idx.shuffle()
	var mimics := {idx[0]: true, idx[1]: true}  # two traps
	for i in range(spots.size()):
		var trap: bool = mimics.has(i)
		_crate(spots[i].x, spots[i].y, (0 if trap else _rng.randi_range(8, 12)), trap)


## SHOOTING GALLERY — caches float out of jumping reach over a safe floor; shoot
## them down and collect the spilled loot below.
func _build_gallery() -> void:
	_set_spikes(false)
	_label("GALLERY", Color(0.4, 0.85, 1.0))
	var spots := [
		Vector2(70.0, -92.0), Vector2(120.0, -132.0), Vector2(170.0, -100.0),
		Vector2(220.0, -138.0), Vector2(268.0, -96.0), Vector2(160.0, -164.0),
	]
	for s in spots:
		_crate(s.x, s.y, _rng.randi_range(8, 12))


# --- Building blocks ----------------------------------------------------------

## A one-way platform with a tiled visual; returns the body.
func _platform(x: float, y: float, w: float) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.position = Vector2(x, y)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, 16.0)
	col.shape = shape
	col.one_way_collision = true
	b.add_child(col)
	var v := Sprite2D.new()
	v.texture = PLAT_TEX
	v.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	v.region_enabled = true
	v.region_rect = Rect2(0, 0, w, 16.0)
	b.add_child(v)
	add_child(b)
	return b


func _crate(x: float, y: float, money: int, mimic: bool = false) -> StaticBody2D:
	var c := GEM_CRATE.instantiate()
	c.position = Vector2(x, y)
	c.money_count = money
	c.is_mimic = mimic
	add_child(c)
	return c


## A platform that crumbles (and drops the player) shortly after they step on it.
func _crumble(x: float, y: float, w: float) -> StaticBody2D:
	var b := _platform(x, y, w)
	var det := Area2D.new()
	det.collision_layer = 0
	det.collision_mask = 2  # player
	var ds := CollisionShape2D.new()
	var dr := RectangleShape2D.new()
	dr.size = Vector2(w, 12.0)
	ds.shape = dr
	ds.position = Vector2(0, -12.0)
	det.add_child(ds)
	b.add_child(det)
	det.body_entered.connect(_on_crumble_touch.bind(b))
	return b


func _on_crumble_touch(body: Node2D, plat: StaticBody2D) -> void:
	if body.is_in_group("player"):
		_start_crumble(plat)


func _start_crumble(plat: StaticBody2D) -> void:
	if not is_instance_valid(plat) or plat.has_meta("crumbling"):
		return
	plat.set_meta("crumbling", true)
	var tw := create_tween()
	tw.set_loops(3)
	tw.tween_property(plat, "modulate", Color(1.7, 0.6, 0.6, 1.0), 0.1)
	tw.tween_property(plat, "modulate", Color(1, 1, 1, 1), 0.1)
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(plat):
		plat.queue_free()


## Toggle the floor spikes (overlay damage + red visual) for this variant.
func _set_spikes(active: bool) -> void:
	_spike_active = active
	spike_floor.monitoring = active
	var vis := spike_floor.get_node_or_null("Visual") as CanvasItem
	if vis:
		vis.visible = active


func _on_spike_entered(body: Node2D) -> void:
	if _spike_active and body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)


## A small header label naming the room's theme.
func _label(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", color)
	l.position = Vector2(12.0, -190.0)
	l.z_index = 1
	add_child(l)
