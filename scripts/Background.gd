extends Node2D

# Tiles the dungeon floor texture (assets/background/floor_tile.png, a
# 16x16 tile cropped from "Dungeon Gathering Full Ver. 1.1/Set
# 4.1.png" at Rect2(64, 16, 16, 16) - the flat gray-blue floor visible
# inside that sheet's room-frame piece, not the checkered brick around
# it, which is the *wall* face) across an infinitely-scrolling area,
# then scatters a handful of purely-decorative props (rocks, bones, a
# skull) on top for visual variety.
#
# Floor tile is a standalone cropped PNG, not an AtlasTexture slice of
# the shared sheet: an AtlasTexture region samples slightly outside
# its own rect at the edges, bleeding in whatever pixels sit next to
# it in the source sheet - invisible for a single draw (e.g. Player's
# sprite frames), but the floor tile is drawn edge-to-edge hundreds of
# times per frame, so that bleed multiplied into a visible grid of
# seam lines across the whole floor.
#
# The world has no boundaries (EnemySpawner/Player can wander
# indefinitely), so a fixed-size background isn't enough for a long
# run. Instead this node snaps its own position to a grid whenever
# the player crosses a chunk boundary and redraws a generous tile
# area around that point.

const FLOOR_TEXTURE: Texture2D = preload("res://assets/background/floor_tile.png")
const TILE_SIZE := 40.0
const CHUNK_SIZE := 200.0
# Must exceed CHUNK_SIZE, or the player could outrun the drawn area
# in the moment just before the next chunk-crossing redraw.
const VISIBLE_MARGIN := 250.0

# Purely decorative - no collision, nothing ever reads these back.
# Drawn once each (not tiled edge-to-edge like the floor), so the
# AtlasTexture seam-bleed problem above doesn't apply here. The
# statue/candle/star props are cropped from "Set 4 all.png"/"Set
# 4.8.png"/"Set 4.9.png" - the same modular dungeon kit the floor
# tile comes from (Set 4.3.png), used here purely for ambient
# clutter rather than actual level geometry.
const PROP_TEXTURES := [
	preload("res://allassets/Dungeon Gathering Full Ver. 1.1/rocks.png"),
	preload("res://assets/background/prop_skull.png"),
	preload("res://assets/background/prop_bone.png"),
	preload("res://assets/background/prop_statue1.png"),
	preload("res://assets/background/prop_statue2.png"),
	preload("res://assets/background/prop_candle.png"),
	preload("res://assets/background/prop_star.png"),
]
# Coarser than TILE_SIZE so props read as sparse floor clutter, not a
# solid layer.
const PROP_CELL_SIZE := 130.0
const PROP_SPAWN_CHANCE := 0.35

var last_chunk: Vector2i = Vector2i(999999, 999999)

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

func _draw_floor(half_w: float, half_h: float) -> void:
	var start_x: float = floor(-half_w / TILE_SIZE) * TILE_SIZE
	var end_x: float = ceil(half_w / TILE_SIZE) * TILE_SIZE
	var start_y: float = floor(-half_h / TILE_SIZE) * TILE_SIZE
	var end_y: float = ceil(half_h / TILE_SIZE) * TILE_SIZE

	var x: float = start_x
	while x < end_x:
		var y: float = start_y
		while y < end_y:
			draw_texture_rect(FLOOR_TEXTURE, Rect2(x, y, TILE_SIZE, TILE_SIZE), false)
			y += TILE_SIZE
		x += TILE_SIZE

# Scatters props on a coarser grid than the floor tiles, one
# deterministic roll per cell seeded from the cell's *world*
# coordinates rather than local draw-space (which shifts every time
# this node re-snaps to a new chunk) - so a given spot in the world
# always shows the same prop, or none, no matter which chunk-crossing
# triggered the redraw.
func _draw_props(half_w: float, half_h: float) -> void:
	var start_x: float = floor((-half_w + global_position.x) / PROP_CELL_SIZE) * PROP_CELL_SIZE
	var end_x: float = ceil((half_w + global_position.x) / PROP_CELL_SIZE) * PROP_CELL_SIZE
	var start_y: float = floor((-half_h + global_position.y) / PROP_CELL_SIZE) * PROP_CELL_SIZE
	var end_y: float = ceil((half_h + global_position.y) / PROP_CELL_SIZE) * PROP_CELL_SIZE

	var world_x: float = start_x
	while world_x < end_x:
		var world_y: float = start_y
		while world_y < end_y:
			_draw_prop_cell(world_x, world_y)
			world_y += PROP_CELL_SIZE
		world_x += PROP_CELL_SIZE

func _draw_prop_cell(world_x: float, world_y: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(floori(world_x / PROP_CELL_SIZE), floori(world_y / PROP_CELL_SIZE)))
	if rng.randf() > PROP_SPAWN_CHANCE:
		return

	var texture: Texture2D = PROP_TEXTURES[rng.randi_range(0, PROP_TEXTURES.size() - 1)]
	var jitter := Vector2(rng.randf_range(0.0, PROP_CELL_SIZE), rng.randf_range(0.0, PROP_CELL_SIZE))
	var local_pos: Vector2 = Vector2(world_x, world_y) + jitter - global_position
	draw_texture(texture, local_pos)
