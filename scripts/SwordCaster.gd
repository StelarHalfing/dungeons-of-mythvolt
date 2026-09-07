extends "res://scripts/WeaponCaster.gd"

# Child of Player (sibling of Forcefield/TornadoCaster/GrenadeCaster/
# FireballCaster). Once its cooldown is up it waits until the nearest
# enemy is within the slash's full depth (reach + how far the slash
# flies), then spawns a Slash (Slash.gd) into the world aimed at it.
# Inactive until the "sword" weapon has been picked (level > 0) - the
# gate, the cooldown and the attack-speed bonus are WeaponCaster.gd's.
# The weapon's "speed" stat is swings per second (cooldown = 1 / speed),
# "size" is the reach, "duration" is how long the slash flies (at
# Slash.SPEED, stretched by GameManager.get_duration_mult()) - so a
# max-level sword with Duration bonuses cleaves deep into a wave -
# "knockback" is how far each hit shoves the enemy (pixels, times
# GameManager.get_knockback_mult()), and every 3rd level adds a
# projectile_count slash aimed at the next-nearest enemy in depth.

const SlashScript := preload("res://scripts/Slash.gd")

func _init() -> void:
	weapon_id = "sword"

# How long a slash flies right now: the weapon's duration stat times
# the run's duration multiplier.
static func slash_duration(stats: Dictionary) -> float:
	return stats["duration"] * GameManager.get_duration_mult()

# How far a slash can hit from the player: its reach plus its flight.
static func slash_depth(stats: Dictionary) -> float:
	return stats["size"] + SlashScript.SPEED * slash_duration(stats)

# Returns false (and keeps the cooldown ready) when nothing is in depth.
func _cast(stats: Dictionary) -> bool:
	var origin: Vector2 = global_position
	var depth: float = slash_depth(stats)
	var in_depth: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if origin.distance_to(enemy.global_position) <= depth + SlashScript.ENEMY_PAD:
			in_depth.append(enemy)
	if in_depth.is_empty():
		return false
	in_depth.sort_custom(func(a, b):
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)

	var swings: int = mini(GameManager.get_projectile_count("sword"), in_depth.size())
	var damage: float = stats["damage"] * GameManager.get_damage_mult()
	var world: Node = get_parent().get_parent()
	for i in range(swings):
		var slash := Node2D.new()
		slash.set_script(SlashScript)
		# Set before add_child(): Slash._ready() aims and deals its first
		# damage the moment it enters the tree (same caveat as the other
		# casters).
		slash.direction = (in_depth[i].global_position - origin).normalized()
		slash.reach = stats["size"]
		slash.duration = slash_duration(stats)
		slash.damage = damage
		slash.knockback = stats.get("knockback", 0.0) * GameManager.get_knockback_mult()
		world.add_child(slash)
		slash.global_position = origin
	return true
