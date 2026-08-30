extends Area2D

# Spawned by TornadoCaster on top of a nearby enemy. Wanders in a
# slow random walk, ticks damage to everything overlapping it (same
# tick-damage pattern as ForcefieldWeapon.gd), and pulls overlapping
# enemies toward its own center each frame so they stay "caught"
# inside it as it drifts, instead of needing to track/replicate the
# tornado's exact movement. Tank Zombies are too heavy to drag around
# - they get slowed (Zombie.apply_slow()) instead of pulled. Frees
# itself after `duration` seconds.

var damage: float = 6.0
var radius: float = 55.0
var duration: float = 2.5

const TICK_INTERVAL := 0.4
const PULL_SPEED := 90.0
# Tank Zombies get slowed, not pulled (see class comment), so nothing
# re-centers them in the tornado - wander can carry it away from a
# stationary/slow Tank Zombie and cost a tick or two. That's
# intentional variance, not a bug: max-level damage gain
# (GameManager.gd) is tuned so a full, uninterrupted 6-tick duration
# deals exactly half a Tank Zombie's HP - that's the ceiling when
# wander cooperates, not a guarantee. Regular Zombies are unaffected
# since the pull re-centers them regardless of where the tornado
# wanders.
const WANDER_SPEED := 45.0
const WANDER_TURN_INTERVAL := 0.7

var tick_timer: float = TICK_INTERVAL
var wander_timer: float = 0.0
var wander_dir: Vector2 = Vector2.ZERO
var elapsed: float = 0.0

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	_pick_wander_dir()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return

	wander_timer -= delta
	if wander_timer <= 0:
		_pick_wander_dir()
	global_position += wander_dir * WANDER_SPEED * delta

	tick_timer -= delta
	if tick_timer <= 0:
		_deal_damage()
		tick_timer = TICK_INTERVAL

	_pull_enemies(delta)
	queue_redraw()

func _pick_wander_dir() -> void:
	wander_dir = Vector2.RIGHT.rotated(randf() * TAU)
	wander_timer = WANDER_TURN_INTERVAL

func _deal_damage() -> void:
	for area in get_overlapping_areas():
		if area.is_in_group("enemies"):
			area.take_damage(damage)

# Re-centers overlapping enemies toward the tornado each frame rather
# than moving them by the tornado's own delta - simpler and avoids
# ever needing to know if the tornado moved this frame before or
# after a given enemy did. Tank Zombies are exempt from the pull (see
# class comment above) and get slowed instead.
func _pull_enemies(delta: float) -> void:
	for area in get_overlapping_areas():
		if not area.is_in_group("enemies"):
			continue
		if area.is_in_group("tank_zombies"):
			area.apply_slow()
		else:
			area.global_position = area.global_position.move_toward(global_position, PULL_SPEED * delta)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.55, 0.55, 0.6, 0.12))
	var t: float = elapsed * 6.0
	for i in range(3):
		var arc_radius: float = radius * (0.42 - i * 0.12)
		var start_angle: float = t + i * (TAU / 3.0)
		draw_arc(Vector2.ZERO, arc_radius, start_angle, start_angle + PI * 1.4, 16, Color(0.75, 0.75, 0.8, 0.55), 3.0)
