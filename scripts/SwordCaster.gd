extends Node2D

# Child of Player (sibling of Forcefield/TornadoCaster/GrenadeCaster/
# FireballCaster). A melee weapon: once its cooldown is up it waits until
# the nearest enemy is within reach, then spawns a Slash (Slash.gd) aimed
# at it. Inactive until the "sword" weapon has been picked (level > 0).
# The weapon's "speed" stat is swings per second (cooldown = 1 / speed,
# what levels up), "size" is the reach, and every 3rd level adds a
# projectile_count slash aimed at the next-nearest enemy in reach.

const SlashScript := preload("res://scripts/Slash.gd")

var swing_timer: float = 0.0

func _process(delta: float) -> void:
	if GameManager.is_paused_for_upgrade:
		return
	var stats: Dictionary = GameManager.weapons["sword"]
	if stats["level"] <= 0:
		return

	swing_timer -= delta
	if swing_timer <= 0.0 and _try_swing(stats):
		swing_timer = 1.0 / stats["speed"]

# Returns false (and keeps the cooldown ready) when nothing is in reach.
func _try_swing(stats: Dictionary) -> bool:
	var reach: float = stats["size"]
	var origin: Vector2 = global_position
	var in_reach: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if origin.distance_to(enemy.global_position) <= reach + SlashScript.ENEMY_PAD:
			in_reach.append(enemy)
	if in_reach.is_empty():
		return false
	in_reach.sort_custom(func(a, b):
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)

	var swings: int = mini(int(stats.get("projectile_count", 1.0)), in_reach.size())
	var damage: float = stats["damage"] * GameManager.get_damage_mult()
	for i in range(swings):
		var slash := Node2D.new()
		slash.set_script(SlashScript)
		# Set before add_child(): Slash._ready() aims and deals damage the
		# moment it enters the tree (same caveat as the other casters).
		slash.direction = (in_reach[i].global_position - origin).normalized()
		slash.reach = reach
		slash.damage = damage
		add_child(slash)
	return true
