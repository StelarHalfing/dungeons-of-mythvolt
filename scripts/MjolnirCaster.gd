extends Node2D

# Child of Player (sibling of the other casters). On a fixed cooldown,
# hurls MjolnirHammer.tscn at the nearest enemies: each hammer homes in
# on its target, and where it lands a LightningChain leaps on to nearby
# enemies (see MjolnirHammer.gd / LightningChain.gd). Inactive until the
# "mjolnir" weapon has been picked (level > 0). The weapon's "speed" is
# the hammer's flight speed, "size" is how far each lightning jump can
# reach, "chains" is how many jumps a strike makes (+1 every 3rd level)
# and "projectile_count" is hammers per throw, one per nearest enemy
# (+1 at levels 6 and 12 - see GameManager.level_up_weapon()).

@export var hammer_scene: PackedScene = preload("res://scenes/MjolnirHammer.tscn")
const COOLDOWN := 1.4

var cast_timer: float = 0.0

func _process(delta: float) -> void:
	if GameManager.is_paused_for_upgrade:
		return
	var stats: Dictionary = GameManager.weapons["mjolnir"]
	if stats["level"] <= 0:
		return

	cast_timer -= delta
	if cast_timer <= 0.0:
		_try_throw(stats)
		cast_timer = COOLDOWN

func _try_throw(stats: Dictionary) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var player: Node2D = get_parent()
	var origin: Vector2 = player.global_position
	enemies.sort_custom(func(a, b):
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	var throws: int = mini(int(stats.get("projectile_count", 1.0)), enemies.size())
	var damage: float = stats["damage"] * GameManager.get_damage_mult()

	for i in range(throws):
		var hammer = hammer_scene.instantiate()
		# Set before add_child(): the hammer reads these as it enters the
		# tree (same caveat as the other casters).
		hammer.target = enemies[i]
		hammer.direction = (enemies[i].global_position - origin).normalized()
		hammer.speed = stats["speed"]
		hammer.damage = damage
		hammer.chains = int(stats.get("chains", 0.0))
		hammer.chain_range = stats["size"]
		player.get_parent().add_child(hammer)
		hammer.global_position = origin
