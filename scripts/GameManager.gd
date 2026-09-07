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
# How many options a level-up panel shows.
const CHOICE_COUNT := 3
# The ids on the open level-up panel (what a reroll replaces).
var current_choices: Array = []
# Level-up rerolls: the first one each run is free (plus one more per
# level of the permanent Rerolls upgrade - see get_free_rerolls()), then
# REROLL_BASE_COST coins doubling per reroll (50, 100, 200, ...), paid
# from the same coin bank the permanent upgrades spend. Counted per run
# (reset() zeroes it); make it per level-up by zeroing it in
# offer_upgrades() instead.
const REROLL_BASE_COST := 50
var rerolls_used: int = 0
# Level-up bans: a banned id never appears in this run's level-up pool
# again. There are none by default; each level of the permanent Bans
# upgrade grants one per run (see get_max_bans()).
var banned_ids: Array = []
var bans_used: int = 0

# User preferences and meta-progression. Persist across runs (not
# touched by reset()) and across game restarts (saved to disk).
var show_damage_numbers: bool = true
# Defaults to false so a fresh install (no settings file yet) always
# starts windowed - _load_persistent_data() only overwrites this if
# SETTINGS_PATH exists, i.e. only after the player has explicitly
# turned fullscreen on at least once via set_fullscreen().
var is_fullscreen: bool = false
# Frame-rate cap applied to Engine.max_fps; 0 = unlimited (the engine
# default, so a fresh install behaves as before). Always one of
# FPS_CAP_OPTIONS - the settings panels cycle through that list.
var fps_cap: int = 0
const FPS_CAP_OPTIONS := [60, 120, 144, 240, 540, 0]
var coins: int = 0
# permanent_upgrades[id] = level, one entry per PERMANENT_UPGRADE_DEFS key
# (filled in by _apply_slot() before anything reads it).
var permanent_upgrades: Dictionary = {}

const SETTINGS_PATH := "user://settings.json"
const LEGACY_SAVE_PATH := "user://save_data.json"
const SLOT_COUNT := 3
# Which save slot's progression is loaded (1..SLOT_COUNT); remembered in
# settings.json so the game reopens on the slot last played.
var active_slot: int = 1

# Static definition of every permanent (coin-bought) upgrade: display
# info, how much each level is worth (level * per_level_value is the
# bonus - see get_permanent_bonus()), its level cap, and the coin cost
# to buy each level (costs[0] = cost of level 1, costs[1] = cost of
# level 2, etc). stat_label/format are read by format_bonus(), the same
# way PASSIVE_DEFS' are, so the shop text needs no per-id code.
const PERMANENT_UPGRADE_DEFS := {
	"health_regen": {
		"display_name": "Health Regeneration",
		"description": "Permanently regenerate health during every run.",
		"stat_label": "HP/sec",
		"format": "flat",
		"per_level_value": 0.2,
		"max_level": 5,
		"costs": [100, 200, 500, 1000, 2500],
	},
	"damage": {
		"display_name": "Damage",
		"description": "Permanently increase all weapon damage.",
		"stat_label": "damage",
		"per_level_value": 0.10,
		"max_level": 5,
		"costs": [200, 400, 1000, 2000, 5000],
	},
	# Same curve as the Wisdom Orb passive (+10%/level, 5 levels); the two
	# multiply together in get_xp_mult(), like Damage and the Power Emblem.
	"xp_gain": {
		"display_name": "XP Gain",
		"description": "Permanently earn more XP from every gem.",
		"stat_label": "XP gain",
		"per_level_value": 0.10,
		"max_level": 5,
		"costs": [200, 400, 1000, 2000, 5000],
	},
	# Damage's costs and curve (+10%/level, +50% at max). Unlike Damage and
	# XP Gain this ADDS to the Lucky Coin passive rather than multiplying,
	# so both maxed is exactly x2: two gold per coin - see get_coin_mult().
	"coin_gain": {
		"display_name": "Gold Gain",
		"description": "Permanently earn more gold from every coin.",
		"stat_label": "gold gain",
		"per_level_value": 0.10,
		"max_level": 5,
		"costs": [200, 400, 1000, 2000, 5000],
	},
	# Whole-number perks for the level-up panel (format "count": shown as
	# "+1"). Two expensive levels each, so they're a late investment.
	"rerolls": {
		"display_name": "Rerolls",
		"description": "Extra free level-up rerolls every run.",
		"stat_label": "free rerolls per run",
		"format": "count",
		"per_level_value": 1.0,
		"max_level": 2,
		"costs": [1000, 5000],
	},
	"bans": {
		"display_name": "Bans",
		"description": "Ban a level-up option for the rest of the run.",
		"stat_label": "bans per run",
		"format": "count",
		"per_level_value": 1.0,
		"max_level": 2,
		"costs": [1000, 5000],
	},
	# Each level turns one locked box in the HUD's collection grid into an
	# open slot (see get_weapon_slots() / get_passive_slots()): 2 base
	# slots + 2 levels = 4 of the row's 6 boxes; the rest come from
	# UNLOCK_DEFS (earned in play, not bought).
	"weapon_slots": {
		"display_name": "Weapon Slots",
		"description": "Unlock another weapon slot for every run.",
		"stat_label": "weapon slots",
		"format": "count",
		"per_level_value": 1.0,
		"max_level": 2,
		"costs": [1000, 2500],
	},
	"passive_slots": {
		"display_name": "Passive Slots",
		"description": "Unlock another passive slot for every run.",
		"stat_label": "passive slots",
		"format": "count",
		"per_level_value": 1.0,
		"max_level": 2,
		"costs": [1000, 2500],
	},
}

