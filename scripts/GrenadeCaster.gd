extends Node2D

# Child of Player (sibling of Forcefield/TornadoCaster). On a cooldown,
# lobs a Grenade.tscn onto the nearest enemy - same nearest-enemy
# targeting as TornadoCaster. Inactive until the "grenade" weapon has
# been picked at least once (level > 0). Every 3rd level (see
# GameManager.level_up_weapon()) also lobs an extra grenade at an
# additional nearby enemy per cooldown, via projectile_count - same
# idea as the Laser Pistol/Tornado.

@export var grenade_scene: PackedScene = preload("res://scenes/Grenade.tscn")

var cast_timer: float = 0.0

func _process(delta: float) -> void:
	if GameManager.is_paused_for_upgrade:
		return
	var stats: Dictionary = GameManager.weapons["grenade"]
	if stats["level"] <= 0:
		return

	cast_timer -= delta
	if cast_timer <= 0:
		_try_throw(stats)
		cast_timer = 1.0 / max(stats["speed"], 0.01)

func _try_throw(stats: Dictionary) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var player: Node2D = get_parent()
	enemies.sort_custom(func(a, b):
		return player.global_position.distance_squared_to(a.global_position) < player.global_position.distance_squared_to(b.global_position)
	)

	var grenade_count: int = int(stats.get("projectile_count", 1.0))
	var throws: int = min(grenade_count, enemies.size())
	var damage: float = stats["damage"] * GameManager.get_permanent_damage_mult()

	for i in range(throws):
		var grenade = grenade_scene.instantiate()
		# Set before add_child(): Grenade._ready() builds its
		# CollisionShape2D from `radius` immediately/synchronously when
		# added to the tree (Godot does not defer _ready() for
		# runtime-added nodes) - setting radius after add_child() would
		# leave the actual hit-detection area stuck at the class
		# default forever, regardless of weapon level.
		grenade.damage = damage
		grenade.radius = stats["size"]
		get_parent().get_parent().add_child(grenade)
		grenade.global_position = enemies[i].global_position
