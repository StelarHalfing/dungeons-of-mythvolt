extends Area2D

# Child of Player. Stays centered on the player automatically since
# it's parented (position is a fixed offset set in Player.tscn to
# align with the sprite's visual center, not necessarily (0,0)).
# Inactive/invisible until the "forcefield" weapon has been picked at
# least once (level > 0).

var tick_timer: float = 0.0

func _ready() -> void:
	monitoring = false
	visible = false
	var shape := CircleShape2D.new()
	$CollisionShape2D.shape = shape
	_sync_shape()

func _process(delta: float) -> void:
	var stats: Dictionary = GameManager.weapons["forcefield"]
	var owned: bool = stats["level"] > 0
	if owned != visible:
		visible = owned
		monitoring = owned
	if not owned:
		return

	_sync_shape()

	var interval: float = 1.0 / max(stats["speed"], 0.01)
	tick_timer -= delta
	if tick_timer <= 0:
		_deal_damage(stats["damage"] * GameManager.get_permanent_damage_mult())
		tick_timer = interval

func _sync_shape() -> void:
	var stats: Dictionary = GameManager.weapons["forcefield"]
	var shape: CircleShape2D = $CollisionShape2D.shape
	if shape.radius != stats["size"]:
		shape.radius = stats["size"]
		queue_redraw()

func _deal_damage(damage: float) -> void:
	for area in get_overlapping_areas():
		if area.is_in_group("enemies"):
			area.take_damage(damage)

func _draw() -> void:
	var stats: Dictionary = GameManager.weapons["forcefield"]
	if stats["level"] <= 0:
		return
	var size: float = stats["size"]
	draw_circle(Vector2.ZERO, size, Color(0.6, 0.3, 1.0, 0.10))
	draw_arc(Vector2.ZERO, size, 0.0, TAU, 48, Color(0.6, 0.3, 1.0, 0.6), 3.0)
