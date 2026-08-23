extends Node2D

@export var goblin_scene: PackedScene = preload("res://scenes/Goblin.tscn")
@export var minotaur_scene: PackedScene = preload("res://scenes/Minotaur.tscn")
@export var spawn_radius: float = 500.0
@export var initial_interval: float = 1.2

const MINOTAUR_START_TIME := 90.0  # 1:30
const MINOTAUR_SPAWN_INTERVAL := 25  # 1 Minotaur per 25 spawns

var spawn_timer: float = 0.0
var enemies_spawned: int = 0

func _process(delta: float) -> void:
	if GameManager.is_paused_for_upgrade:
		return
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_enemy()
		var interval: float = max(0.15, initial_interval - GameManager.game_time * 0.01)
		spawn_timer = interval

func spawn_enemy() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node2D = players[0]
	var angle: float = randf() * TAU
	var pos: Vector2 = player.global_position + Vector2.RIGHT.rotated(angle) * spawn_radius

	enemies_spawned += 1
	var spawn_minotaur: bool = (
		GameManager.game_time >= MINOTAUR_START_TIME
		and enemies_spawned % MINOTAUR_SPAWN_INTERVAL == 0
	)
	var scene: PackedScene = minotaur_scene if spawn_minotaur else goblin_scene

	# Enemies always spawn at their scene's base stats - only the
	# spawn rate ramps up over time, not each individual enemy's
	# toughness.
	var enemy = scene.instantiate()
	get_parent().add_child(enemy)
	enemy.global_position = pos
