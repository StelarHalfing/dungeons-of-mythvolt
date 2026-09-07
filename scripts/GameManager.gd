extends Node

# Autoloaded singleton (see project.godot [autoload]).
# Tracks XP/level, the run timer, and every owned weapon's live stats.

signal xp_changed(current: int, needed: int)
signal level_changed(new_level: int)
signal player_died
signal level_up_choices(choices: Array)

var level: int = 1
var xp: int = 0
var xp_to_next: int = 5
var game_time: float = 0.0
var is_paused_for_upgrade: bool = false
var is_menu_paused: bool = false
var is_game_over: bool = false
var enemies_defeated: int = 0
# Level-ups the player has earned but not yet picked an upgrade for.
# Several can land at once (a burst of gems arriving in the same
# physics tick - a magnet pull makes this common - or one RedXPGem
# crossing two thresholds at low level); they're queued here so each
# one gets its own choice panel in turn, instead of every extra
# offer_upgrades() overwriting the panel that's already open and
# silently losing that level's pick.
var pending_level_ups: int = 0

# User preferences and meta-progression. Persist across runs (not
# touched by reset()) and across game restarts (saved to disk).
var show_damage_numbers: bool = true
# Defaults to false so a fresh install (no save file yet) always
# starts windowed - _load_persistent_data() only overwrites this if
# user://save_data.json exists, i.e. only after the player has
# explicitly turned fullscreen on at least once via set_fullscreen().
var is_fullscreen: bool = false
# Frame-rate cap applied to Engine.max_fps; 0 = unlimited (the engine
# default, so a fresh install behaves as before). Always one of
# FPS_CAP_OPTIONS - the settings panels cycle through that list.
var fps_cap: int = 0
const FPS_CAP_OPTIONS := [60, 120, 144, 240, 540, 0]
var coins: int = 0
var permanent_upgrades: Dictionary = {"health_regen": 0, "damage": 0}

const SAVE_PATH := "user://save_data.json"

# Static definition of every permanent (coin-bought) upgrade: display
# info, how much each level is worth, its level cap, and the coin
# cost to buy each level (costs[0] = cost of level 1, costs[1] = cost
# of level 2, etc).
const PERMANENT_UPGRADE_DEFS := {
	"health_regen": {
		"display_name": "Health Regeneration",
		"description": "Permanently regenerate health during every run.",
		"per_level_value": 0.2,
		"max_level": 5,
		"costs": [100, 200, 500, 1000, 2500],
	},
	"damage": {
		"display_name": "Damage",
		"description": "Permanently increase all weapon damage.",
		"per_level_value": 0.10,
		"max_level": 5,
		"costs": [200, 400, 1000, 2000, 5000],
	},
}

# Player-level stats. Passives (PASSIVE_DEFS below) drive these:
# pickup_range_mult is the Attraction Tome's stat (read by XPGem/
# CoinPickup/MagnetPickup), damage_mult is the Power Emblem's (folded
# into every weapon's damage via get_damage_mult()); speed_mult/
# max_hp_bonus are still free hooks for future passives.
var speed_mult: float = 1.0
var max_hp_bonus: float = 0.0
var pickup_range_mult: float = 1.0
var damage_mult: float = 1.0

