extends Node2D

# Draws the dungeon floor and scatters decorative props under everything
# else in Main.tscn.
#
# Floor: assets/background/floor_slabs.png is the whole 192x64 flagstone
# block from "Dungeon Gathering Full Ver. 1.1/Set 4.3.png" (0,0,192,64) -
# irregular slate slabs with light grout seams and small studs. Its outer
# edges are half-seams (3px light + the dark line on the far side), so the
# block wraps into the same 6px seam the interior has and tiles seamlessly
# as one unit. It's a standalone PNG rather than an AtlasTexture slice of
# the sheet: a region sampled edge-to-edge hundreds of times bleeds its
# neighbours in at the borders and draws a visible grid of seam lines.
#
# Everything here is drawn at PIXEL_SCALE so a floor/prop texel is the
# same size on screen as a character texel (sprites run at 2.6-3.4x).
#
# The world has no boundaries (EnemySpawner/Player can wander
# indefinitely), so a fixed-size background isn't enough for a long run.
# Instead this node snaps its own position to a grid whenever the player
# crosses a chunk boundary and redraws a generous area around that point.
# Both the floor and the prop grid are anchored to *world* coordinates
# (not to this node's local space, which shifts on every re-snap), so
# nothing visibly jumps when a redraw happens.

const PIXEL_SCALE := 3.0
const FLOOR_TEXTURE: Texture2D = preload("res://assets/background/floor_slabs.png")
const FLOOR_TILE := Vector2(192.0, 64.0) * PIXEL_SCALE
# The slab block's own base colour. The floor is drawn as this flat
# colour with the slab texture blended over it at FLOOR_DETAIL_ALPHA:
# at full strength the 6px seams and studs (18px+ on screen at 3x)
# read as a loud grid that fights the sprites; faded, they read as
# subtle stonework and the play area stays clean.
const FLOOR_BASE_COLOR := Color8(101, 115, 146)
const FLOOR_DETAIL_ALPHA := 0.4
const CHUNK_SIZE := 200.0
# Must exceed CHUNK_SIZE, or the player could outrun the drawn area
# in the moment just before the next chunk-crossing redraw.
const VISIBLE_MARGIN := 250.0

# Purely decorative - no collision, nothing ever reads these back. Each
# entry is [texture, weight]; weight is the relative chance a populated
# cell picks it, so rocks/bones are common clutter and the big statues
# are rare landmarks. Sprites are cropped from the same modular dungeon
# kit the floor comes from (rocks.png, Set 4 all/4.8/4.9).
const PROPS := [
	[preload("res://assets/background/prop_rock1.png"), 3.0],
	[preload("res://assets/background/prop_rock2.png"), 4.0],
	[preload("res://assets/background/prop_rock3.png"), 4.0],
	[preload("res://assets/background/prop_rock4.png"), 4.0],
	[preload("res://assets/background/prop_bone.png"), 3.0],
	[preload("res://assets/background/prop_skull.png"), 2.0],
	[preload("res://assets/background/prop_candle.png"), 1.0],
	[preload("res://assets/background/prop_statue1.png"), 0.5],
	[preload("res://assets/background/prop_statue2.png"), 0.5],
]
# One roll per cell of this size; coarse so props read as sparse floor
# clutter rather than a solid layer.
const PROP_CELL_SIZE := 170.0
const PROP_SPAWN_CHANCE := 0.3

var last_chunk: Vector2i = Vector2i(999999, 999999)
var _prop_weight_total: float = 0.0
# One RNG reused for every prop cell (re-seeded per cell) rather than a
# fresh allocation per cell per redraw.
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	for entry in PROPS:
		_prop_weight_total += entry[1]

func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player_pos: Vector2 = players[0].global_position
	var chunk := Vector2i(floori(player_pos.x / CHUNK_SIZE), floori(player_pos.y / CHUNK_SIZE))
	if chunk != last_chunk:
		last_chunk = chunk
		global_position = Vector2(chunk.x * CHUNK_SIZE, chunk.y * CHUNK_SIZE)
		queue_redraw()

func _draw() -> void:
	var half_w: float = 640.0 + VISIBLE_MARGIN
	var half_h: float = 360.0 + VISIBLE_MARGIN
	_draw_floor(half_w, half_h)
	_draw_props(half_w, half_h)

# Flat base colour, then the slab block tiled over the visible area on a
# world-aligned grid and faded to FLOOR_DETAIL_ALPHA.
func _draw_floor(half_w: float, half_h: float) -> void:
	draw_rect(Rect2(-half_w, -half_h, half_w * 2.0, half_h * 2.0), FLOOR_BASE_COLOR)
	var detail := Color(1.0, 1.0, 1.0, FLOOR_DETAIL_ALPHA)
	var first := Vector2i(
		floori((global_position.x - half_w) / FLOOR_TILE.x),
		floori((global_position.y - half_h) / FLOOR_TILE.y))
	var last := Vector2i(
		ceili((global_position.x + half_w) / FLOOR_TILE.x),
		ceili((global_position.y + half_h) / FLOOR_TILE.y))
	for tx in range(first.x, last.x):
		for ty in range(first.y, last.y):
			var world_pos := Vector2(tx, ty) * FLOOR_TILE
			draw_texture_rect(FLOOR_TEXTURE, Rect2(world_pos - global_position, FLOOR_TILE), false, detail)

# Scatters props on a coarse grid: one deterministic roll per cell seeded
# from the cell's world coordinates, so a given spot always shows the
# same prop (or none) no matter which chunk-crossing triggered the redraw.
func _draw_props(half_w: float, half_h: float) -> void:
	var first := Vector2i(
		floori((global_position.x - half_w) / PROP_CELL_SIZE),
		floori((global_position.y - half_h) / PROP_CELL_SIZE))
	var last := Vector2i(
		ceili((global_position.x + half_w) / PROP_CELL_SIZE),
		ceili((global_position.y + half_h) / PROP_CELL_SIZE))
	for cx in range(first.x, last.x):
		for cy in range(first.y, last.y):
			_draw_prop_cell(Vector2i(cx, cy))

func _draw_prop_cell(cell: Vector2i) -> void:
	_rng.seed = hash(cell)
	if _rng.randf() > PROP_SPAWN_CHANCE:
		return
	# Weighted pick.
	var roll: float = _rng.randf() * _prop_weight_total
	var texture: Texture2D = PROPS[0][0]
	for entry in PROPS:
		roll -= entry[1]
		if roll <= 0.0:
			texture = entry[0]
			break
	var size: Vector2 = texture.get_size() * PIXEL_SCALE
	# Jitter inside the cell but keep the whole sprite within it, so two
	# neighbouring cells can't overlap their props.
	var free := Vector2(max(PROP_CELL_SIZE - size.x, 0.0), max(PROP_CELL_SIZE - size.y, 0.0))
	var jitter := Vector2(_rng.randf() * free.x, _rng.randf() * free.y)
	var world_pos := Vector2(cell) * PROP_CELL_SIZE + jitter
	draw_texture_rect(texture, Rect2(world_pos - global_position, size), false)
