extends Node2D

# A short expanding, fading disc + ring drawn at a blast point (used by
# Fireball.gd). Created with ExplosionFlash.new(), given `radius`, added
# to the world; frees itself when done.

const DURATION := 0.25

var radius: float = 30.0
var elapsed: float = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t: float = clamp(elapsed / DURATION, 0.0, 1.0)
	var r: float = radius * (0.6 + 0.4 * t)
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.55, 0.15, 0.55 * (1.0 - t)))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(1.0, 0.9, 0.5, 0.9 * (1.0 - t)), 3.0)