# Static definition of every weapon: its starting level (0 = not yet
# owned, must be picked once to unlock), base stats, and the flat
# amount added to each stat every time it levels up.
const WEAPON_DEFS := {
	"laser_pistol": {
		"display_name": "Laser Pistol",
		"description": "Auto-fires at the nearest enemy.",
		"start_level": 1,
		"base": {"damage": 10.0, "size": 4.0, "speed": 400.0, "projectile_count": 1.0},
		# damage gain tuned so that at max level (12), projectile_count
		# (5, from +1 every 3rd level) times damage clears a Tank Zombie's
		# 300 HP in one cooldown cycle if every shot could land on the
		# same target - see the level-12 math in chat. Also already
		# one-shots a Zombie (20 HP) well before max level.
		"gain": {"damage": 4.6, "size": 1.0, "speed": 40.0},
		"speed_label": "projectile speed",
		"max_level": 12,
	},
	"forcefield": {
		"display_name": "Forcefield",
		"description": "A ring around you that damages nearby enemies every tick.",
		"start_level": 0,
		"base": {"damage": 10.0, "size": 50.0, "speed": 1.0},
		"gain": {"damage": 4.0, "size": 8.0, "speed": 0.15},
		# speed here is ticks/sec (interval = 1/speed), same as
		# Tornado - see _get_weapon_choice_text().
		"speed_label": "cooldown",
		"max_level": 12,
	},
	"tornado": {
		"display_name": "Tornado",
		"description": "Conjures a wandering vortex on a nearby enemy that damages and drags in everything caught inside.",
		"start_level": 0,
		# duration is base-only (not in gain) - it's deliberately fixed
		# across levels; every 3rd level instead casts an extra
		# simultaneous tornado (projectile_count), same mechanic as
		# Laser Pistol.
		"base": {"damage": 6.0, "size": 55.0, "speed": 0.1, "duration": 2.5, "projectile_count": 1.0},
		# damage gain tuned so max level (12) deals ~half a Tank Zombie's
		# 300 HP (150) over a full 2.5s duration: with Tornado.gd's
		# fixed 0.4s tick interval, that's 6 ticks * 25.0 dmg/tick -
		# see the level-12 math in chat. Zombies (20 HP) stay a fast
		# wipe throughout - killed in 4 ticks at level 1, down to a
		# single tick by level 10+.
		"gain": {"damage": 1.73, "size": 6.0, "speed": 0.02},
		# speed here is casts/sec (cooldown = 1/speed), so the level-up
		# text should show the cooldown getting shorter, not the raw
		# "speed" stat going up - see _get_weapon_choice_text().
		"speed_label": "cooldown",
		"max_level": 12,
	},
	"grenade": {
		"display_name": "Grenade",
		"description": "Lobs a grenade onto a nearby enemy that explodes once for heavy AoE damage.",
		"start_level": 0,
		# damage tuned so a single un-upgraded throw (base raised from 22.0
		# to 35.0 for a punchier early game; first pick applies no gain,
		# see level_up_weapon()) one-shots a Zombie (20 HP), and max level
		# (12) deals ~2/3 of a Tank Zombie's 300 HP (200) in one burst hit:
		# 35.0 + 11 * 15.0 = 200.0 exactly. Gain lowered from 16.1818 to
		# 15.0 so the climb per level is gentler now that base is higher.
		# speed here is casts/sec (cooldown = 1/speed): base 1/15 = 15s
		# cooldown at level 1, gain 13/330 per level so level 12 lands on
		# exactly 2s: 1/15 + 11 * (13/330) = 22/330 + 143/330 = 165/330 =
		# 0.5 -> 1/0.5 = 2.0s. projectile_count gets +1 every 3rd level
		# same as Laser Pistol/Tornado.
		"base": {"damage": 35.0, "size": 60.0, "speed": 1.0 / 15.0, "projectile_count": 1.0},
		"gain": {"damage": 15.0, "size": 5.0, "speed": 13.0 / 330.0},
		"speed_label": "cooldown",
		"max_level": 12,
	},
	"fireball": {
		"display_name": "Fireball",
		"description": "Launches slow fireballs that explode on impact.",
		"start_level": 0,
		# Fired by FireballCaster.gd on its own fixed cooldown; speed here
		# is projectile speed, size is the fireball's radius (blast radius
		# and blast damage derive from size/damage - see Fireball.gd).
		# projectile_count gets +1 every 3rd level like the Laser Pistol.
		"base": {"damage": 25.0, "size": 8.0, "speed": 100.0, "projectile_count": 1.0},
		"gain": {"damage": 5.0, "size": 2.0, "speed": 10.0},
		"speed_label": "speed",
		"max_level": 12,
	},
}

# Live per-weapon stats: weapons[id] = {"level": int, "damage": float, "size": float, "speed": float}
var weapons: Dictionary = {}

