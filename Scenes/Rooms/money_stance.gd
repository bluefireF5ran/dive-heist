extends "res://Scenes/Rooms/base_room.gd"
## Chest room. Picks one of several distinct treasure-room variants at random and
## builds the interior in code on a clean, code-built floor at a KNOWN height
## (FLOOR_TOP) so crates/platforms never float and the spawn always has footing.
##
## The shell scene provides side walls, ceiling, SpawnPoint, ExitDoor and a spike
## overlay; we strip the authored floor/platforms and lay everything out ourselves.

const GEM_CRATE := preload("res://Scenes/Collectibles/gem_crate.tscn")
const PLAT_TEX := preload("res://Sprites/Active_Sprites/tiles/prison_ground/Tile_02.png")
const FONT := preload("res://Sprites/Active_Sprites/ui/font/CyberpunkCraftpixPixel.otf")
const ARENA_FOE := preload("res://Scenes/Enemies/prisoner.tscn")
const ARENA_FLYER := preload("res://Scenes/Enemies/drone.tscn")

const FLOOR_TOP := 0.0  # World-Y the player stands on; everything is placed off this.
const CRATE_HALF := 16.0  # gem crate is 32px tall

enum {VAULT, SPIKE_CROSSING, CRUMBLING, GREED_TOWER, MIMIC, GALLERY}

@onready var spike_floor: Area2D = $SpikeFloor

var _spike_active := false
var _arena_started := false
var _arena_left := 0


func _ready() -> void:
	super()
	# Strip the scene's authored interior; we rebuild it on our own floor.
	for n in ["Plat1", "Plat2", "Plat3", "Plat4", "Plat5", "GemCrate"]:
		var node := get_node_or_null(n)
		if node:
			node.queue_free()
	# Drop the rotated tscn "BottomWall" floor — we build a clean one at FLOOR_TOP.
	var old_floor := get_node_or_null("LeftWall/BottomWall")
	if old_floor:
		old_floor.queue_free()
	# Disable the tscn spike overlay (it sits below our code floor and never hits the
	# player); spike variants build their own spike strip at the floor surface.
	spike_floor.monitoring = false
	var tscn_spike_vis := spike_floor.get_node_or_null("Visual") as CanvasItem
	if tscn_spike_vis:
		tscn_spike_vis.visible = false

	_solid_floor()
	# Footing at the entrance and exit so every variant is enterable/exitable.
	_ledge(36.0, -28.0, 46.0)
	_ledge(290.0, -28.0, 48.0)

	match _rng.randi() % 6:
		VAULT: _build_vault()
		SPIKE_CROSSING: _build_spike_crossing()
		CRUMBLING: _build_crumbling()
		GREED_TOWER: _build_greed_tower()
		MIMIC: _build_mimic()
		GALLERY: _build_gallery()


# --- Variants -----------------------------------------------------------------

## VAULT — generous and WIDE. Loot spread across the floor + a low stair to a
## jackpot crate. Safe floor.
func _build_vault() -> void:
	_set_spikes(false)
	_label("VAULT", Color(1.0, 0.85, 0.3))
	_ledge(100.0, -54.0, 46.0)
	_ledge(160.0, -96.0, 50.0)
	_ledge(220.0, -54.0, 46.0)
	_crate_on(160.0, -96.0, _rng.randi_range(14, 18))  # jackpot
	_crate_on(100.0, -54.0, _rng.randi_range(5, 7))
	_crate_on(220.0, -54.0, _rng.randi_range(5, 7))
	_crate_on(64.0, FLOOR_TOP, _rng.randi_range(4, 6))
	_crate_on(256.0, FLOOR_TOP, _rng.randi_range(4, 6))


## SPIKE CROSSING — hop a zig-zag of small stones over a lethal floor.
func _build_spike_crossing() -> void:
	_set_spikes(true)
	_label("CROSSING", Color(1.0, 0.4, 0.3))
	_ledge(92.0, -50.0, 26.0)
	_ledge(140.0, -84.0, 26.0)
	_ledge(190.0, -56.0, 26.0)
	_ledge(238.0, -42.0, 26.0)
	_crate_on(140.0, -84.0, _rng.randi_range(13, 17))
	_crate_on(238.0, -42.0, _rng.randi_range(6, 9))


## CRUMBLING — a LONG left-to-right path of crumbling platforms over spikes, ending
## at a solid reward ledge with two chests, then the exit.
func _build_crumbling() -> void:
	_set_spikes(true)
	_label("CRUMBLING", Color(0.95, 0.7, 0.3))
	_crumble(88.0, -46.0, 30.0)
	_crumble(136.0, -64.0, 30.0)
	_crumble(186.0, -50.0, 30.0)
	# Solid reward ledge at the end of the run (doesn't crumble).
	_ledge(244.0, -66.0, 46.0)
	_crate_on(232.0, -66.0, _rng.randi_range(9, 13))
	_crate_on(256.0, -66.0, _rng.randi_range(9, 13))


## GREED TOWER — a tall VERTICAL stack over a spike pit. Higher = richer = riskier.
func _build_greed_tower() -> void:
	_set_spikes(true)
	_label("GREED", Color(0.6, 1.0, 0.5))
	_ledge(96.0, -46.0, 30.0)   # step up from spawn
	_ledge(210.0, -46.0, 30.0)  # step down to exit
	# Three reachable rungs (the old 4th was out of jump range).
	var tops := [-54.0, -94.0, -134.0]
	var values := [6, 10, 16]
	for i in range(tops.size()):
		_ledge(160.0, tops[i], 30.0)
		_crate_on(160.0, tops[i], values[i])


