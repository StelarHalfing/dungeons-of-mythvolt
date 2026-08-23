extends Control

# A small procedurally-drawn icon (no external art) identifying a
# weapon or passive by id. Falls back to a "locked" glyph for any
# id it doesn't recognize - which is also what an empty icon_id (a
# not-yet-implemented future slot) resolves to.

var icon_id: String = ""
var dimmed: bool = false

func configure(id: String, is_dimmed: bool) -> void:
	icon_id = id
	dimmed = is_dimmed
	queue_redraw()

func _draw() -> void:
	var rect_size: Vector2 = size
	var s: float = min(rect_size.x, rect_size.y)
	var center: Vector2 = rect_size / 2.0
	var color: Color = _base_color()
	if dimmed:
		color.a *= 0.35

	match icon_id:
		"laser_pistol":
			_draw_laser_pistol(center, s, color)
		"forcefield":
			_draw_forcefield(center, s, color)
		"tornado":
			_draw_tornado(center, s, color)
		_:
			_draw_locked(center, s, color)

func _base_color() -> Color:
	match icon_id:
		"laser_pistol":
			return Color(1.0, 0.9, 0.3)
		"forcefield":
			return Color(0.65, 0.35, 1.0)
		"tornado":
			return Color(0.65, 0.8, 0.85)
		_:
			return Color(0.6, 0.6, 0.6)

func _draw_laser_pistol(center: Vector2, s: float, color: Color) -> void:
	var barrel_w: float = s * 0.7
	var barrel_h: float = s * 0.22
	draw_rect(Rect2(center.x - barrel_w / 2.0, center.y - barrel_h / 2.0, barrel_w, barrel_h), color)
	var grip_w: float = s * 0.2
	var grip_h: float = s * 0.36
	draw_rect(Rect2(center.x - barrel_w / 2.0 + s * 0.08, center.y, grip_w, grip_h), color)
	# muzzle tip highlight
	draw_rect(Rect2(center.x + barrel_w / 2.0 - s * 0.06, center.y - barrel_h / 2.0, s * 0.06, barrel_h), Color(1, 1, 1, color.a))

func _draw_forcefield(center: Vector2, s: float, color: Color) -> void:
	draw_arc(center, s * 0.36, 0.0, TAU, 32, color, s * 0.09)
	draw_circle(center, s * 0.12, Color(color.r, color.g, color.b, color.a * 0.5))

func _draw_tornado(center: Vector2, s: float, color: Color) -> void:
	for i in range(3):
		var arc_radius: float = s * (0.42 - i * 0.12)
		var start_angle: float = i * 1.3
		draw_arc(center, arc_radius, start_angle, start_angle + PI * 1.4, 16, color, s * 0.07)

func _draw_locked(center: Vector2, s: float, color: Color) -> void:
	var body_w: float = s * 0.5
	var body_h: float = s * 0.38
	var body_top: float = center.y - s * 0.02
	draw_rect(Rect2(center.x - body_w / 2.0, body_top, body_w, body_h), color)
	draw_arc(Vector2(center.x, body_top), body_w * 0.34, PI, TAU, 16, color, s * 0.08)