# Weapon and passive slots: how many different weapons (passives) a run
# can hold. Every run has BASE_*_SLOTS; the permanent Weapon Slots /
# Passive Slots upgrades add one each per level (to 4), and the boxes
# beyond the shop's reach come from UNLOCK_DEFS below (earned in play,
# not bought). The HUD grid shows GRID_SLOTS_PER_ROW boxes per row -
# open ones first, a lock on each of the rest, so an upgrade or unlock
# visibly removes one. A slot is a real cap: _upgrade_pool() only
# offers a weapon (passive) you don't own yet while a slot is free.
const BASE_WEAPON_SLOTS := 2
const BASE_PASSIVE_SLOTS := 2
const GRID_SLOTS_PER_ROW := 6

# Unlocks earned by playing, saved with the slot's progression. Each
# names a survival time and the slots it grants once reached in a
# single run; _check_unlocks() awards it the moment the clock gets
# there (and the slot opens in that same run).
const UNLOCK_DEFS := {
	"weapon_slot_10min": {
		"display_name": "Fifth weapon slot",
		"description": "Survive 10:00 in a single run.",
		"survive_time": 600.0,
		"weapon_slots": 1,
		"passive_slots": 0,
	},
	"passive_slot_15min": {
		"display_name": "Fifth passive slot",
		"description": "Survive 15:00 in a single run.",
		"survive_time": 900.0,
		"weapon_slots": 0,
		"passive_slots": 1,
	},
}
# unlocks[id] = earned, one entry per UNLOCK_DEFS key (filled by
# _apply_slot()).
var unlocks: Dictionary = {}
signal unlock_earned(id: String)

# The weapons and passives owned this run, in the order they were
# picked up - what the HUD grid's open boxes show, left to right.
var weapon_order: Array = []
var passive_order: Array = []

