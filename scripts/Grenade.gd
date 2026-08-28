extends Area2D

# Thrown by GrenadeCaster from the player's position. Travels to the
# target (THROWN), then sits through a charging-up fuse once landed
# (FUSE) before exploding once - deals damage to everything
# overlapping within `radius`, shows a brief expanding blast ring,
# and frees itself. Unlike Tornado (which lingers and ticks), this is
# a single burst hit - see GameManager.WEAPON_DEFS["grenade"] for the
# level-1/level-12 damage targets it's tuned against.

var damage: float = 35.0
var radius: float = 60.0

const THROW_SPEED := 600.0
const MIN_THROW_TIME := 0.1
const FUSE_TIME := 1.0
const BLAST_VISUAL_TIME := 0.25

enum State { THROWN, FUSE, BLAST }
var state: State = State.THROWN
var state_elapsed: float = 0.0

var throw_start: Vector2 = Vector2.ZERO
var throw_target: Vector2 = Vector2.ZERO
var throw_duration: float = MIN_THROW_TIME

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape

# Called by GrenadeCaster right after add_child() (global_position
# needs the node already in the tree to resolve correctly - same
# reasoning as every other runtime-spawned effect in this project,
# see GrenadeCaster.gd). Kicks off the flight from the player's
# position to the landing spot; duration scales with distance so a
# longer throw takes visibly longer to arrive instead of teleporting.
func start_throw(from: Vector2, to: Vector2) -> void:
	throw_start = from
	throw_target = to
	global_position = from
	throw_duration = max(MIN_THROW_TIME, from.distance_to(to) / THROW_SPEED)

func _process(delta: float) -> void:
	state_elapsed += delta
	match state:
		State.THROWN:
			var t: float = clamp(state_elapsed / throw_duration, 0.0, 1.0)
			global_position = throw_start.lerp(throw_target, t)
			if t >= 1.0:
				global_position = throw_target
				state = State.FUSE
				state_elapsed = 0.0
		State.FUSE:
			if state_elapsed >= FUSE_TIME:
				_explode()
		State.BLAST:
			if state_elapsed >= BLAST_VISUAL_TIME:
				queue_free()
	queue_redraw()

func _explode() -> void:
	state = State.BLAST
	state_elapsed = 0.0
	for area in get_overlapping_areas():
		if area.is_in_group("enemies"):
			area.take_damage(damage)

func _draw() -> void:
	match state:
		State.THROWN:
			# No real height axis in this top-down game, so the "lob"
			# is just a scale bump peaking at the midpoint of the
			# flight - reads as an arc without needing actual 3D.
			var t: float = clamp(state_elapsed / throw_duration, 0.0, 1.0)
			var arc: float = sin(t * PI)
			draw_circle(Vector2.ZERO, radius * 0.06 * (1.0 + arc), Color(0.25, 0.55, 0.2, 1.0))
		State.FUSE:
			# Charging up: pulse speeds up and shifts from green toward
			# red as `p` nears 1, so the instant before detonation is
			# unmistakable rather than a flat repeating blink.
			var p: float = clamp(state_elapsed / FUSE_TIME, 0.0, 1.0)
			var pulse: float = 0.6 + 0.4 * sin(state_elapsed * (8.0 + p * 24.0))
			var charge_color: Color = Color(0.25, 0.55, 0.2, 1.0).lerp(Color(1.0, 0.25, 0.05, 1.0), p)
			draw_circle(Vector2.ZERO, radius * 0.14, Color(0.25, 0.55, 0.2, 1.0))
			draw_circle(Vector2.ZERO, radius * (0.14 + 0.1 * p) * pulse, charge_color)
		State.BLAST:
			var t: float = state_elapsed / BLAST_VISUAL_TIME
			draw_circle(Vector2.ZERO, radius, Color(1.0, 0.45, 0.1, 0.35 * (1.0 - t)))
			draw_arc(Vector2.ZERO, radius * (0.5 + 0.5 * t), 0.0, TAU, 32, Color(1.0, 0.8, 0.3, 0.9 * (1.0 - t)), 4.0)
