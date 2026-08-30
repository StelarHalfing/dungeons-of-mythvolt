extends Control

# Identifies a weapon or passive by id with a small icon. Most
# weapons now use a real sprite (see ICON_TEXTURES); anything without
# a matching texture - currently only Tornado, which has no fitting
# icon in the asset library - falls back to a procedurally-drawn
# glyph, same as the "locked" glyph used for any id this doesn't
# recognize (including an empty icon_id, i.e. a not-yet-implemented
# future slot).

const ICON_TEXTURES := {
	"laser_pistol": preload("res://allassets/DG Fire Zone Expansion Full Ver/Items/Magic wand.png"),
	"forcefield": preload("res://allassets/DG Fire Zone Expansion Full Ver/Items/Shield.png"),
	"grenade": preload("res://allassets/DG Fire Zone Expansion Full Ver/Items/Fire Orb.png"),
}

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

	if ICON_TEXTURES.has(icon_id):
		_draw_texture_icon(center, s, ICON_TEXTURES[icon_id])
		return

	var color: Color = _base_color()
	if dimmed:
		color.a *= 0.35

	match icon_id:
		"tornado":
			_draw_tornado(center, s, color)
		_:
			_draw_locked(center, s, color)

func _draw_texture_icon(center: Vector2, s: float, texture: Texture2D) -> void:
	var tint: Color = Color(1, 1, 1, 1)
	if dimmed:
		tint.a = 0.35
	var icon_size: float = s * 0.8
	var rect := Rect2(center - Vector2.ONE * icon_size / 2.0, Vector2.ONE * icon_size)
	draw_texture_rect(texture, rect, false, tint)

func _base_color() -> Color:
	match icon_id:
		"tornado":
			return Color(0.65, 0.8, 0.85)
		_:
			return Color(0.6, 0.6, 0.6)

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