# Player-level stats. Passives (PASSIVE_DEFS below) drive these:
# pickup_range_mult is the Attraction Tome's stat (read by XPGem/
# CoinPickup/MagnetPickup), damage_mult is the Power Emblem's (folded
# into every weapon's damage via get_damage_mult()); speed_mult/
# max_hp_bonus are still free hooks for future passives.
var speed_mult: float = 1.0
var max_hp_bonus: float = 0.0
var pickup_range_mult: float = 1.0
var damage_mult: float = 1.0
# Vitality Elixir's stat: extra HP/sec this run, added to the permanent
# Health Regeneration upgrade in get_health_regen_rate().
var regen_bonus: float = 0.0
# Wisdom Orb's stat (this run's XP multiplier; the permanent XP Gain
# upgrade multiplies on top - see get_xp_mult()). XP is integer (1 per
# gem, 5 per red gem), so the boosted value's fraction is carried
# across pickups instead of rounded away - ten 1-XP gems at x1.1 really
# do give 11 XP. The carry is kept in whole hundredths of an XP (see
# add_xp()) because a float carry isn't exact: 1.2 is really
# 1.19999..., so floor() would hand out one XP a gem late at x1.2.
var xp_mult: float = 1.0
var xp_carry: int = 0
# Lucky Coin's stat: this run's extra gold per coin as a fraction (0.5 =
# +50%), added to the permanent Gold Gain bonus in get_coin_mult(). Coins
# are integer like XP, so the boosted fraction is carried in hundredths
# too (coin_carry) - ten coins at x1.1 really do give 11 gold.
var coin_gain_bonus: float = 0.0
var coin_carry: int = 0

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
	"wisdom_orb": {
		"display_name": "Wisdom Orb",
		"description": "Every XP gem is worth more.",
		"stat": "xp_mult",
		"stat_label": "XP gain",
		"base": 1.0,
		# +10% XP per level, +50% at max: taken early it buys a couple of
		# extra level-ups (= extra picks) over a run, which is what makes
		# it worth a slot, but it never doubles progression the way the
		# damage/pickup passives double their stat.
		"per_level_value": 0.1,
		"max_level": 5,
	},
	"vitality_elixir": {
		"display_name": "Vitality Elixir",
		"description": "Slowly regenerates health during the run.",
		"stat": "regen_bonus",
		"stat_label": "HP/sec",
		# A flat amount, not a percentage: shown as "+0.2 HP/sec".
		"format": "flat",
		"base": 0.0,
		# Same curve as the permanent Health Regeneration upgrade (+0.2
		# HP/sec per level, 5 levels, 1.0 HP/sec at max); the two add
		# together in get_health_regen_rate().
		"per_level_value": 0.2,
		"max_level": 5,
	},
	"lucky_coin": {
		"display_name": "Lucky Coin",
		"description": "Every coin is worth more gold.",
		"stat": "coin_gain_bonus",
		"stat_label": "gold gain",
		# Stored as the bonus fraction (base 0, +0.1/level, +50% at max)
		# rather than a multiplier, because it ADDS to the permanent Gold
		# Gain upgrade in get_coin_mult(): both maxed = x2 gold per coin.
		"base": 0.0,
		"per_level_value": 0.1,
		"max_level": 5,
	},
}

# Live passive levels: passives[id] = {"level": int}. 0 = not yet picked.
var passives: Dictionary = {}

# Consolation picks for a level-up with nothing left to offer (every
# slot full and everything owned at max level): the panel shows these
# two instead of dropping the level-up. Applied by _apply_fallback().
const FALLBACK_DEFS := {
	"heal": {
		"display_name": "Small Heal",
		"description": "Restore 25% of your max HP.",
		"heal_fraction": 0.25,
	},
	"coins": {
		"display_name": "Coin Bonus",
		"description": "+25 gold, right now.",
		"coins": 25,
	},
}

# Playable characters and maps offered on the run-setup screens
# (RunSetup.tscn builds one card per entry). `traits` are the lines shown
# in the description panel - keep them true to the actual numbers in
# Player.tscn / EnemySpawner.gd. Only the Knight and Level 1 exist so
# far; selected_character / selected_map record the choice for when
# Main.tscn has more than one of each to load.
const CHARACTER_DEFS := {
	"knight": {
		"display_name": "Knight",
		"flavor": "A steadfast dungeon delver in blue plate - the all-rounder.",
		"traits": [
			"Health: 100",
			"Move speed: 140",
			"Starting weapon: Laser Pistol",
			"Can unlock: Forcefield, Tornado, Grenade, Fireball",
			"Passives: Attraction Tome, Power Emblem, Wisdom Orb, Vitality Elixir, Lucky Coin",
			"Slots: 2 weapons, 2 passives (more from the Upgrades shop; a 5th weapon slot for surviving 10:00, a 5th passive slot for 15:00)",
		],
		"portrait": "res://assets/ui/portrait_knight.tres",
	},
}
const MAP_DEFS := {
	"level_1": {
		"display_name": "Level 1",
		"flavor": "An endless flagstone dungeon floor. Survive as long as you can.",
		"traits": [
			"Zombies from the start, spawning faster over time",
			"Tank Zombies join at 1:30 (dash attack, 300 HP)",
			"Skeletons take over from 1:45",
			"Spawn surge at 6:00 (double rate)",
		],
		"preview": "res://assets/ui/preview_level1.tres",
	},
}
var selected_character: String = "knight"
var selected_map: String = "level_1"

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
	weapon_order.clear()
	for id in WEAPON_DEFS.keys():
		var def: Dictionary = WEAPON_DEFS[id]
		var stats: Dictionary = def["base"].duplicate()
		stats["level"] = def["start_level"]
		weapons[id] = stats
		if stats["level"] > 0:
			weapon_order.append(id)