# Static definition of every passive (non-weapon) upgrade. Passives sit
# in the same level-up pool as weapons (see offer_upgrades()) but
# instead of their own stats they drive one of the player-level vars
# above: after every level, `stat` is set to base + level *
# per_level_value. Unlike weapons, the first pick already applies one
# step (level 1 = one bonus), since a passive with no effect would be a
# dead pick.
const PASSIVE_DEFS := {
	"attraction_tome": {
		"display_name": "Attraction Tome",
		"description": "Widens the range at which XP gems and coins fly to you.",
		"stat": "pickup_range_mult",
		"stat_label": "pickup range",
		"base": 1.0,
		# +30% pickup range per level: 60px base becomes 78/96/114/132/150,
		# i.e. 2.5x at max level - enough to feel magnetic without making
		# the Magnet pickup pointless.
		"per_level_value": 0.3,
		"max_level": 5,
	},
	"power_emblem": {
		"display_name": "Power Emblem",
		"description": "Every weapon hits harder.",
		"stat": "damage_mult",
		"stat_label": "damage",
		"base": 1.0,
		# +20% per level, x2 damage at max: a real rival to spending the
		# pick on a weapon level (a Laser Pistol level is ~+46% at Lv 2
		# falling to ~+8% by Lv 12), on top of the coin-bought permanent
		# +10%/level - both multiply together in get_damage_mult().
		"per_level_value": 0.2,
		"max_level": 5,
	},
}

# Live passive levels: passives[id] = {"level": int}. 0 = not yet picked.
var passives: Dictionary = {}

func _ready() -> void:
	# Keep ticking (and keep the level-up UI responsive) while the
	# tree is paused for an upgrade choice.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_weapons()
	_init_passives()
	_load_persistent_data()
	_apply_fullscreen()
	_apply_fps_cap()

func _init_weapons() -> void:
	weapons.clear()
	for id in WEAPON_DEFS.keys():
		var def: Dictionary = WEAPON_DEFS[id]
		var stats: Dictionary = def["base"].duplicate()
		stats["level"] = def["start_level"]
		weapons[id] = stats

func _init_passives() -> void:
	passives.clear()
	for id in PASSIVE_DEFS.keys():
		passives[id] = {"level": 0}
		_apply_passive(id)

# Recomputes the player-level stat a passive drives from its current
# level - the single place the level -> stat math lives.
func _apply_passive(id: String) -> void:
	var def: Dictionary = PASSIVE_DEFS[id]
	var passive_level: int = passives[id]["level"]
	set(def["stat"], def["base"] + passive_level * def["per_level_value"])

func _process(delta: float) -> void:
	if not is_paused_for_upgrade and not is_menu_paused and not is_game_over:
		game_time += delta

func reset() -> void:
	level = 1
	xp = 0
	xp_to_next = 5
	game_time = 0.0
	is_paused_for_upgrade = false
	is_menu_paused = false
	is_game_over = false
	enemies_defeated = 0
	pending_level_ups = 0
	speed_mult = 1.0
	max_hp_bonus = 0.0
	pickup_range_mult = 1.0
	damage_mult = 1.0
	_init_weapons()
	_init_passives()

func end_run() -> void:
	is_game_over = true
	player_died.emit()

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(xp_to_next * 1.25) + 3
		level_changed.emit(level)
		pending_level_ups += 1
	xp_changed.emit(xp, xp_to_next)
	# Only open a panel if one isn't already up; choose_upgrade() works
	# through the rest of the queue one pick at a time.
	if pending_level_ups > 0 and not is_paused_for_upgrade:
		offer_upgrades()

# Pauses the game and puts up a choice panel. Returns false (and does
# nothing) when every weapon and passive is already at max level: with
# nothing left to offer, pausing would leave the player stuck on an
# empty panel - the pending level-ups are simply dropped instead.
func offer_upgrades() -> bool:
	var ids: Array = []
	for id in weapons.keys():
		var max_level: int = WEAPON_DEFS[id].get("max_level", -1)
		if max_level < 0 or weapons[id]["level"] < max_level:
			ids.append(id)
	for id in passives.keys():
		if passives[id]["level"] < PASSIVE_DEFS[id]["max_level"]:
			ids.append(id)
	if ids.is_empty():
		pending_level_ups = 0
		return false
	is_paused_for_upgrade = true
	get_tree().paused = true
	ids.shuffle()
	var count: int = min(3, ids.size())
	var choices: Array = ids.slice(0, count)
	level_up_choices.emit(choices)
	return true

