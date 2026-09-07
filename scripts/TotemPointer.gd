extends Control

# Points the way to the Boss Totem (BossTotem.gd): an arrow orbiting the
# player at ORBIT_RADIUS on screen, aimed at the totem, with the walk
# time left under it (distance over the player's current speed). Hidden
# once the totem is close enough to be on screen, and for good once it
# has been used. Fills the whole HUD layer and draws itself; it never
# takes input.

const ORBIT_RADIUS := 110.0
const HIDE_WITHIN := 420.0
const ARROW_SIZE := 14.0
const COLOR := Color(0.9, 0.7, 1.0)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.9)

var _totem: Node2D = null
var _player: Node2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if not is_instance_valid(_totem):
		_totem = get_tree().get_first_node_in_group("boss_totems")
	_player = GameManager.player
	var show: bool = _totem != null and _player != null and not _totem.used \
		and _player.global_position.distance_to(_totem.global_position) > HIDE_WITHIN
	if show != visible:
		visible = show
	if show:
		queue_redraw()

func _draw() -> void:
	if _totem == null or _player == null:
		return
	var to_totem: Vector2 = _totem.global_position - _player.global_position
	var dir: Vector2 = to_totem.normalized()
	# The player's spot on screen, camera zoom and shake included.
	var centre: Vector2 = _player.get_global_transform_with_canvas().origin
	var tip: Vector2 = centre + dir * ORBIT_RADIUS
	var side: Vector2 = dir.orthogonal()
	var points := PackedVector2Array([
		tip + dir * ARROW_SIZE,
		tip - dir * ARROW_SIZE * 0.6 + side * ARROW_SIZE * 0.8,
		tip - dir * ARROW_SIZE * 0.6 - side * ARROW_SIZE * 0.8,
	])
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_colored_polygon(points, COLOR)
	draw_polyline(outline, OUTLINE, 2.0)

	var walk_speed: float = _player.base_speed * GameManager.speed_mult
	var seconds: int = int(ceil(to_totem.length() / maxf(walk_speed, 1.0)))
	var text: String = "Boss Totem  %d:%02d" % [seconds / 60, seconds % 60]
	var font: Font = get_theme_font("font", "Label")
	var size: int = 20
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at: Vector2 = tip + dir * (ARROW_SIZE + 6.0) + Vector2(-width * 0.5, size * 0.4)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, OUTLINE)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, COLOR)