func _init_passives() -> void:
	passives.clear()
	passive_order.clear()
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
		_check_unlocks()
	_tick_slot_save(delta)

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
	current_choices = []
	rerolls_used = 0
	banned_ids = []
	bans_used = 0
	speed_mult = 1.0
	max_hp_bonus = 0.0
	pickup_range_mult = 1.0
	damage_mult = 1.0
	regen_bonus = 0.0
	xp_mult = 1.0
	xp_carry = 0
	coin_gain_bonus = 0.0
	coin_carry = 0
	_init_weapons()
	_init_passives()
	# A new run is starting: make sure the last run's coins are on disk.
	_flush_slot()

func end_run() -> void:
	is_game_over = true
	_flush_slot()
	player_died.emit()

func add_xp(amount: int) -> void:
	# Apply the XP multiplier in whole percent with an integer carry (see
	# xp_carry): every multiplier is a product of +10% steps, so the
	# percent value is exact where the float product isn't.
	xp_carry += amount * get_xp_mult_percent()
	var gained: int = xp_carry / 100
	xp_carry %= 100
	xp += gained
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

# Pauses the game and puts up a choice panel: the usual weapon/passive
# picks, or the FALLBACK_DEFS consolation picks when there's nothing
# left to level or unlock. Always returns true now (kept as a bool so
# callers can treat "no panel" as a possibility if that ever returns).
func offer_upgrades() -> bool:
	var pool: Array = _upgrade_pool()
	is_paused_for_upgrade = true
	get_tree().paused = true
	# Nothing left to level or unlock: offer the consolation picks so the
	# level-up still pays out something.
	current_choices = FALLBACK_DEFS.keys() if pool.is_empty() else _pick_choices(pool, [])
	level_up_choices.emit(current_choices)
	return true

# Whether the open panel is showing the consolation picks (no rerolls
# or bans apply to those).
func is_fallback_panel() -> bool:
	return not current_choices.is_empty() and FALLBACK_DEFS.has(current_choices[0])

func _apply_fallback(id: String) -> void:
	var def: Dictionary = FALLBACK_DEFS[id]
	if def.has("heal_fraction"):
		for player in get_tree().get_nodes_in_group("player"):
			player.hp = minf(player.hp + player.max_hp * def["heal_fraction"], player.max_hp)
	if def.has("coins"):
		add_coins(def["coins"])

# Every weapon and passive that can still level up and isn't banned. A
# weapon (passive) you don't own yet is only offered while a slot is
# free for it; owned ones can always level up.
func _upgrade_pool() -> Array:
	var ids: Array = []
	var weapon_room: bool = _owned_count(weapons) < get_weapon_slots()
	for id in weapons.keys():
		var max_level: int = WEAPON_DEFS[id].get("max_level", -1)
		var can_level: bool = max_level < 0 or weapons[id]["level"] < max_level
		var has_room: bool = weapons[id]["level"] > 0 or weapon_room
		if can_level and has_room and not banned_ids.has(id):
			ids.append(id)
	var passive_room: bool = _owned_count(passives) < get_passive_slots()
	for id in passives.keys():
		var can_level: bool = passives[id]["level"] < PASSIVE_DEFS[id]["max_level"]
		var has_room: bool = passives[id]["level"] > 0 or passive_room
		if can_level and has_room and not banned_ids.has(id):
			ids.append(id)
	return ids

func _owned_count(registry: Dictionary) -> int:
	var count: int = 0
	for id in registry.keys():
		if registry[id]["level"] > 0:
			count += 1
	return count

func get_weapon_slots() -> int:
	return BASE_WEAPON_SLOTS + int(get_permanent_bonus("weapon_slots")) + _unlocked_slots("weapon_slots")