func choose_upgrade(id: String) -> void:
	if PASSIVE_DEFS.has(id):
		level_up_passive(id)
	else:
		level_up_weapon(id)
	pending_level_ups = max(pending_level_ups - 1, 0)
	# Another level-up still owed a pick: stay paused and put up the next
	# set of choices right away (unless the pool just ran dry).
	if pending_level_ups > 0 and offer_upgrades():
		return
	is_paused_for_upgrade = false
	get_tree().paused = false

func level_up_weapon(weapon_id: String) -> void:
	var gain: Dictionary = WEAPON_DEFS[weapon_id]["gain"]
	var stats: Dictionary = weapons[weapon_id]
	if stats["level"] <= 0:
		# First pick just unlocks the weapon at its base stats -
		# it hasn't "leveled up" yet, so no gain is applied here.
		stats["level"] = 1
		return
	stats["level"] += 1
	for stat_key in gain.keys():
		stats[stat_key] = stats.get(stat_key, 0.0) + gain[stat_key]

	# Any weapon whose base stats include a projectile_count (Laser
	# Pistol, Tornado) gets +1 every 3rd level instead of/alongside
	# its normal gains - a whole extra shot/cast, not a bigger stat
	# bump. Forcefield has no projectile_count, so it's unaffected.
	if WEAPON_DEFS[weapon_id]["base"].has("projectile_count") and stats["level"] % 3 == 0:
		stats["projectile_count"] = stats.get("projectile_count", 1.0) + 1.0

func level_up_passive(id: String) -> void:
	passives[id]["level"] += 1
	_apply_passive(id)

# Text for a level-up choice button (weapon or passive): current
# name/level plus what picking it will grant.
func get_choice_text(id: String) -> Dictionary:
	if PASSIVE_DEFS.has(id):
		return _get_passive_choice_text(id)
	return _get_weapon_choice_text(id)

func _get_passive_choice_text(id: String) -> Dictionary:
	var def: Dictionary = PASSIVE_DEFS[id]
	var passive_level: int = passives[id]["level"]
	var step_pct: float = def["per_level_value"] * 100.0
	if passive_level <= 0:
		return {
			"name": "%s (NEW)" % def["display_name"],
			"desc": "%s +%.0f%% %s." % [def["description"], step_pct, def["stat_label"]],
		}
	var next_level: int = passive_level + 1
	return {
		"name": "%s (Lv %d)" % [def["display_name"], next_level],
		"desc": "+%.0f%% %s (total +%.0f%%)" % [step_pct, def["stat_label"], next_level * step_pct],
	}

func _get_weapon_choice_text(weapon_id: String) -> Dictionary:
	var def: Dictionary = WEAPON_DEFS[weapon_id]
	var stats: Dictionary = weapons[weapon_id]
	var gain: Dictionary = def["gain"]
	if stats["level"] <= 0:
		return {
			"name": "%s (NEW)" % def["display_name"],
			"desc": def["description"],
		}
	var next_level: int = stats["level"] + 1
	var speed_label: String = def.get("speed_label", "spd")
	var speed_text: String
	if speed_label == "cooldown":
		var current_cooldown: float = 1.0 / stats["speed"]
		var next_cooldown: float = 1.0 / (stats["speed"] + gain["speed"])
		speed_text = "-%.1f%% cooldown" % _percent_gain(current_cooldown, current_cooldown - next_cooldown)
	else:
		speed_text = "+%.1f%% %s" % [_percent_gain(stats["speed"], gain["speed"]), speed_label]
	var desc: String = "+%.1f%% dmg, +%.1f%% size, %s" % [
		_percent_gain(stats["damage"], gain["damage"]), _percent_gain(stats["size"], gain["size"]), speed_text
	]
	if def["base"].has("projectile_count") and next_level % 3 == 0:
		match weapon_id:
			"laser_pistol":
				desc += ", +1 projectile"
			"tornado":
				desc += ", +1 tornado"
			"grenade":
				desc += ", +1 grenade"
	return {
		"name": "%s (Lv %d)" % [def["display_name"], next_level],
		"desc": desc,
	}

# What `delta` is as a percentage of `current` - the shared math
# behind every "% change from last level" label above.
func _percent_gain(current: float, delta: float) -> float:
	return (delta / current) * 100.0

