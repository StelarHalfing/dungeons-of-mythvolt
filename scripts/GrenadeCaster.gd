extends Node2D

# Child of Player (sibling of Forcefield/TornadoCaster). On a cooldown,
# throws a Grenade.tscn from the player's position toward a target -
# unlike Tornado/Laser Pistol (which just target the nearest
# enemies), grenade targeting favors the densest cluster of enemies
# within blast radius, since a single grenade hits everything in its
# radius and a "nearest enemy" pick could waste that on a lone
# straggler while a real group stands two steps further out.
# Inactive until the "grenade" weapon has been picked at least once
# (level > 0). Every 3rd level (see GameManager.level_up_weapon())
# also throws an extra grenade at another dense cluster per cooldown,
# via projectile_count - same idea as the Laser Pistol/Tornado.

@export var grenade_scene: PackedScene = preload("res://scenes/Grenade.tscn")
# Referenced (not duplicated) so THROW_SPEED/FUSE_TIME used for lead
# prediction below can never drift out of sync with Grenade.gd's own
# values - GDScript exposes a preloaded script's top-level consts via
# dot access same as class_name would, without needing one.
const GrenadeScript := preload("res://scripts/Grenade.gd")

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
	var blast_radius: float = stats["size"]
	var grenade_count: int = int(stats.get("projectile_count", 1.0))
	var throws: int = min(grenade_count, enemies.size())
	var damage: float = stats["damage"] * GameManager.get_permanent_damage_mult()
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

# Enemies never stand still - Zombie/TankZombie AI always walks straight
# toward wherever the player currently is (see Zombie._move_toward_
# player()) - so aiming at today's positions means a group has
# usually walked out from under the blast by the time it actually
# goes off (throw travel time plus Grenade.FUSE_TIME's 1s charge-up,
# often 1.3-1.8s total). Each enemy gets "led" by that same math:
# its own current distance determines how long a grenade thrown now
# would take to reach + detonate near it, and it's assumed to keep
# closing on the player at its own speed for that whole window - an
# approximation (it breaks down if the player also moves a lot in
# that time), but a close one, since it's exactly what the AI
# actually does if the player holds roughly still. Enemies already
# grouped together end up with near-identical lead times too, so the
# prediction keeps them clustered instead of scattering the estimate.
func _predict_positions(enemies: Array, player_pos: Vector2) -> Array:
	var predicted: Array = []
	for enemy in enemies:
		var lead_time: float = player_pos.distance_to(enemy.global_position) / GrenadeScript.THROW_SPEED + GrenadeScript.FUSE_TIME
		var to_player: Vector2 = (player_pos - enemy.global_position).normalized()
		var predicted_pos: Vector2 = enemy.global_position + to_player * enemy.speed * lead_time
		predicted.append({"enemy": enemy, "pos": predicted_pos})
	return predicted

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
	while targets.size() < count and not remaining.is_empty():
		var best: Dictionary = remaining[0]
		var best_score: int = -1
		var best_dist: float = INF
		for candidate in remaining:
			var score: int = 0
			for other in remaining:
				if candidate["pos"].distance_to(other["pos"]) <= blast_radius:
					score += 1
			var dist: float = from.distance_squared_to(candidate["enemy"].global_position)
			if score > best_score or (score == best_score and dist < best_dist):
				best_score = score
				best_dist = dist
				best = candidate
		targets.append(best["pos"])
		remaining = remaining.filter(func(c): return c["pos"].distance_to(best["pos"]) > blast_radius)
	return targets