func get_passive_slots() -> int:
	return BASE_PASSIVE_SLOTS + int(get_permanent_bonus("passive_slots")) + _unlocked_slots("passive_slots")

# What an unlock grants, for the Unlocks panel: "+1 weapon slot",
# "+1 weapon slot, +2 passive slots".
func unlock_reward_text(id: String) -> String:
	var def: Dictionary = UNLOCK_DEFS[id]
	var parts: PackedStringArray = []
	for kind in ["weapon", "passive"]:
		var count: int = def[kind + "_slots"]
		if count > 0:
			parts.append("+%d %s slot%s" % [count, kind, "" if count == 1 else "s"])
	return ", ".join(parts)

# Slots of one kind granted by every earned unlock.
func _unlocked_slots(kind: String) -> int:
	var total: int = 0
	for id in UNLOCK_DEFS.keys():
		if unlocks.get(id, false):
			total += UNLOCK_DEFS[id][kind]
	return total

# Awards any unlock whose survival time this run has just reached.
# Called from _process() right after the run clock advances, so it
# can't fire while paused or after death.
func _check_unlocks() -> void:
	for id in UNLOCK_DEFS.keys():
		if unlocks.get(id, false) or game_time < UNLOCK_DEFS[id]["survive_time"]:
			continue
		unlocks[id] = true
		# An achievement, not a coin trickle: write it now.
		_save_slot()
		unlock_earned.emit(id)

# Up to CHOICE_COUNT random ids from the pool, taking ones not in
# `avoid` (the set being rerolled) first, so a reroll shows all-new
# options whenever the pool has enough and only repeats when it doesn't.
func _pick_choices(pool: Array, avoid: Array) -> Array:
	var fresh: Array = pool.filter(func(id): return not avoid.has(id))
	var stale: Array = pool.filter(func(id): return avoid.has(id))
	fresh.shuffle()
	stale.shuffle()
	var picks: Array = fresh + stale
	return picks.slice(0, mini(CHOICE_COUNT, picks.size()))

# Free rerolls per run: one, plus one per level of the permanent
# Rerolls upgrade.
func get_free_rerolls() -> int:
	return 1 + int(get_permanent_bonus("rerolls"))

func get_free_rerolls_left() -> int:
	return maxi(get_free_rerolls() - rerolls_used, 0)

# Coins the next reroll costs: 0 while free ones remain, then
# REROLL_BASE_COST doubling each paid reroll (the shift is capped so the
# value can't overflow, not that anyone reaches 50 million coins).
func get_reroll_cost() -> int:
	var paid_so_far: int = rerolls_used - get_free_rerolls()
	if paid_so_far < 0:
		return 0
	return REROLL_BASE_COST << mini(paid_so_far, 20)

# A reroll needs an open panel, the coins, and at least one option the
# panel isn't already showing (otherwise it could only repeat itself).
func can_reroll() -> bool:
	if not is_paused_for_upgrade or is_fallback_panel() or coins < get_reroll_cost():
		return false
	return _upgrade_pool().size() > current_choices.size()

# Replaces the open panel's choices, charging get_reroll_cost(). Emits
# level_up_choices again on success so the HUD redraws; returns whether
# the reroll happened.
func reroll_upgrades() -> bool:
	if not can_reroll():
		return false
	coins -= get_reroll_cost()
	rerolls_used += 1
	_slot_dirty = true
	current_choices = _pick_choices(_upgrade_pool(), current_choices)
	level_up_choices.emit(current_choices)
	return true

# Bans per run come only from the permanent Bans upgrade (0 without it).
func get_max_bans() -> int:
	return int(get_permanent_bonus("bans"))

func get_bans_left() -> int:
	return maxi(get_max_bans() - bans_used, 0)

# A ban needs an open panel, a ban left, and something for the panel to
# still show afterwards (another choice, or a replacement in the pool).
func can_ban() -> bool:
	if not is_paused_for_upgrade or is_fallback_panel() or get_bans_left() <= 0:
		return false
	return current_choices.size() > 1 or _upgrade_pool().size() > 1

