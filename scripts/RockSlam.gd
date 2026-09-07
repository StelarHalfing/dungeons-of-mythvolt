extends Node2D

# The Ancient Keeper's rock slam (AncientKeeper._start_charge()): a red
# circle on the ground for telegraph_time - the ring is the area that
# will be hit, the inner fill grows to meet it as the slam lands - then
# rocks burst up out of the floor and the player takes `damage` if still
# inside the ring. The rocks are the background's own prop rocks (see
# Background.gd PROPS) at the same pixel scale, popped up and faded; the
# whole node frees itself once they're gone.

const ROCK_TEXTURES: Array[Texture2D] = [
	preload("res://assets/background/prop_rock1.png"),
	preload("res://assets/background/prop_rock2.png"),
	preload("res://assets/background/prop_rock3.png"),
	preload("res://assets/background/prop_rock4.png"),
]
const PIXEL_SCALE := 3.0
const ROCK_COUNT := 7
const ERUPT_LIFETIME := 0.8

var radius: float = 100.0
var damage: float = 45.0
var telegraph_time: float = 1.5

var elapsed: float = 0.0
var erupted: bool = false

func _process(delta: float) -> void:
	elapsed += delta
	if not erupted:
		queue_redraw()
		if elapsed >= telegraph_time:
			_erupt()
	elif elapsed >= telegraph_time + ERUPT_LIFETIME:
		queue_free()

func _draw() -> void:
	if erupted:
		var fade: float = 1.0 - clampf((elapsed - telegraph_time) / ERUPT_LIFETIME, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(0.25, 0.18, 0.12, 0.5 * fade))
		return
	var progress: float = clampf(elapsed / telegraph_time, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.1, 0.1, 0.18))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.15, 0.15, 0.9), 2.0)
	draw_circle(Vector2.ZERO, radius * progress, Color(1.0, 0.2, 0.1, 0.35))

func _erupt() -> void:
	erupted = true
	queue_redraw()
	var player: Node2D = GameManager.player
	if player != null and player.global_position.distance_to(global_position) <= radius:
		player.take_damage(damage)
	for i in range(ROCK_COUNT):
		var rock := Sprite2D.new()
		rock.texture = ROCK_TEXTURES[randi() % ROCK_TEXTURES.size()]
		# This node sits under the sprites; the rocks should land over them.
		rock.z_index = 1
		var rest: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * radius * sqrt(randf()) * 0.9
		rock.position = rest + Vector2(0.0, 12.0)
		rock.scale = Vector2.ZERO
		add_child(rock)
		var tween := create_tween()
		tween.tween_property(rock, "scale", Vector2.ONE * PIXEL_SCALE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(rock, "position", rest, 0.12)
		tween.tween_interval(0.25)
		tween.tween_property(rock, "modulate:a", 0.0, ERUPT_LIFETIME - 0.4)
