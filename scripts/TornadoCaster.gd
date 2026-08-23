extends Node2D

# Child of Player (sibling of Forcefield). On a cooldown, spawns a
# Tornado.tscn on top of the nearest enemy - same nearest-enemy
# targeting as Player.try_fire(), but a discrete AoE-zone spawn
# instead of a projectile. Inactive until the "tornado" weapon has
# been picked at least once (level > 0). Every 3rd level (see
# GameManager.level_up_weapon()) also casts on additional nearby
# enemies per cooldown, via projectile_count - same idea as the
# Laser Pistol's multi-target firing.

@export var tornado_scene: PackedScene = preload("res://scenes/Tornado.tscn")

var cast_timer: float = 0.0

func _process(delta: float) -> void:
	if GameManager.is_paused_for_upgrade:
		return
	var stats: Dictionary = GameManager.weapons["tornado"]
	if stats["level"] <= 0:
		return

	cast_timer -= delta
	if cast_timer <= 0:
		_try_cast(stats)
		cast_timer = 1.0 / max(stats["speed"], 0.01)

func _try_cast(stats: Dictionary) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var player: Node2D = get_parent()
	enemies.sort_custom(func(a, b):
		return player.global_position.distance_squared_to(a.global_position) < player.global_position.distance_squared_to(b.global_position)
	)

	var tornado_count: int = int(stats.get("projectile_count", 1.0))
	var casts: int = min(tornado_count, enemies.size())
	var damage: float = stats["damage"] * GameManager.get_permanent_damage_mult()

	for i in range(casts):
		var tornado = tornado_scene.instantiate()
		# Set before add_child(): Tornado._ready() builds its
		# CollisionShape2D from `radius` immediately/synchronously
		# when added to the tree (Godot does not defer _ready() for
		# runtime-added nodes) - setting radius after add_child()
		# would leave the actual hit-detection area stuck at the
		# class default (55.0) forever, regardless of weapon level,
		# even though the visual _draw() circle (which re-reads
		# radius every frame) would still show the correct size.
		tornado.damage = damage
		tornado.radius = stats["size"]
		tornado.duration = stats["duration"]
		get_parent().get_parent().add_child(tornado)
		tornado.global_position = enemies[i].global_position
