extends "res://scripts/WeaponCaster.gd"

# Child of Player (sibling of Forcefield/TornadoCaster). On a cooldown,
# throws a Grenade.tscn from the player's position toward a target -
# unlike Tornado/Laser Pistol (which just target the nearest
# enemies), grenade targeting favors the densest cluster of enemies
# within blast radius, since a single grenade hits everything in its
# radius and a "nearest enemy" pick could waste that on a lone
# straggler while a real group stands two steps further out.
# Inactive until the "grenade" weapon has been picked at least once
# (level > 0); the cooldown gate is WeaponCaster.gd's, with the weapon's
# "speed" stat as casts per second. Every 3rd level (see
# GameManager.level_up_weapon()) also throws an extra grenade at another
# dense cluster per cooldown, via projectile_count - same idea as the
# Laser Pistol/Tornado.

@export var grenade_scene: PackedScene = preload("res://scenes/Grenade.tscn")
# Referenced (not duplicated) so THROW_SPEED/FUSE_TIME used for lead
# prediction below can never drift out of sync with Grenade.gd's own
# values - GDScript exposes a preloaded script's top-level consts via
# dot access same as class_name would, without needing one.
const GrenadeScript := preload("res://scripts/Grenade.gd")

func _init() -> void:
	weapon_id = "grenade"

func _cast(stats: Dictionary) -> bool:
	_try_throw(stats)
	return true

func _try_throw(stats: Dictionary) -> void:
	var enemies: Array = live_enemies()
	if enemies.is_empty():
		return

	var player: Node2D = get_parent()
	var blast_radius: float = stats["size"]
	var grenade_count: int = GameManager.get_projectile_count("grenade")
	var throws: int = min(grenade_count, enemies.size())
	var damage: float = stats["damage"] * GameManager.get_damage_mult()
	var predicted: Array = _predict_positions(enemies, player.global_position)
	var targets: Array = _pick_cluster_targets(predicted, blast_radius, throws, player.global_position)

	for target_pos in targets:
		var grenade = grenade_scene.instantiate()
		# Set before add_child(): Grenade._ready() builds its
		# CollisionShape2D from `radius` immediately/synchronously when
		# added to the tree (Godot does not defer _ready() for
		# runtime-added nodes) - setting radius after add_child() would
		# leave the actual hit-detection area stuck at the class
		# default forever, regardless of weapon level.
		grenade.damage = damage
		grenade.radius = blast_radius
		get_parent().get_parent().add_child(grenade)
		grenade.start_throw(player.global_position, target_pos)

# Enemies never stand still - every enemy's AI walks straight toward
# wherever the player currently is (Zombie._move_toward_player()), and a
# Tank Zombie periodically stops to telegraph and then dashes - so aiming
# at today's positions means a group has usually walked out from under
# the blast by the time it actually goes off (throw travel time plus
# Grenade.FUSE_TIME's 1s charge-up, often 1.3-1.8s total). Each enemy is
# asked where it will be after that lead time (Zombie.predict_position(),
# which TankZombie overrides to play its dash out - leading a dashing
# tank by its base speed put the blast hundreds of pixels from where it
# actually ended up): an approximation (it breaks down if the player also
# moves a lot in that time), but a close one, since it is exactly what
# the AI does if the player holds roughly still. Enemies already grouped
# together end up with near-identical lead times too, so the prediction
# keeps them clustered instead of scattering the estimate.
func _predict_positions(enemies: Array, player_pos: Vector2) -> Array:
	var predicted: Array = []
	for enemy in enemies:
		# The lead time depends on how far the grenade flies, which
		# depends on where the enemy will be by then: one refinement
		# pass from the first estimate is plenty at enemy speeds well
		# under THROW_SPEED.
		var pos: Vector2 = enemy.predict_position(_lead_time(player_pos, enemy.global_position), player_pos)
		pos = enemy.predict_position(_lead_time(player_pos, pos), player_pos)
		predicted.append({"enemy": enemy, "pos": pos})
	return predicted

# Seconds until a grenade thrown now at `target` goes off: its flight
# (Grenade.start_throw()'s duration) plus the fuse.
func _lead_time(from: Vector2, target: Vector2) -> float:
	return maxf(GrenadeScript.MIN_THROW_TIME, from.distance_to(target) / GrenadeScript.THROW_SPEED) + GrenadeScript.FUSE_TIME

# Picks up to `count` distinct cluster centers (by predicted position,
# see _predict_positions()) to throw at, biased toward the densest
# groups of enemies rather than whichever is nearest to the player.
# Each pick is the enemy with the most other enemies within
# blast_radius of its predicted position (ties broken by current
# distance to `from`, so equally-dense clusters still prefer the
# closer one); every enemy that pick's blast would already cover is
# then removed from consideration so the next pick (if any) lands on
# a fresh cluster instead of re-targeting the same clump.
func _pick_cluster_targets(predicted: Array, blast_radius: float, count: int, from: Vector2) -> Array:
	var remaining: Array = predicted.duplicate()
	var targets: Array = []
	var radius_sq: float = blast_radius * blast_radius
	while targets.size() < count and not remaining.is_empty():
		# Bucket the predicted positions into blast_radius-sized cells:
		# anything within blast_radius of a candidate is in its own cell
		# or one of the 8 around it, so scoring a candidate walks ~9
		# short lists instead of every other enemy - the all-pairs
		# version was O(n^2) per grenade, real frame time at the 200-300
		# enemies a late run puts on the field.
		var cells: Dictionary = {}
		for entry in remaining:
			var cell: Vector2i = _cell_of(entry["pos"], blast_radius)
			if not cells.has(cell):
				cells[cell] = []
			cells[cell].append(entry)
		var best: Dictionary = remaining[0]
		var best_score: int = -1
		var best_dist: float = INF
		for candidate in remaining:
			var score: int = 0
			var cell: Vector2i = _cell_of(candidate["pos"], blast_radius)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var bucket = cells.get(cell + Vector2i(dx, dy))
					if bucket == null:
						continue
					for other in bucket:
						if candidate["pos"].distance_squared_to(other["pos"]) <= radius_sq:
							score += 1
			var dist: float = from.distance_squared_to(candidate["enemy"].global_position)
			if score > best_score or (score == best_score and dist < best_dist):
				best_score = score
				best_dist = dist
				best = candidate
		targets.append(best["pos"])
		remaining = remaining.filter(func(c): return c["pos"].distance_to(best["pos"]) > blast_radius)
	return targets

# Which cell_size-sized grid cell a predicted position falls in.
func _cell_of(pos: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(floori(pos.x / cell_size), floori(pos.y / cell_size))
