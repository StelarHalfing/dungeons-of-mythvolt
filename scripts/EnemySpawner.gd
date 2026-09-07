extends Node2D

@export var zombie_scene: PackedScene = preload("res://scenes/Zombie.tscn")
@export var tank_zombie_scene: PackedScene = preload("res://scenes/TankZombie.tscn")
@export var skeleton_scene: PackedScene = preload("res://scenes/Skeleton.tscn")
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

var spawn_timer: float = 0.0
var enemies_spawned: int = 0

func _process(delta: float) -> void:
	if GameManager.is_paused_for_upgrade:
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
# over SURGE_RAMP_DURATION seconds, then staying there.
func _surge_interval_mult() -> float:
	var t: float = clamp((GameManager.game_time - SURGE_START_TIME) / SURGE_RAMP_DURATION, 0.0, 1.0)
	return lerp(1.0, SURGE_INTERVAL_MULT, t)

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
	else:
		scene = skeleton_scene if randf() < _skeleton_spawn_chance() else zombie_scene

	# Enemies always spawn at their scene's base stats - only the
	# spawn rate ramps up over time, not each individual enemy's
	# toughness.
	var enemy = scene.instantiate()
	get_parent().add_child(enemy)
	enemy.global_position = pos

# 0.0 before SKELETON_START_TIME, ramping linearly to 1.0 over
# SKELETON_RAMP_DURATION seconds, then staying at 1.0 forever after.
func _skeleton_spawn_chance() -> float:
	var elapsed: float = GameManager.game_time - SKELETON_START_TIME
	return clamp(elapsed / SKELETON_RAMP_DURATION, 0.0, 1.0)
