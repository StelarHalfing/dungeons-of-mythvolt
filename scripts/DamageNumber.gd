extends Node2D

@export var lifetime: float = 0.6
@export var rise_distance: float = 28.0

@onready var label: Label = $Label

var elapsed: float = 0.0
var target: Node2D = null
var local_offset: Vector2 = Vector2.ZERO
var last_known_pos: Vector2 = Vector2.ZERO

# follow_target (usually the Enemy that was hit) lets the number
# track a moving enemy instead of just drifting up from a fixed
# point. Once the target is freed (enemy died), the number keeps
# rising from wherever it last saw it.
func setup(damage: float, follow_target: Node2D = null) -> void:
	label.text = str(int(round(damage)))
	target = follow_target
	if target != null and is_instance_valid(target):
		local_offset = Vector2(randf_range(-6.0, 6.0), -18.0)
		last_known_pos = target.global_position + local_offset
	else:
		last_known_pos = global_position
	global_position = last_known_pos

func _process(delta: float) -> void:
	elapsed += delta
	var t: float = clamp(elapsed / lifetime, 0.0, 1.0)

	if target != null and is_instance_valid(target):
		last_known_pos = target.global_position + local_offset

	global_position = last_known_pos + Vector2(0.0, -rise_distance * t)
	modulate.a = 1.0 - t
	if elapsed >= lifetime:
		queue_free()
