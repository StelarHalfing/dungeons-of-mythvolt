extends Node2D

# The lightning that leaps from a Mjolnir strike (MjolnirHammer.gd).
# Placed on the struck enemy, it arcs at once to the nearest enemy
# within `jump_range` that hasn't been hit yet, deals `damage` to it,
# and every JUMP_INTERVAL continues from there - up to `jumps` times, or
# until nothing is in reach. Each arc is drawn in code (like the Slash
# and Tornado) as a jagged bolt with a white core that fades over
# BOLT_FADE, plus a small flash at every strike point; the node frees
# itself once the chain has ended and the last bolt has faded. Bolts are
# kept in global coordinates because enemies keep moving underneath.

const JUMP_INTERVAL := 0.06
const BOLT_FADE := 0.22
const SEGMENTS := 6
# How far a bolt's midpoints wander off the straight line.
const JAG := 12.0

var damage: float = 18.0
var jumps: int = 2
var jump_range: float = 90.0
# Enemies already struck (the hammer's own target first); never twice.
var struck: Array = []

var current_pos: Vector2
var jump_timer: float = 0.0
var finished: bool = false
# Each bolt: {"points": PackedVector2Array (global), "age": float}. A
# single point is just a strike flash (the hammer's impact).
var bolts: Array = []

func _ready() -> void:
	current_pos = global_position
	bolts.append({"points": PackedVector2Array([current_pos]), "age": 0.0})
	_jump()
	jump_timer = JUMP_INTERVAL

func _process(delta: float) -> void:
	for bolt in bolts:
		bolt["age"] += delta
	if not finished:
		jump_timer -= delta
		if jump_timer <= 0.0:
			_jump()
			jump_timer = JUMP_INTERVAL
	elif _all_faded():
		queue_free()
		return
	queue_redraw()

func _all_faded() -> bool:
	for bolt in bolts:
		if bolt["age"] < BOLT_FADE:
			return false
	return true

func _jump() -> void:
	if jumps <= 0:
		finished = true
		return
	var next: Node2D = _nearest_unstruck()
	if next == null:
		finished = true
		return
	jumps -= 1
	struck.append(next)
	next.take_damage(damage)
	bolts.append({"points": _bolt_points(current_pos, next.global_position), "age": 0.0})
	current_pos = next.global_position

func _nearest_unstruck() -> Node2D:
	var best: Node2D = null
	var best_distance: float = jump_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if struck.has(enemy) or enemy.get("is_dead"):
			continue
		var distance: float = current_pos.distance_to(enemy.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = enemy
	return best

func _bolt_points(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var normal: Vector2 = (to - from).normalized().orthogonal()
	points.append(from)
	for i in range(1, SEGMENTS):
		points.append(from.lerp(to, float(i) / SEGMENTS) + normal * randf_range(-JAG, JAG))
	points.append(to)
	return points

func _draw() -> void:
	for bolt in bolts:
		var fade: float = 1.0 - clampf(bolt["age"] / BOLT_FADE, 0.0, 1.0)
		if fade <= 0.0:
			continue
		var local := PackedVector2Array()
		for p in bolt["points"]:
			local.append(to_local(p))
		if local.size() >= 2:
			draw_polyline(local, Color(0.35, 0.6, 1.0, 0.8 * fade), 7.0)
			draw_polyline(local, Color(0.9, 0.97, 1.0, 0.95 * fade), 3.0)
		var end: Vector2 = local[local.size() - 1]
		draw_circle(end, 10.0 * (1.4 - 0.4 * fade), Color(0.6, 0.8, 1.0, 0.5 * fade))
