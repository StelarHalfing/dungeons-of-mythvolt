extends Node2D

# One sword swing, spawned by SwordCaster.gd into the world at the
# player's position. A crescent that faces `direction`, sweeps open over
# SWING_TIME, then flies forward at SPEED for `duration` seconds (the
# weapon's duration stat times GameManager.get_duration_mult()) before
# fading out. Every frame it damages any enemy inside its fan (ARC degrees out
# to `reach` from the crescent's current position) that it hasn't hit
# yet - once per enemy, and shoves it `knockback` px along the slash's
# direction (Zombie.apply_knockback()) - so a slash cleaves through a
# line of enemies rather than stopping at the first. The hit test is
# geometric against the "enemies" group, like Fireball.gd's blast; no
# physics shape. Drawn in code like the Tornado and ExplosionFlash.

var direction: Vector2 = Vector2.RIGHT
var reach: float = 60.0
var damage: float = 10.0
var duration: float = 0.2
# Pixels each hit enemy is shoved (0 = none); SwordCaster sets it with
# GameManager.get_knockback_mult() already applied.
var knockback: float = 0.0

const SPEED := 450.0
const ARC := deg_to_rad(110.0)
const SWING_TIME := 0.1
const FADE_TIME := 0.12
# Enemies are hit by their centre; this lets a blade that visually
# reaches an enemy's near edge still count.
const ENEMY_PAD := 12.0

var elapsed: float = 0.0
var travelled: float = 0.0
# Enemies already damaged by this slash (each only once).
var hit: Array = []

func _ready() -> void:
	rotation = direction.angle()
	_deal_damage()

func _process(delta: float) -> void:
	elapsed += delta
	var step: float = minf(SPEED * delta, _travel() - travelled)
	if step > 0.0:
		global_position += direction * step
		travelled += step
		_deal_damage()
	if travelled >= _travel() and elapsed >= duration + FADE_TIME:
		queue_free()
		return
	queue_redraw()

# How far the slash flies in total.
func _travel() -> float:
	return SPEED * duration

func _deal_damage() -> void:
	var half_arc: float = ARC / 2.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if hit.has(enemy):
			continue
		var to: Vector2 = enemy.global_position - global_position
		if to.length() > reach + ENEMY_PAD:
			continue
		if absf(angle_difference(direction.angle(), to.angle())) > half_arc:
			continue
		hit.append(enemy)
		enemy.take_damage(damage)
		if knockback > 0.0 and enemy.has_method("apply_knockback"):
			enemy.apply_knockback(direction, knockback)

func _draw() -> void:
	var half_arc: float = ARC / 2.0
	# The blade sweeps open across the arc, flies as a full crescent,
	# then fades once it has gone as far as it goes.
	var sweep: float = clampf(elapsed / SWING_TIME, 0.0, 1.0)
	var fade: float = 1.0 - clampf((elapsed - duration) / FADE_TIME, 0.0, 1.0)
	var end_angle: float = -half_arc + ARC * sweep
	if end_angle <= -half_arc + 0.01 or fade <= 0.0:
		return
	var blade_radius: float = reach * 0.82
	var width: float = maxf(reach * 0.2, 6.0)
	draw_arc(Vector2.ZERO, blade_radius, -half_arc, end_angle, 24, Color(0.2, 0.25, 0.4, 0.8 * fade), width + 3.0)
	draw_arc(Vector2.ZERO, blade_radius, -half_arc, end_angle, 24, Color(0.92, 0.95, 1.0, 0.95 * fade), width)
	draw_arc(Vector2.ZERO, blade_radius + width * 0.3, -half_arc, end_angle, 24, Color(1.0, 1.0, 1.0, 0.9 * fade), 2.0)
