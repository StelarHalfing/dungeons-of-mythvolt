extends Node2D

@export var zombie_scene: PackedScene = preload("res://scenes/Zombie.tscn")
@export var tank_zombie_scene: PackedScene = preload("res://scenes/TankZombie.tscn")
@export var skeleton_scene: PackedScene = preload("res://scenes/Skeleton.tscn")
@export var slime_scene: PackedScene = preload("res://scenes/Slime.tscn")
@export var spawn_radius: float = 500.0
@export var initial_interval: float = 1.2

const TANK_ZOMBIE_START_TIME := 90.0  # 1:30
const TANK_ZOMBIE_SPAWN_INTERVAL := 25  # 1 Tank Zombie per 25 spawns

# Skeletons start appearing at 1:45 and linearly take over the "base
# chaser" spawn slot (i.e. everything that isn't a Tank Zombie) over
# the next 30 seconds, so the mix is 0% Skeleton right at 1:45, ~50%
# at 2:00, and 100% - Zombies stop spawning entirely - from 2:15
# onward. Tank Zombies keep spawning on their own schedule throughout,
# unaffected by this ramp.
const SKELETON_START_TIME := 105.0  # 1:45
const SKELETON_RAMP_DURATION := 30.0

# The base interval ramp below bottoms out at MIN_INTERVAL by 1:45 and
# then stays flat. The surge is a second difficulty step: from 6:00 the
# interval is scaled down toward SURGE_INTERVAL_MULT over
# SURGE_RAMP_DURATION, so the spawn rate doubles (~6.7/s -> ~13/s) by
# 6:30 instead of staying at the 1:45 plateau for the rest of the run.
const MIN_INTERVAL := 0.15
const SURGE_START_TIME := 360.0  # 6:00
const SURGE_RAMP_DURATION := 30.0
const SURGE_INTERVAL_MULT := 0.5

# The third step trades numbers for toughness: from 8:00 Slimes (500
# HP, slow) take over the base chaser slot, ramping from none of it to
# SLIME_MAX_SHARE (all of it - Skeletons stop spawning) by 8:30, and
# over the same 30 seconds the surge eases back off, so the spawn rate
# returns to its pre-6:00 level (~6.7/s) with far more HP per spawn.
# Tank Zombies keep their own schedule.
const SLIME_START_TIME := 480.0  # 8:00
const SLIME_RAMP_DURATION := 30.0
const SLIME_MAX_SHARE := 1.0

# The fourth step: from 10:30 a bigger surge ramps in over
# SECOND_SURGE_RAMP_DURATION - the interval drops to
# SECOND_SURGE_INTERVAL_MULT of the plateau by 11:00 (four times the
# rate, twice the first surge: ~6.7/s -> ~27/s), now with the Slimes
# still in the mix - and stays for the rest of the run.
const SECOND_SURGE_START_TIME := 630.0  # 10:30
const SECOND_SURGE_RAMP_DURATION := 30.0
const SECOND_SURGE_INTERVAL_MULT := 0.25

# The end of the road, for now: at REAPER_TIME every enemy on the field
# is wiped, spawning stops for good and one Reaper (Reaper.tscn, see
# Reaper.gd) is summoned to run the player down and end the run. A
# placeholder finale until more of the game exists - move REAPER_TIME
# later when it does. 15:01 rather than 15:00 so the 15-minute survival
# unlock (GameManager.UNLOCK_DEFS) is earned first.
const REAPER_TIME := 901.0  # 15:01
@export var reaper_scene: PackedScene = preload("res://scenes/Reaper.tscn")
var reaper_summoned: bool = false

var spawn_timer: float = 0.0
var enemies_spawned: int = 0

func _process(delta: float) -> void:
	if GameManager.is_paused_for_upgrade:
		return
	if GameManager.game_time >= REAPER_TIME:
		if not reaper_summoned:
			_summon_reaper()
		return
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_enemy()
		spawn_timer = current_interval()

# Seconds between spawns right now: the base ramp, then the surge on top.
func current_interval() -> float:
	var base: float = max(MIN_INTERVAL, initial_interval - GameManager.game_time * 0.01)
	return base * _surge_interval_mult()

# 1.0 before SURGE_START_TIME, easing linearly to SURGE_INTERVAL_MULT
# over SURGE_RAMP_DURATION seconds, holding there until SLIME_START_TIME,
# easing back to 1.0 over SLIME_RAMP_DURATION as the Slimes arrive, then
# easing to SECOND_SURGE_INTERVAL_MULT from SECOND_SURGE_START_TIME and
# staying there.
func _surge_interval_mult() -> float:
	var surge_in: float = clamp((GameManager.game_time - SURGE_START_TIME) / SURGE_RAMP_DURATION, 0.0, 1.0)
	var surge_out: float = clamp((GameManager.game_time - SLIME_START_TIME) / SLIME_RAMP_DURATION, 0.0, 1.0)
	var second_in: float = clamp((GameManager.game_time - SECOND_SURGE_START_TIME) / SECOND_SURGE_RAMP_DURATION, 0.0, 1.0)
	# The first surge: 0 = plateau rate, 1 = full surge, eased back out
	# again by the time the Slimes have arrived.
	var first: float = lerp(1.0, SURGE_INTERVAL_MULT, clamp(surge_in * (1.0 - surge_out), 0.0, 1.0))
	# The second starts from wherever that left off (the plateau, since
	# it fully eased out by 8:30) and goes twice as far.
	return lerp(first, SECOND_SURGE_INTERVAL_MULT, second_in)

func spawn_enemy() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node2D = players[0]
	var angle: float = randf() * TAU
	var pos: Vector2 = player.global_position + Vector2.RIGHT.rotated(angle) * spawn_radius

	enemies_spawned += 1
	var spawn_tank_zombie: bool = (
		GameManager.game_time >= TANK_ZOMBIE_START_TIME
		and enemies_spawned % TANK_ZOMBIE_SPAWN_INTERVAL == 0
	)
	var scene: PackedScene
	if spawn_tank_zombie:
		scene = tank_zombie_scene
	elif randf() < _slime_spawn_chance():
		scene = slime_scene
	else:
		scene = skeleton_scene if randf() < _skeleton_spawn_chance() else zombie_scene

	# Enemies always spawn at their scene's base stats - only the
	# spawn rate ramps up over time, not each individual enemy's
	# toughness.
	var enemy = scene.instantiate()
	get_parent().add_child(enemy)
	enemy.global_position = pos

# Wipes the field and brings on the Reaper at the player's spawn
# distance in a random direction, like any other spawn. The wiped
# enemies drop nothing.
func _summon_reaper() -> void:
	reaper_summoned = true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var reaper = reaper_scene.instantiate()
	get_parent().add_child(reaper)
	reaper.global_position = players[0].global_position + Vector2.RIGHT.rotated(randf() * TAU) * spawn_radius

# 0.0 before SKELETON_START_TIME, ramping linearly to 1.0 over
# SKELETON_RAMP_DURATION seconds, then staying at 1.0 forever after.
func _skeleton_spawn_chance() -> float:
	var elapsed: float = GameManager.game_time - SKELETON_START_TIME
	return clamp(elapsed / SKELETON_RAMP_DURATION, 0.0, 1.0)

# 0.0 before SLIME_START_TIME, ramping linearly to SLIME_MAX_SHARE over
# SLIME_RAMP_DURATION seconds, then staying there.
func _slime_spawn_chance() -> float:
	var elapsed: float = GameManager.game_time - SLIME_START_TIME
	return clamp(elapsed / SLIME_RAMP_DURATION, 0.0, 1.0) * SLIME_MAX_SHARE
