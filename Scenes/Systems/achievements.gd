extends Node
## Global achievement tracker (autoload "Achievements").
## Persists unlocked achievements + lifetime stats to user:// via ConfigFile.
## Gameplay reports events through the notify_* methods; unlocking fires a toast.

signal achievement_unlocked(id: String, title: String)

const SAVE_PATH := "user://dive_heist_save.cfg"
const TOAST_SCRIPT := preload("res://Scenes/UI/achievement_toast.gd")

## id -> {title, desc}. ORDER controls display order in the menu.
const CATALOG := {
	# Combat & combo
	"first_kill": {"title": "First Blood", "desc": "Defeat your first enemy."},
	"combo_10": {"title": "Chain Reaction", "desc": "Reach a x10 combo."},
	"combo_25": {"title": "Unstoppable", "desc": "Reach a x25 combo."},
	"combo_50": {"title": "Bullet Ballet", "desc": "Reach a x50 combo."},
	"combo_100": {"title": "Combo Deity", "desc": "Reach a x100 combo."},
	# Score (run)
	"score_25k": {"title": "Combo Artist", "desc": "Score 25,000 in one run."},
	"score_60k": {"title": "A-Rank Run", "desc": "Score 60,000 in one run."},
	"score_120k": {"title": "S-Rank Legend", "desc": "Score 120,000 in one run."},
	# Depth
	"depth_500": {"title": "Going Down", "desc": "Descend 500m in one run."},
	"depth_1500": {"title": "Deep Diver", "desc": "Descend 1500m in one run."},
	"depth_3000": {"title": "The Abyss", "desc": "Descend 3000m in one run."},
	# Progression & bosses
	"first_level": {"title": "Breakout", "desc": "Complete your first level."},
	"warden": {"title": "Warden Down", "desc": "Defeat the Warden (prison boss)."},
	"factory": {"title": "Factory Floor", "desc": "Reach the factory (level 4)."},
	"loader": {"title": "Scrapped", "desc": "Defeat the Loader (factory boss)."},
	"demo_clear": {"title": "The Big Score", "desc": "Clear the demo."},
	"flawless": {"title": "Flawless", "desc": "Beat a boss without taking damage."},
	# Economy & loot
	"rich": {"title": "High Roller", "desc": "Hold $50 at once."},
	"money_500": {"title": "Big Heist", "desc": "Collect $500 total."},
	"treasure": {"title": "Treasure Hunter", "desc": "Open 25 chests (lifetime)."},
	"mimic": {"title": "Bamboozled", "desc": "Open a mimic chest."},
	# Loadout
	"gun_nut": {"title": "Gun Nut", "desc": "Use 5 different weapons."},
	"perks_5": {"title": "Loaded Out", "desc": "Hold 5 perks in one run."},
	"perks_8": {"title": "Fully Augmented", "desc": "Hold 8 perks in one run."},
	"bulletproof": {"title": "Bulletproof", "desc": "Gain a shield."},
	# Kills (lifetime)
	"kills_100": {"title": "Exterminator", "desc": "Defeat 100 enemies total."},
	"kills_1000": {"title": "Rampage", "desc": "Defeat 1000 enemies total."},
	# Meta
	"first_death": {"title": "Welcome to the Heist", "desc": "Die for the first time."},
	"untouchable": {"title": "Untouchable", "desc": "Clear a level without taking damage."},
}

const ORDER := [
	"first_kill", "combo_10", "combo_25", "combo_50", "combo_100",
	"score_25k", "score_60k", "score_120k",
	"depth_500", "depth_1500", "depth_3000",
	"first_level", "warden", "factory", "loader", "demo_clear", "flawless",
	"rich", "money_500", "treasure", "mimic",
	"gun_nut", "perks_5", "perks_8", "bulletproof",
	"kills_100", "kills_1000",
	"first_death", "untouchable",
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
	"best_score": 0,
	"chests_opened": 0,
	"bosses_defeated": 0,
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
	if combo >= 100:
		unlock("combo_100")


func notify_score(score: int) -> void:
	if score > int(_stats["best_score"]):
		_stats["best_score"] = score
	if score >= 25000:
		unlock("score_25k")
	if score >= 60000:
		unlock("score_60k")
	if score >= 120000:
		unlock("score_120k")


func notify_boss_defeated(boss_id: String) -> void:
	_stats["bosses_defeated"] = int(_stats["bosses_defeated"]) + 1
	if boss_id == "WARDEN":
		unlock("warden")
	elif boss_id == "LOADER":
		unlock("loader")
	_save()


func notify_flawless_boss() -> void:
	unlock("flawless")


func notify_demo_complete() -> void:
	unlock("demo_clear")


func notify_chest_opened() -> void:
	_stats["chests_opened"] = int(_stats["chests_opened"]) + 1
	if int(_stats["chests_opened"]) >= 25:
		unlock("treasure")
	_save()


func notify_mimic_opened() -> void:
	unlock("mimic")


func notify_shield_gained() -> void:
	unlock("bulletproof")


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
	unlock("first_level")
	_save()


func notify_level_reached(level: int) -> void:
	if level > int(_stats["best_level"]):
		_stats["best_level"] = level
	if level >= 4:
		unlock("factory")


func notify_perks(count: int) -> void:
	if count >= 5:
		unlock("perks_5")
	if count >= 8:
		unlock("perks_8")


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
