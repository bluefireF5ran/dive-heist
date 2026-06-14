extends Node
## Global achievement tracker (autoload "Achievements").
## Persists unlocked achievements + lifetime stats to user:// via ConfigFile.
## Gameplay reports events through the notify_* methods; unlocking fires a toast.

signal achievement_unlocked(id: String, title: String)

const SAVE_PATH := "user://dive_heist_save.cfg"
const TOAST_SCRIPT := preload("res://Scenes/UI/achievement_toast.gd")

## id -> {title, desc}. ORDER controls display order in the menu.
const CATALOG := {
	"first_kill": {"title": "First Blood", "desc": "Defeat your first enemy."},
	"combo_10": {"title": "Chain Reaction", "desc": "Reach a x10 combo."},
	"combo_25": {"title": "Unstoppable", "desc": "Reach a x25 combo."},
	"combo_50": {"title": "Bullet Ballet", "desc": "Reach a x50 combo."},
	"depth_500": {"title": "Going Down", "desc": "Descend 500m in one run."},
	"depth_1500": {"title": "Deep Diver", "desc": "Descend 1500m in one run."},
	"depth_3000": {"title": "The Abyss", "desc": "Descend 3000m in one run."},
	"level_1": {"title": "Breakout", "desc": "Complete the prison (level 1)."},
	"factory": {"title": "Factory Floor", "desc": "Reach the factory (level 2)."},
	"kills_100": {"title": "Exterminator", "desc": "Defeat 100 enemies total."},
	"kills_1000": {"title": "Rampage", "desc": "Defeat 1000 enemies total."},
	"money_500": {"title": "Big Heist", "desc": "Collect $500 total."},
	"rich": {"title": "High Roller", "desc": "Hold $50 at once."},
	"gun_nut": {"title": "Gun Nut", "desc": "Use 5 different weapons."},
	"perks_5": {"title": "Loaded Out", "desc": "Hold 5 perks in one run."},
	"first_death": {"title": "Welcome to the Heist", "desc": "Die for the first time."},
	"untouchable": {"title": "Untouchable", "desc": "Clear a level without taking damage."},
}

const ORDER := [
	"first_kill", "combo_10", "combo_25", "combo_50",
	"depth_500", "depth_1500", "depth_3000",
	"level_1", "factory",
	"kills_100", "kills_1000", "money_500", "rich",
	"gun_nut", "perks_5", "first_death", "untouchable",
]

var _unlocked := {}  # id -> true
var _stats := {
	"total_kills": 0,
	"total_money": 0,
	"deaths": 0,
	"weapons_used": [],
	"best_depth": 0,
	"best_combo": 0,
	"best_level": 1,
}


func _ready() -> void:
	_load()


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func get_stat(key: String) -> Variant:
	return _stats.get(key, 0)


func unlock(id: String) -> void:
	if _unlocked.has(id) or not CATALOG.has(id):
		return
	_unlocked[id] = true
	_save()
	var title: String = CATALOG[id]["title"]
	achievement_unlocked.emit(id, title)
	_show_toast(title)


# ---- Event API (called from gameplay) ----

func notify_combo(combo: int) -> void:
	if combo > int(_stats["best_combo"]):
		_stats["best_combo"] = combo
	if combo >= 1:
		unlock("first_kill")
	if combo >= 10:
		unlock("combo_10")
	if combo >= 25:
		unlock("combo_25")
	if combo >= 50:
		unlock("combo_50")


func notify_depth(depth: int) -> void:
	if depth > int(_stats["best_depth"]):
		_stats["best_depth"] = depth
	if depth >= 500:
		unlock("depth_500")
	if depth >= 1500:
		unlock("depth_1500")
	if depth >= 3000:
		unlock("depth_3000")


func notify_money_held(amount: int) -> void:
	if amount >= 50:
		unlock("rich")


func notify_weapon(weapon_name: String) -> void:
	var used: Array = _stats["weapons_used"]
	if weapon_name != "" and not used.has(weapon_name):
		used.append(weapon_name)
		_save()
	if used.size() >= 5:
		unlock("gun_nut")


func notify_level_complete(level: int) -> void:
	if level > int(_stats["best_level"]):
		_stats["best_level"] = level
	unlock("level_1")
	_save()


func notify_level_reached(level: int) -> void:
	if level > int(_stats["best_level"]):
		_stats["best_level"] = level
	if level >= 2:
		unlock("factory")


func notify_perks(count: int) -> void:
	if count >= 5:
		unlock("perks_5")


func notify_untouchable() -> void:
	unlock("untouchable")


func notify_death(run_kills: int, run_money: int) -> void:
	_stats["deaths"] = int(_stats["deaths"]) + 1
	_stats["total_kills"] = int(_stats["total_kills"]) + run_kills
	_stats["total_money"] = int(_stats["total_money"]) + run_money
	unlock("first_death")
	if int(_stats["total_kills"]) >= 100:
		unlock("kills_100")
	if int(_stats["total_kills"]) >= 1000:
		unlock("kills_1000")
	if int(_stats["total_money"]) >= 500:
		unlock("money_500")
	_save()


# ---- Persistence ----

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("achievements", "unlocked", _unlocked.keys())
	for k: String in _stats:
		cf.set_value("stats", k, _stats[k])
	cf.save(SAVE_PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	for id: String in cf.get_value("achievements", "unlocked", []):
		_unlocked[id] = true
	for k: String in _stats.keys():
		_stats[k] = cf.get_value("stats", k, _stats[k])


func _show_toast(title: String) -> void:
	var toast := TOAST_SCRIPT.new()
	toast.pending_title = title
	add_child(toast)
