extends Node2D

# Floating damage text, spawned through spawn() below. Pooled: on the
# hottest path in the game (a Forcefield tick across a late-run crowd is
# hundreds of hits in one frame) instantiating a scene per hit and
# freeing it 0.6s later was a real cost, so a finished number parks
# itself - hidden, not processing - in a free list and the next spawn()
# reuses it instead of instantiating. The list is static (one per
# process) but its nodes live in whatever world spawned them: when that
# world is freed (a restart, back to the menu) each one leaves the list
# in _exit_tree(), and spawn() skips anything freed or foreign regardless.

@export var lifetime: float = 0.6
@export var rise_distance: float = 28.0

static var _pool: Array = []

@onready var label: Label = $Label

var elapsed: float = 0.0
var target: Node2D = null
var local_offset: Vector2 = Vector2.ZERO
var last_known_pos: Vector2 = Vector2.ZERO

# The one way to show a damage number: takes a parked one from the pool
# (it must already be a child of `world`) or instantiates `scene` under
# `world`, then setup()s it.
static func spawn(scene: PackedScene, world: Node, damage: float, follow_target: Node2D = null) -> void:
	var num: Node2D = null
	while num == null and not _pool.is_empty():
		var candidate = _pool.pop_back()
		if is_instance_valid(candidate) and candidate.get_parent() == world:
			num = candidate
	if num == null:
		num = scene.instantiate()
		world.add_child(num)
	num.setup(damage, follow_target)

# follow_target (usually the Enemy that was hit) lets the number
# track a moving enemy instead of just drifting up from a fixed
# point. Once the target is freed (enemy died), the number keeps
# rising from wherever it last saw it.
func setup(damage: float, follow_target: Node2D = null) -> void:
	label.text = str(int(round(damage)))
	elapsed = 0.0
	target = follow_target
	if target != null and is_instance_valid(target):
		local_offset = Vector2(randf_range(-6.0, 6.0), -18.0)
		last_known_pos = target.global_position + local_offset
	else:
		last_known_pos = global_position
	global_position = last_known_pos
	modulate.a = 1.0
	visible = true
	set_process(true)

func _process(delta: float) -> void:
	elapsed += delta
	var t: float = clamp(elapsed / lifetime, 0.0, 1.0)

	if target != null and is_instance_valid(target):
		last_known_pos = target.global_position + local_offset

	global_position = last_known_pos + Vector2(0.0, -rise_distance * t)
	modulate.a = 1.0 - t
	if elapsed >= lifetime:
		_park()

# Done: hide, stop ticking and wait in the pool for the next spawn().
func _park() -> void:
	target = null
	visible = false
	set_process(false)
	_pool.append(self)

func _exit_tree() -> void:
	_pool.erase(self)