func format_time() -> String:
	var minutes: int = int(game_time) / 60
	var seconds: int = int(game_time) % 60
	return "%02d:%02d" % [minutes, seconds]

# --- Meta-progression: coins and permanent (coin-bought) upgrades ---

func add_coins(amount: int) -> void:
	coins += amount
	_save_persistent_data()

func get_upgrade_level(id: String) -> int:
	return permanent_upgrades.get(id, 0)

# Coin cost of the *next* level, or -1 if already maxed out.
func get_upgrade_cost(id: String) -> int:
	var def: Dictionary = PERMANENT_UPGRADE_DEFS[id]
	var upgrade_level: int = get_upgrade_level(id)
	if upgrade_level >= def["max_level"]:
		return -1
	return def["costs"][upgrade_level]

# Spends coins and levels the upgrade up if affordable. Returns
# whether the purchase went through.
func purchase_upgrade(id: String) -> bool:
	var cost: int = get_upgrade_cost(id)
	if cost < 0 or coins < cost:
		return false
	coins -= cost
	permanent_upgrades[id] = get_upgrade_level(id) + 1
	_save_persistent_data()
	return true

# Total HP/sec granted by the Health Regeneration upgrade right now.
func get_health_regen_rate() -> float:
	var per_level: float = PERMANENT_UPGRADE_DEFS["health_regen"]["per_level_value"]
	return get_upgrade_level("health_regen") * per_level

# Damage multiplier from the permanent Damage upgrade (1.0 = no
# bonus, up to 1.5 at max level - flat +10%/level, not compounding).
func get_permanent_damage_mult() -> float:
	var per_level: float = PERMANENT_UPGRADE_DEFS["damage"]["per_level_value"]
	return 1.0 + get_upgrade_level("damage") * per_level

# The one multiplier every weapon applies to its base damage: the
# permanent (coin-bought) bonus times this run's Power Emblem passive.
# Weapons call this rather than either piece so a new global damage
# source only has to be added here.
func get_damage_mult() -> float:
	return get_permanent_damage_mult() * damage_mult

func _load_persistent_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	coins = int(parsed.get("coins", 0))
	show_damage_numbers = bool(parsed.get("show_damage_numbers", true))
	is_fullscreen = bool(parsed.get("is_fullscreen", false))
	var saved_cap: int = int(parsed.get("fps_cap", 0))
	fps_cap = saved_cap if FPS_CAP_OPTIONS.has(saved_cap) else 0
	var saved_upgrades: Dictionary = parsed.get("permanent_upgrades", {})
	for id in saved_upgrades.keys():
		if permanent_upgrades.has(id):
			permanent_upgrades[id] = int(saved_upgrades[id])

func _save_persistent_data() -> void:
	var data := {
		"coins": coins,
		"show_damage_numbers": show_damage_numbers,
		"is_fullscreen": is_fullscreen,
		"fps_cap": fps_cap,
		"permanent_upgrades": permanent_upgrades,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()

func set_show_damage_numbers(enabled: bool) -> void:
	show_damage_numbers = enabled
	_save_persistent_data()

# Sets the fullscreen preference, applies it to the actual window,
# and saves it so it's remembered next launch.
func set_fullscreen(enabled: bool) -> void:
	is_fullscreen = enabled
	_apply_fullscreen()
	_save_persistent_data()

func _apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

# Sets the frame-rate cap, applies it, and saves it.
func set_fps_cap(value: int) -> void:
	fps_cap = value if FPS_CAP_OPTIONS.has(value) else 0
	_apply_fps_cap()
	_save_persistent_data()

# Steps to the next FPS_CAP_OPTIONS entry (wrapping around) - what the
# settings panels' FPS button does on each press. Returns the new cap.
func cycle_fps_cap() -> int:
	var idx: int = FPS_CAP_OPTIONS.find(fps_cap)
	set_fps_cap(FPS_CAP_OPTIONS[(idx + 1) % FPS_CAP_OPTIONS.size()])
	return fps_cap

func fps_cap_label() -> String:
	return "Unlimited" if fps_cap == 0 else "%d FPS" % fps_cap

func _apply_fps_cap() -> void:
	Engine.max_fps = fps_cap