## MIMIC ARENA — chests on the floor, one is a trap. The exit is sealed until you
## open the trap (it bites + summons guards) and clear them. Safe floor.
func _build_mimic() -> void:
	_set_spikes(false)
	_label("AMBUSH", Color(0.9, 0.5, 0.9))
	if exit_door:
		exit_door.visible = false
		exit_door.set_deferred("monitoring", false)
	var xs := [70.0, 120.0, 170.0, 220.0, 270.0]
	var trap_i := _rng.randi() % xs.size()
	for i in range(xs.size()):
		var is_trap: bool = i == trap_i
		var c := _crate_on(xs[i], FLOOR_TOP, (0 if is_trap else _rng.randi_range(8, 12)), is_trap)
		if is_trap:
			c.opened.connect(_on_mimic_opened)


func _on_mimic_opened(_was_mimic: bool) -> void:
	if _arena_started:
		return
	_arena_started = true
	_label("CLEAR THE GUARDS", Color(1.0, 0.4, 0.4))
	SFX.play(SFX.empty_click, -2.0, 0.6)
	var spawns := [
		[ARENA_FOE, Vector2(60.0, -24.0)],
		[ARENA_FOE, Vector2(260.0, -24.0)],
		[ARENA_FLYER, Vector2(120.0, -64.0)],
		[ARENA_FLYER, Vector2(208.0, -72.0)],
	]
	_arena_left = spawns.size()
	for s in spawns:
		var e: Node = (s[0] as PackedScene).instantiate()
		e.position = s[1]
		add_child(e)
		if e.has_signal("died"):
			e.died.connect(_on_arena_enemy_died)


func _on_arena_enemy_died() -> void:
	_arena_left -= 1
	if _arena_left <= 0:
		_label("CLEARED!", Color(0.4, 1.0, 0.5))
		if exit_door:
			exit_door.visible = true
			exit_door.set_deferred("monitoring", true)


## SHOOTING GALLERY — caches float out of jumping reach over a safe floor; shoot
## them down and collect the spilled loot below.
func _build_gallery() -> void:
	_set_spikes(false)
	_label("GALLERY", Color(0.4, 0.85, 1.0))
	for p in [Vector2(70.0, -92.0), Vector2(120.0, -132.0), Vector2(170.0, -100.0),
			Vector2(220.0, -132.0), Vector2(268.0, -96.0)]:
		_crate(p.x, p.y, _rng.randi_range(5, 8))


# --- Building blocks ----------------------------------------------------------

## Full-width solid floor; its top surface is FLOOR_TOP.
func _solid_floor() -> void:
	var b := StaticBody2D.new()
	b.position = Vector2(160.0, FLOOR_TOP + 8.0)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(344.0, 16.0)
	col.shape = shape
	b.add_child(col)
	var v := Sprite2D.new()
	v.texture = PLAT_TEX
	v.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	v.region_enabled = true
	v.region_rect = Rect2(0, 0, 344, 16)
	b.add_child(v)
	add_child(b)


## One-way platform whose TOP surface is at `top`. Returns the body.
func _ledge(x: float, top: float, w: float) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.position = Vector2(x, top + 8.0)
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


## A crate resting on a surface whose top is `surface_top`.
func _crate_on(x: float, surface_top: float, money: int, mimic: bool = false) -> StaticBody2D:
	return _crate(x, surface_top - CRATE_HALF, money, mimic)


func _crate(x: float, y: float, money: int, mimic: bool = false) -> StaticBody2D:
	var c := GEM_CRATE.instantiate()
	c.position = Vector2(x, y)
	c.money_count = money
	c.is_mimic = mimic
	add_child(c)
	return c


## A platform that crumbles (and drops the player) shortly after they step on it.
func _crumble(x: float, top: float, w: float) -> StaticBody2D:
	var b := _ledge(x, top, w)
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


## Enable a spike strip at the floor surface (damage + red sawtooth visual).
func _set_spikes(active: bool) -> void:
	_spike_active = active
	if active:
		_build_spike_floor()


func _build_spike_floor() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # player
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(320.0, 10.0)
	cs.shape = rect
	cs.position = Vector2(160.0, FLOOR_TOP - 2.0)
	area.add_child(cs)
	area.body_entered.connect(_on_spike_entered)
	add_child(area)
	# Red sawtooth along the floor surface.
	var n := 20
	var step := 320.0 / float(n)
	for i in range(n):
		var bx := float(i) * step
		var tri := Polygon2D.new()
		tri.polygon = PackedVector2Array([
			Vector2(bx, FLOOR_TOP),
			Vector2(bx + step, FLOOR_TOP),
			Vector2(bx + step * 0.5, FLOOR_TOP - 8.0),
		])
		tri.color = Color(0.85, 0.18, 0.2, 0.95)
		tri.z_index = 1
		add_child(tri)


func _on_spike_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)


## A small header label naming the room's theme (recreated to update arena state).
func _label(text: String, color: Color) -> void:
	var existing := get_node_or_null("ThemeLabel")
	if existing:
		existing.free()
	var l := Label.new()
	l.name = "ThemeLabel"
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", color)
	l.position = Vector2(12.0, -190.0)
	l.z_index = 1
	add_child(l)
