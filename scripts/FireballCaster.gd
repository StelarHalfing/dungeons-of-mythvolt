extends Node2D

# Child of Player (sibling of Forcefield/TornadoCaster/GrenadeCaster).
# On a fixed cooldown, launches Fireball.tscn at the nearest enemies -
# slow, heavy shots that explode on impact (see Fireball.gd). Inactive
# until the "fireball" weapon has been picked at least once (level > 0).
# Every 3rd level (see GameManager.level_up_weapon()) fires an extra
# fireball at the next-nearest enemy per cooldown, via projectile_count,
# same as the Laser Pistol. The weapon's "speed" stat is projectile
# speed (that's what levels up), not fire rate, hence the constant.

@export var fireball_scene: PackedScene = preload("res://scenes/Fireball.tscn")
const COOLDOWN := 1.2

var cast_timer: float = 0.0

func _process(delta: float) -> void:
	if GameManager.is_paused_for_upgrade:
		return
	var stats: Dictionary = GameManager.weapons["fireball"]
	if stats["level"] <= 0:
		return

	cast_timer -= delta
	if cast_timer <= 0.0:
		_try_launch(stats)
		cast_timer = COOLDOWN

func _try_launch(stats: Dictionary) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var player: Node2D = get_parent()
	var origin: Vector2 = player.global_position
	enemies.sort_custom(func(a, b):
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	var shots: int = min(int(stats.get("projectile_count", 1.0)), enemies.size())
	var damage: float = stats["damage"] * GameManager.get_damage_mult()

	for i in range(shots):
		var dir: Vector2 = (enemies[i].global_position - origin).normalized()
		var fireball = fireball_scene.instantiate()
		# Set before add_child(): Fireball._ready() reads direction and
		# radius synchronously when added to the tree (same caveat as
		# Player.try_fire()).
		fireball.direction = dir
		fireball.speed = stats["speed"]
		fireball.radius = stats["size"]
		fireball.damage = damage
		get_parent().get_parent().add_child(fireball)
		fireball.global_position = origin