# Removes `id` from this run's level-up pool for good and swaps a fresh
# option into its place on the open panel (or drops the slot when the
# pool has nothing new left). Emits level_up_choices again so the HUD
# redraws; returns whether the ban happened.
func ban_upgrade(id: String) -> bool:
	if not can_ban() or not current_choices.has(id):
		return false
	banned_ids.append(id)
	bans_used += 1
	var index: int = current_choices.find(id)
	var fresh: Array = _upgrade_pool().filter(func(other): return not current_choices.has(other))
	if fresh.is_empty():
		current_choices.remove_at(index)
	else:
		current_choices[index] = fresh[randi() % fresh.size()]
	level_up_choices.emit(current_choices)
	return true

func choose_upgrade(id: String) -> void:
	if FALLBACK_DEFS.has(id):
		_apply_fallback(id)
	elif PASSIVE_DEFS.has(id):
		level_up_passive(id)
	else:
		level_up_weapon(id)
	current_choices = []
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
		weapon_order.append(weapon_id)
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
	if passives[id]["level"] == 1:
		passive_order.append(id)
	_apply_passive(id)

# Text for a level-up choice button (weapon or passive): current
# name/level plus what picking it will grant.
func get_choice_text(id: String) -> Dictionary:
	if FALLBACK_DEFS.has(id):
		return {"name": FALLBACK_DEFS[id]["display_name"], "desc": FALLBACK_DEFS[id]["description"]}
	if PASSIVE_DEFS.has(id):
		return _get_passive_choice_text(id)
	return _get_weapon_choice_text(id)

func _get_passive_choice_text(id: String) -> Dictionary:
	var def: Dictionary = PASSIVE_DEFS[id]
	var passive_level: int = passives[id]["level"]
	var step: float = def["per_level_value"]
	if passive_level <= 0:
		return {
			"name": "%s (NEW)" % def["display_name"],
			"desc": "%s %s %s." % [def["description"], format_bonus(def, step), def["stat_label"]],
		}
	var next_level: int = passive_level + 1
	return {
		"name": "%s (Lv %d)" % [def["display_name"], next_level],
		"desc": "%s %s (total %s)" % [format_bonus(def, step), def["stat_label"], format_bonus(def, next_level * step)],
	}

# The one way a bonus value is written, for passives and permanent
# upgrades alike: "+10%" for percentage bonuses (the default), "+0.2"
# for flat ones (def["format"] == "flat") and "+1" for whole-number
# ones ("count"); def["stat_label"] names the unit and callers append
# it once where it reads best.
func format_bonus(def: Dictionary, value: float) -> String:
	match def.get("format", "percent"):
		"flat":
			return "+%.1f" % value
		"count":
			return "+%d" % int(round(value))
		_:
			return "+%d%%" % int(round(value * 100.0))

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

# Gold from a coin pickup, boosted by get_coin_mult() with an integer
# hundredths carry (see coin_carry), the same scheme as add_xp().
#
# Coins are only marked dirty here, not written: a Magnet can land
# dozens of coins in one physics tick, and a file write per coin would
# stall that frame. The slot is flushed by _process() a second later
# and, so nothing is lost, on end_run()/reset(), slot switch/delete,
# purchase, and quit (see _flush_slot()).
func add_coins(amount: int) -> void:
	coin_carry += amount * get_coin_mult_percent()
	coins += coin_carry / 100
	coin_carry %= 100
	_slot_dirty = true

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
	_save_slot()
	return true

# A permanent upgrade's current bonus: level * per_level_value (flat,
# not compounding - Damage tops out at +0.5, i.e. x1.5, at level 5).
# The single place the level -> bonus math lives, for the run and for
# the shop's "+X now" label alike.
func get_permanent_bonus(id: String) -> float:
	var per_level: float = PERMANENT_UPGRADE_DEFS[id]["per_level_value"]
	return get_upgrade_level(id) * per_level

# Total HP/sec right now: the permanent Health Regeneration upgrade plus
# this run's Vitality Elixir passive (both flat, so they add).
func get_health_regen_rate() -> float:
	return get_permanent_bonus("health_regen") + regen_bonus

# The one multiplier every weapon applies to its base damage: the
# permanent (coin-bought) bonus times this run's Power Emblem passive.
# Weapons call this rather than either piece so a new global damage
# source only has to be added here.
func get_damage_mult() -> float:
	return (1.0 + get_permanent_bonus("damage")) * damage_mult

