extends Area2D

# Spawned by GrenadeCaster on top of a nearby enemy. Sits through a
# brief fuse (small pulsing telegraph), then explodes: deals damage
# once to everything overlapping within `radius`, shows a brief
# expanding blast ring, and frees itself. Unlike Tornado (which
# lingers and ticks), this is a single burst hit - see
# GameManager.WEAPON_DEFS["grenade"] for the level-1/level-12 damage
# targets it's tuned against.

var damage: float = 22.0
var radius: float = 60.0

const FUSE_TIME := 0.3
const BLAST_VISUAL_TIME := 0.25

enum State { FUSE, BLAST }
var state: State = State.FUSE
var state_elapsed: float = 0.0

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape

func _process(delta: float) -> void:
	state_elapsed += delta
	match state:
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
		State.FUSE:
			var pulse: float = 0.6 + 0.4 * sin(state_elapsed * 20.0)
			draw_circle(Vector2.ZERO, radius * 0.14, Color(0.25, 0.55, 0.2, 1.0))
			draw_circle(Vector2.ZERO, radius * 0.14 * pulse, Color(1.0, 0.6, 0.1, 0.8))
		State.BLAST:
			var t: float = state_elapsed / BLAST_VISUAL_TIME
			draw_circle(Vector2.ZERO, radius, Color(1.0, 0.45, 0.1, 0.35 * (1.0 - t)))
			draw_arc(Vector2.ZERO, radius * (0.5 + 0.5 * t), 0.0, TAU, 32, Color(1.0, 0.8, 0.3, 0.9 * (1.0 - t)), 4.0)
