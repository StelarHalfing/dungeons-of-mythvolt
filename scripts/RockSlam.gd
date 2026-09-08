extends Node2D

# The Ancient Keeper's ground ring - one node used by both its attacks
# (AncientKeeper._spawn_ring(): the rock slam's one big ring and the
# rock barrage's three small ones). A circle that hunts the player for
# telegraph_time, in two phases. TRACKING (the first telegraph_time -
# lock_time seconds): a red ring glued to the player's feet - wherever
# they go, it goes. LOCKED (the last lock_time seconds): the ring stops
# dead where the player was, turns amber and its inner fill rushes out
# to meet the ring; this is the window to get out of it. Then rock_count
# rocks burst up out of the floor and the player takes `damage` if still
# inside. That hit goes through the ordinary contact-damage i-frames
# (Player.take_damage() with pierce_invuln) - a stray zombie touch half
# a second earlier must not eat the boss's attacks.
#
# The rocks are the background's own prop rocks (see Background.gd
# PROPS) at the same pixel scale, popped up, held and faded over
# erupt_lifetime; the whole node frees itself once they're gone.

const ROCK_TEXTURES: Array[Texture2D] = [
	preload("res://assets/background/prop_rock1.png"),
	preload("res://assets/background/prop_rock2.png"),
	preload("res://assets/background/prop_rock3.png"),
	preload("res://assets/background/prop_rock4.png"),
]
const PIXEL_SCALE := 3.0
const ROCK_POP_TIME := 0.12

const TRACK_FILL := Color(1.0, 0.1, 0.1, 0.18)
const TRACK_RING := Color(1.0, 0.15, 0.15, 0.9)
const LOCK_FILL := Color(1.0, 0.45, 0.1, 0.22)
const LOCK_RING := Color(1.0, 0.8, 0.25, 1.0)
const LOCK_PROGRESS := Color(1.0, 0.35, 0.1, 0.4)
const RUBBLE := Color(0.25, 0.18, 0.12, 0.5)

var radius: float = 100.0
var damage: float = 45.0
var telegraph_time: float = 1.5
var lock_time: float = 0.8
var rock_count: int = 7
var erupt_lifetime: float = 0.8

var elapsed: float = 0.0
var erupted: bool = false

func _process(delta: float) -> void:
	elapsed += delta
	if not erupted:
		if not is_locked():
			_follow_player()
		queue_redraw()
		if elapsed >= telegraph_time:
			_erupt()
	elif elapsed >= telegraph_time + erupt_lifetime:
		queue_free()

# True once the ring has stopped following the player (the LOCKED phase
# above, and after the eruption).
func is_locked() -> bool:
	return elapsed >= telegraph_time - lock_time

func _follow_player() -> void:
	var player: Node2D = GameManager.player
	if player != null:
		global_position = player.global_position

func _draw() -> void:
	if erupted:
		var fade: float = 1.0 - clampf((elapsed - telegraph_time) / maxf(erupt_lifetime, 0.001), 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(RUBBLE, RUBBLE.a * fade))
		return
	if not is_locked():
		# A slow pulse on the ring while it hunts, so it reads as live.
		var pulse: float = 0.7 + 0.3 * sin(elapsed * 12.0)
		draw_circle(Vector2.ZERO, radius, TRACK_FILL)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(TRACK_RING, TRACK_RING.a * pulse), 2.0)
		return
	var lock_progress: float = clampf((elapsed - (telegraph_time - lock_time)) / maxf(lock_time, 0.001), 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, LOCK_FILL)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, LOCK_RING, 3.0)
	draw_circle(Vector2.ZERO, radius * lock_progress, LOCK_PROGRESS)

func _erupt() -> void:
	erupted = true
	queue_redraw()
	var player: Node2D = GameManager.player
	if player != null and player.global_position.distance_to(global_position) <= radius:
		player.take_damage(damage, true)
	# Pop up fast, hold, then fade out for the back half of the lifetime.
	var fade_time: float = maxf(erupt_lifetime * 0.5, 0.1)
	var hold_time: float = maxf(erupt_lifetime - ROCK_POP_TIME - fade_time, 0.0)
	for i in range(rock_count):
		var rock := Sprite2D.new()
		rock.texture = ROCK_TEXTURES[randi() % ROCK_TEXTURES.size()]
		# This node sits under the sprites; the rocks should land over them.
		rock.z_index = 1
		var rest: Vector2 = Vector2.RIGHT.rotated(randf() * TAU) * radius * sqrt(randf()) * 0.9
		rock.position = rest + Vector2(0.0, 12.0)
		rock.scale = Vector2.ZERO
		add_child(rock)
		var tween := create_tween()
		tween.tween_property(rock, "scale", Vector2.ONE * PIXEL_SCALE, ROCK_POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(rock, "position", rest, ROCK_POP_TIME)
		tween.tween_interval(hold_time)
		tween.tween_property(rock, "modulate:a", 0.0, fade_time)