# The one multiplier add_xp() applies: the permanent XP Gain bonus times
# this run's Wisdom Orb passive.
func get_xp_mult() -> float:
	return (1.0 + get_permanent_bonus("xp_gain")) * xp_mult

# get_xp_mult() in whole percent (110 = x1.1), the form add_xp() uses.
func get_xp_mult_percent() -> int:
	return int(round(get_xp_mult() * 100.0))

# Gold per coin: the permanent Gold Gain bonus plus this run's Lucky
# Coin bonus, ADDED (not multiplied like damage/XP) so the two maxed
# +50%s make exactly x2 - two gold per coin, never a fraction over.
func get_coin_mult() -> float:
	return 1.0 + get_permanent_bonus("coin_gain") + coin_gain_bonus

func get_coin_mult_percent() -> int:
	return int(round(get_coin_mult() * 100.0))

# --- Persistence: one global settings file + one file per save slot ---
#
# Preferences (damage numbers, fullscreen, FPS cap) and which slot is
# active live in SETTINGS_PATH; progression (coins, permanent upgrades,
# earned unlocks)
# lives in the active slot's file. Before slots existed everything was
# in one save_data.json - _migrate_legacy_save() turns that into
# settings + slot 1 the first time this build runs, and leaves the old
# file untouched as a backup.
#
# Reading goes through _apply_settings()/_apply_slot() and writing
# through _save_settings()/_save_slot(), so each persisted key is spelled
# in exactly one reader and one writer; anything on disk is treated as
# untrusted (wrong types, out-of-range values) and coerced back into
# range, since a hand-edited or half-written file must never break the
# menu.

# Coins earned since the slot file was last written (see add_coins()).
var _slot_dirty: bool = false
var _slot_save_timer: float = 0.0
const SLOT_SAVE_INTERVAL := 1.0

func slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()

# JSON numbers come back as floats and any key may hold the wrong type;
# these coerce a loaded value or fall back to the default.
func _as_int(value, default: int) -> int:
	if value is int or value is float:
		return int(value)
	return default

func _as_dict(value) -> Dictionary:
	return value if value is Dictionary else {}

func _load_persistent_data() -> void:
	_migrate_legacy_save()
	_apply_settings(_read_json(SETTINGS_PATH))
	_load_slot(active_slot)

# Sets every preference from a settings dictionary (missing keys keep
# their defaults; unknown values are dropped).
func _apply_settings(data: Dictionary) -> void:
	show_damage_numbers = bool(data.get("show_damage_numbers", true))
	is_fullscreen = bool(data.get("is_fullscreen", false))
	var saved_cap: int = _as_int(data.get("fps_cap"), 0)
	fps_cap = saved_cap if FPS_CAP_OPTIONS.has(saved_cap) else 0
	active_slot = clampi(_as_int(data.get("active_slot"), 1), 1, SLOT_COUNT)

# Replaces the in-memory progression with a slot dictionary's (an empty
# one means a fresh start: 0 coins, no upgrades). Levels are clamped to
# 0..max_level so get_upgrade_cost() can never index costs[] out of
# range and no bonus can exceed its documented cap.
func _apply_slot(data: Dictionary) -> void:
	coins = maxi(_as_int(data.get("coins"), 0), 0)
	var saved_upgrades: Dictionary = _as_dict(data.get("permanent_upgrades"))
	for id in PERMANENT_UPGRADE_DEFS.keys():
		var max_level: int = PERMANENT_UPGRADE_DEFS[id]["max_level"]
		permanent_upgrades[id] = clampi(_as_int(saved_upgrades.get(id), 0), 0, max_level)
	var saved_unlocks: Dictionary = _as_dict(data.get("unlocks"))
	for id in UNLOCK_DEFS.keys():
		unlocks[id] = saved_unlocks.get(id, false) == true

func _load_slot(slot: int) -> void:
	_apply_slot(_read_json(slot_path(slot)))
	_slot_dirty = false
	_slot_save_timer = 0.0

# Preferences and progression are written separately so that changing a
# setting never (re)creates the active slot's file - a freshly deleted
# or never-used slot keeps reading as "Empty" until coins are earned.
func _save_settings() -> void:
	_write_json(SETTINGS_PATH, {
		"show_damage_numbers": show_damage_numbers,
		"is_fullscreen": is_fullscreen,
		"fps_cap": fps_cap,
		"active_slot": active_slot,
	})

