extends CanvasLayer
## End-of-level perk selection (Downwell-style). Shows a choice of upgrade cards
## over the level-complete screen. Navigate with left/right, confirm with jump or
## interact. Emits perk_chosen(id); the world applies it via player.apply_perk().
##
## Built entirely in code (no .tscn). A child Control (PerkPanel) renders the
## cards by reading this node's state, mirroring the ammo_hud/ammo_bar pattern.

signal perk_chosen(perk_id: String)

## All available perks. apply_perk() in player.gd implements each id.
const CATALOG := [
	{
		"id": "max_hp",
		"title": "REINFORCED HULL",
		"desc": "+1 Max HP\n& full heal",
		"color": Color(0.85, 0.2, 0.2),
	},
	{
		"id": "max_ammo",
		"title": "EXTENDED MAG",
		"desc": "+2 Max Ammo",
		"color": Color(0.2, 0.6, 1.0),
	},
	{
		"id": "fire_rate",
		"title": "HAIR TRIGGER",
		"desc": "Fire 20%\nfaster",
		"color": Color(0.6, 0.9, 0.3),
	},
	{
		"id": "magnet",
		"title": "COIN MAGNET",
		"desc": "Pull coins\nfrom afar",
		"color": Color(0.9, 0.8, 0.2),
	},
	{
		"id": "profiteer",
		"title": "PROFITEER",
		"desc": "+1 money\nper coin",
		"color": Color(0.95, 0.6, 0.15),
	},
	{
		"id": "swift",
		"title": "SWIFT BOOTS",
		"desc": "+18% move\nspeed",
		"color": Color(0.4, 0.9, 0.9),
	},
	{
		"id": "high_jump",
		"title": "SPRING LEGS",
		"desc": "+15% jump\nheight",
		"color": Color(0.6, 1.0, 0.5),
	},
	{
		"id": "sharpshooter",
		"title": "SHARPSHOOTER",
		"desc": "+1 bullet\ndamage",
		"color": Color(0.8, 0.7, 1.0),
	},
	{
		"id": "glass_cannon",
		"title": "GLASS CANNON",
		"desc": "+2 damage\n-1 Max HP",
		"color": Color(1.0, 0.35, 0.35),
	},
	{
		"id": "adrenaline",
		"title": "ADRENALINE",
		"desc": "Longer i-frames\nwhen hit",
		"color": Color(1.0, 0.5, 0.7),
	},
	{
		"id": "vampire",
		"title": "VAMPIRE",
		"desc": "Heal on every\ncombo cash-in",
		"color": Color(0.7, 0.1, 0.2),
	},
	{
		"id": "blast",
		"title": "BLAST STOMP",
		"desc": "Stomps blast\nnearby foes",
		"color": Color(1.0, 0.5, 0.15),
	},
	{
		"id": "gem_power",
		"title": "GEM POWER",
		"desc": "Coins refill\nammo",
		"color": Color(0.3, 0.9, 0.9),
	},
	{
		"id": "popping",
		"title": "POPPING GEMS",
		"desc": "Coins fire a\nshot upward",
		"color": Color(0.95, 0.85, 0.3),
	},
	{
		"id": "jetpack",
		"title": "JETPACK",
		"desc": "Hover when\nout of ammo",
		"color": Color(0.5, 0.7, 1.0),
	},
	{
		"id": "youth",
		"title": "YOUTH",
		"desc": "+1 perk choice\n& +1 HP",
		"color": Color(0.6, 1.0, 0.5),
	},
]

const PANEL_SCRIPT := preload("res://Scenes/UI/perk_panel.gd")

