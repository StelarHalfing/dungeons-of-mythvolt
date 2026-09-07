extends Node2D

# One sword swing, spawned by SwordCaster.gd as a child of the caster (so
# it rides along with the player). Faces `direction`; on its first frame
# it damages every enemy inside a fan of ARC degrees out to `reach`
# (a geometric check against the "enemies" group, like Fireball.gd's
# blast - no physics shape needed for a one-frame hit), then draws a
# crescent that sweeps across the arc over SWING_TIME and fades out by
# LIFETIME. Drawn in code like the Tornado and ExplosionFlash.

var direction: Vector2 = Vector2.RIGHT
var reach: float = 60.0
var damage: float = 20.0

const ARC := deg_to_rad(110.0)
const SWING_TIME := 0.12
const LIFETIME := 0.26
# Enemies are hit by their centre; this lets a blade that visually
# reaches an enemy's near edge still count.
const ENEMY_PAD := 12.0

var elapsed: float = 0.0

func _ready() -> void:
	rotation = direction.angle()
	_deal_damage()

func _deal_damage() -> void:
	var half_arc: float = ARC / 2.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to: Vector2 = enemy.global_position - global_position
		if to.length() > reach + ENEMY_PAD:
			continue
		if absf(angle_difference(direction.angle(), to.angle())) > half_arc:
			continue
		enemy.take_damage(damage)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= LIFETIME:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var half_arc: float = ARC / 2.0
	# The blade sweeps from one edge of the arc to the other, then the
	# whole crescent fades.
	var sweep: float = clampf(elapsed / SWING_TIME, 0.0, 1.0)
	var fade: float = 1.0 - clampf((elapsed - SWING_TIME) / (LIFETIME - SWING_TIME), 0.0, 1.0)
	var end_angle: float = -half_arc + ARC * sweep
	if end_angle <= -half_arc + 0.01:
		return
	var blade_radius: float = reach * 0.82
	var width: float = maxf(reach * 0.2, 6.0)
	draw_arc(Vector2.ZERO, blade_radius, -half_arc, end_angle, 24, Color(0.2, 0.25, 0.4, 0.8 * fade), width + 3.0)
	draw_arc(Vector2.ZERO, blade_radius, -half_arc, end_angle, 24, Color(0.92, 0.95, 1.0, 0.95 * fade), width)
	draw_arc(Vector2.ZERO, blade_radius + width * 0.3, -half_arc, end_angle, 24, Color(1.0, 1.0, 1.0, 0.9 * fade), 2.0)
