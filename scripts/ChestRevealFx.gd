extends Control

# The drawn effects behind ChestReveal's chest: beams of light fanning
# up out of it (one, three or five by rarity, swaying gently, in the
# rarity's colour - Legendary alternates gold, orange and red like a
# five-item chest), and the starburst of rays where the piece settles.
# No textures, so the colours come straight from RARITY_DEFS and the
# shapes scale with the panel. Runs while the tree is paused (the
# reveal is PROCESS_MODE_ALWAYS and this inherits it).

const BEAM_SPREAD := deg_to_rad(110.0)
const BEAM_TOP_WIDTH := 150.0
const BEAM_BOTTOM_WIDTH := 26.0
const BEAM_SWAY := deg_to_rad(3.0)
const BURST_TIME := 0.7
const BURST_RAYS := 12
const LEGENDARY_COLORS := [Color(1.0, 0.85, 0.35), Color(1.0, 0.55, 0.2), Color(0.95, 0.3, 0.3)]

var beams: int = 1
var color: Color = Color.WHITE
var origin: Vector2 = Vector2.ZERO
# 0 = the chest is closed, 1 = the beams reach the top of the panel.
var progress: float = 0.0
var time: float = 0.0
var burst_center: Vector2 = Vector2.ZERO
# -1 while idle, else seconds since the burst started.
var burst_t: float = -1.0

func setup(beam_count: int, beam_color: Color, from: Vector2) -> void:
	beams = maxi(beam_count, 1)
	color = beam_color
	origin = from
	progress = 0.0
	burst_t = -1.0
	queue_redraw()

func starburst(at: Vector2) -> void:
	burst_center = at
	burst_t = 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	time += delta
	if burst_t >= 0.0:
		burst_t += delta
		if burst_t > BURST_TIME:
			burst_t = -1.0
	queue_redraw()

func _draw() -> void:
	if progress > 0.0:
		var length: float = (origin.y + 40.0) * progress
		for i in range(beams):
			var frac: float = 0.5 if beams == 1 else float(i) / float(beams - 1)
			var angle: float = (frac - 0.5) * BEAM_SPREAD + sin(time * 1.4 + i * 1.7) * BEAM_SWAY
			var dir := Vector2(sin(angle), -cos(angle))
			var normal := Vector2(dir.y, -dir.x)
			var tip: Vector2 = origin + dir * length
			var beam_color: Color = color if beams < 5 else LEGENDARY_COLORS[i % LEGENDARY_COLORS.size()]
			beam_color.a = 0.38 * progress
			draw_colored_polygon(PackedVector2Array([
				origin - normal * BEAM_BOTTOM_WIDTH / 2.0,
				origin + normal * BEAM_BOTTOM_WIDTH / 2.0,
				tip + normal * BEAM_TOP_WIDTH / 2.0,
				tip - normal * BEAM_TOP_WIDTH / 2.0,
			]), beam_color)
			var core := Color(1.0, 1.0, 1.0, 0.22 * progress)
			draw_colored_polygon(PackedVector2Array([
				origin - normal * 6.0,
				origin + normal * 6.0,
				tip + normal * BEAM_TOP_WIDTH * 0.18,
				tip - normal * BEAM_TOP_WIDTH * 0.18,
			]), core)
	if burst_t >= 0.0:
		var t: float = burst_t / BURST_TIME
		var ray_length: float = 30.0 + 90.0 * t
		var fade: float = 1.0 - t
		for i in range(BURST_RAYS):
			var ray_angle: float = i * TAU / BURST_RAYS + t * 0.6
			var d := Vector2(cos(ray_angle), sin(ray_angle))
			var ray_color: Color = color
			ray_color.a = fade
			draw_line(burst_center + d * 20.0, burst_center + d * ray_length, ray_color, 1.0 + 3.0 * fade)
		draw_arc(burst_center, 24.0 + 60.0 * t, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, fade * 0.8), 2.0)
