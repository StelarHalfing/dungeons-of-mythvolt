extends Node2D

# Tiles the dungeon floor texture (assets/background/floor_tile.png,
# a 16x16 tile cropped from the 2D Pixel Dungeon Asset Pack's
# tileset - it was verified to tile seamlessly before extraction)
# across an infinitely-scrolling area.
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