## Per-perk icon (Cyberpunk_Assets/Icons), chosen so the depicted object matches
## the mechanic. Read by perk_panel.gd / world.gd. Leans on the cyberpunk Implants
## set (cyber heart/limbs/eye/blood) since it fits this game's theme best.
const _ICON_DIR := "res://Sprites/Active_Sprites/icons/"
const PERK_ICONS := {
	"max_hp": _ICON_DIR + "perk_max_hp.png",  # armoured cyber-chest -> reinforced hull
	"max_ammo": _ICON_DIR + "perk_max_ammo.png",  # ammo magazine
	"fire_rate": _ICON_DIR + "perk_fire_rate.png",  # gear -> faster mechanism
	"magnet": _ICON_DIR + "perk_magnet.png",  # horseshoe magnet
	"profiteer": _ICON_DIR + "perk_profiteer.png",  # stack of cash
	"swift": _ICON_DIR + "perk_swift.png",  # cyber boot -> move speed
	"high_jump": _ICON_DIR + "perk_high_jump.png",  # cyber leg -> spring legs
	"sharpshooter": _ICON_DIR + "perk_sharpshooter.png",  # cyber eye -> aim/damage
	"glass_cannon": _ICON_DIR + "perk_glass_cannon.png",  # heavy rifle
	"adrenaline": _ICON_DIR + "perk_adrenaline.png",  # auto-injector -> adrenaline shot
	"vampire": _ICON_DIR + "perk_vampire.png",  # vial of blood
	"blast": _ICON_DIR + "perk_blast.png",  # grenade -> blast
	"gem_power": _ICON_DIR + "perk_gem_power.png",  # gem/diamond
	"popping": _ICON_DIR + "perk_popping.png",  # star burst -> popping shot
	"jetpack": _ICON_DIR + "perk_jetpack.png",  # hovering rotor drone
	"youth": _ICON_DIR + "perk_youth.png",  # DNA helix -> rejuvenation
}

var perks: Array = []
var selected := 0
var _done := false
var _panel: Control
const CONFIRM_DELAY_MS := 500.0  # Ignore confirm briefly so the level-clear jump doesn't auto-pick
var _opened_ms := 0.0


func _ready() -> void:
	layer = 50  # Above the HUD (CanvasLayer layer 1)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_opened_ms = Time.get_ticks_msec()
	if perks.is_empty():
		# Youth perk raises how many cards are offered.
		var count := 3
		var p := get_tree().get_first_node_in_group("player")
		if p and "perk_choices" in p:
			count = maxi(int(p.perk_choices), 2)
		perks = _pick_perks(count)
	_panel = Control.new()
	_panel.set_script(PANEL_SCRIPT)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)


## Pick `count` distinct perks at random, excluding any the player already owns so
## a picked perk doesn't show up again. Falls back to the full list only if every
## perk is already owned (so there's always something to choose).
func _pick_perks(count: int) -> Array:
	var owned: Array = []
	var p := get_tree().get_first_node_in_group("player")
	if p and "perks" in p:
		owned = p.perks
	var pool: Array = []
	for d: Dictionary in CATALOG:
		if not owned.has(d["id"]):
			pool.append(d)
	if pool.is_empty():
		pool = CATALOG.duplicate()
	pool.shuffle()
	# Duplicate each chosen entry and bake in its icon path so the renderer
	# (perk_panel) can read perk["icon"] directly. It can't reach this script's
	# PERK_ICONS constant through its parent reference (constants aren't accessible
	# via a dynamically-typed instance), so resolve it here where we own the const.
	var chosen: Array = []
	for d: Dictionary in pool.slice(0, mini(count, pool.size())):
		var e: Dictionary = d.duplicate()
		e["icon"] = PERK_ICONS.get(d["id"], "")
		chosen.append(e)
	return chosen


func _input(event: InputEvent) -> void:
	if _done or perks.is_empty():
		return
	if event.is_action_pressed("move_left"):
		selected = (selected - 1 + perks.size()) % perks.size()
		SFX.play(SFX.combo_increase, -14.0, 0.9)
		_panel.queue_redraw()
	elif event.is_action_pressed("move_right"):
		selected = (selected + 1) % perks.size()
		SFX.play(SFX.combo_increase, -14.0, 0.9)
		_panel.queue_redraw()
	elif event.is_action_pressed("jump") or event.is_action_pressed("interact"):
		if Time.get_ticks_msec() - _opened_ms < CONFIRM_DELAY_MS:
			return  # too soon — avoid accidentally skipping the perk choice
		_confirm()


func _confirm() -> void:
	if _done:
		return
	_done = true
	var id: String = perks[selected]["id"]
	SFX.play(SFX.combo_tier_2, -6.0)
	perk_chosen.emit(id)
	queue_free()