func _save_slot() -> void:
	_slot_dirty = false
	_slot_save_timer = 0.0
	_write_json(slot_path(active_slot), {
		"coins": coins,
		"permanent_upgrades": permanent_upgrades,
		"unlocks": unlocks,
	})

# Writes the active slot if any coins are waiting to be saved.
func _flush_slot() -> void:
	if _slot_dirty:
		_save_slot()

# Debounced coin save: at most one write per SLOT_SAVE_INTERVAL while
# coins keep arriving. Runs even while the tree is paused (this node is
# PROCESS_MODE_ALWAYS), so a pause right after a pickup still saves.
func _tick_slot_save(delta: float) -> void:
	if not _slot_dirty:
		return
	_slot_save_timer += delta
	if _slot_save_timer >= SLOT_SAVE_INTERVAL:
		_save_slot()

func _notification(what: int) -> void:
	# Closing the window or quitting from the menu: don't lose the last
	# second of coins.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		_flush_slot()

# Switches to another slot: writes anything the old slot still owes,
# loads the new slot's progression and remembers the choice.
func select_slot(slot: int) -> void:
	slot = clampi(slot, 1, SLOT_COUNT)
	if slot == active_slot:
		return
	_flush_slot()
	active_slot = slot
	_load_slot(slot)
	_save_settings()

# Wipes a slot's file (the main menu asks for confirmation first). If it
# is the active slot, the in-memory progression resets to a fresh start
# as well - including any unsaved coins, which are deliberately dropped
# rather than flushed into the slot that was just wiped; its file is
# only recreated once coins are earned again.
func delete_slot(slot: int) -> void:
	if slot < 1 or slot > SLOT_COUNT:
		return
	var path: String = slot_path(slot)
	var dir := DirAccess.open("user://")
	if dir != null and FileAccess.file_exists(path):
		dir.remove(path.get_file())
	if slot == active_slot:
		_load_slot(slot)

# What the main menu shows on a slot button without loading the slot.
# "exists" follows the file, not whether it parsed: a damaged file still
# shows up (as 0 coins) so the Delete button can clear it.
func slot_summary(slot: int) -> Dictionary:
	if slot == active_slot:
		_flush_slot()
	var path: String = slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"exists": false, "coins": 0, "upgrade_levels": 0}
	var data := _read_json(path)
	var levels: int = 0
	for value in _as_dict(data.get("permanent_upgrades")).values():
		levels += maxi(_as_int(value, 0), 0)
	return {"exists": true, "coins": maxi(_as_int(data.get("coins"), 0), 0), "upgrade_levels": levels}

# One-time upgrade of the pre-slot save_data.json into settings.json +
# slot 1. Gated on the settings file rather than on the legacy file, so
# it runs exactly once per install: a save_data.json that shows up later
# (an older build sharing this user:// folder, a restored backup) is
# ignored instead of re-migrated over the player's current slot 1. The
# legacy file itself is never touched - it *is* the backup.
func _migrate_legacy_save() -> void:
	if FileAccess.file_exists(SETTINGS_PATH) or not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	var legacy := _read_json(LEGACY_SAVE_PATH)
	_apply_settings(legacy)
	active_slot = 1
	_save_settings()
	# A legacy file that didn't parse (legacy == {}) has no progression
	# to carry over; leave slot 1 empty rather than writing a 0-coin save.
	if legacy.has("coins") and not FileAccess.file_exists(slot_path(1)):
		_apply_slot(legacy)
		_save_slot()

func set_show_damage_numbers(enabled: bool) -> void:
	show_damage_numbers = enabled
	_save_settings()

# Sets the fullscreen preference, applies it to the actual window,
# and saves it so it's remembered next launch.
func set_fullscreen(enabled: bool) -> void:
	is_fullscreen = enabled
	_apply_fullscreen()
	_save_settings()

func _apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

# Sets the frame-rate cap, applies it, and saves it.
func set_fps_cap(value: int) -> void:
	fps_cap = value if FPS_CAP_OPTIONS.has(value) else 0
	_apply_fps_cap()
	_save_settings()

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
