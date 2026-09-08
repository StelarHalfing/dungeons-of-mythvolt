extends Area2D

# XP orbs. A gem's xp_value picks its tier (TIERS: orb colour and size),
# so the scene variants (XPGem/BlueXPGem/RedXPGem) differ only by value,
# and a gem whose value grows (add_value()) re-tiers itself in place.
#
# Capped: spawn() is the one way to drop a gem. Past MAX_GEMS on the
# field a new drop is folded into the nearest existing gem instead of
# becoming another node homing and distance-checking every frame - a
# late-run horde drops gems far faster than the player walks over them.
# No XP is lost: the receiving gem's value goes up by exactly the folded
# amount whether or not that crosses a tier threshold.

@export var xp_value: int = 1

const ORB_ATLAS: Texture2D = preload("res://allassets/Dungeon Gathering Full Ver. 1.1/New Items [Update]/All Orbs anim 16x16.png")
const BASE_SCALE := 0.652
# Ascending by min value; a gem takes the last tier its value reaches.
# `row` is the y offset of that orb colour in ORB_ATLAS (16px rows).
const TIERS := [
	{"min": 1, "row": 96, "tint": Color(0.2, 1.0, 0.4), "scale": 1.0},
	{"min": 3, "row": 64, "tint": Color(0.45, 0.8, 1.0), "scale": 1.0},
	{"min": 5, "row": 48, "tint": Color(1.0, 0.2, 0.2), "scale": 1.0},
	{"min": 15, "row": 48, "tint": Color(1.0, 0.85, 0.35), "scale": 1.15},
	{"min": 50, "row": 32, "tint": Color.WHITE, "scale": 1.3},
	{"min": 250, "row": 80, "tint": Color(0.85, 0.5, 1.0), "scale": 1.5},
]
const MAX_GEMS := 100

# A gem past this far, with the player actively moving further away
# from it (not just standing still or wandering back toward it), snaps
# to the player's side instead of getting left behind for good - see
# _process(). Comfortably past the pickup range but well inside the
# camera's view (1280x720 at zoom 1.25), so it reads as "swept along"
# rather than an off-screen jump.
const LEASH_RANGE := 400.0
const LEASH_SIDE_OFFSET := 50.0

var homing: bool = false
var current_speed: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

# Drops a gem of `scene` at `position` under `world` - or, past MAX_GEMS,
# folds its value into the nearest gem already on the field.
static func spawn(scene: PackedScene, world: Node, position: Vector2) -> void:
	var gem = scene.instantiate()
	var gems: Array = world.get_tree().get_nodes_in_group("gems")
	if gems.size() >= MAX_GEMS:
		var nearest = null
		var best: float = INF
		for other in gems:
			if other.get_parent() != world or other.is_queued_for_deletion():
				continue
			var d: float = other.global_position.distance_squared_to(position)
			if d < best:
				best = d
				nearest = other
		if nearest != null:
			nearest.add_value(gem.xp_value)
			gem.free()
			return
	world.add_child(gem)
	gem.global_position = position

func _ready() -> void:
	add_to_group("gems")
	body_entered.connect(_on_body_entered)
	_apply_tier()

func add_value(amount: int) -> void:
	xp_value += amount
	_apply_tier()

func _apply_tier() -> void:
	var tier: Dictionary = TIERS[0]
	for candidate in TIERS:
		if xp_value >= candidate["min"]:
			tier = candidate
	sprite.region_rect = Rect2(0, tier["row"], 16, 16)
	sprite.modulate = tier["tint"]
	sprite.scale = Vector2.ONE * BASE_SCALE * tier["scale"]

func _process(delta: float) -> void:
	var player: Node2D = GameManager.player
	if player == null:
		return
	var to_gem: Vector2 = global_position - player.global_position
	var dist: float = to_gem.length()
	var pickup_range: float = 60.0 * GameManager.pickup_range_mult
	if dist < pickup_range:
		homing = true
	if not homing and dist > LEASH_RANGE and _player_moving_away(player, to_gem):
		_leash_to_player(player, to_gem)
		return
	if homing:
		current_speed = min(current_speed + 800.0 * delta, 500.0)
		global_position = global_position.move_toward(player.global_position, current_speed * delta)

# True while the player is actually walking further from this gem (not
# standing still, and not wandering back toward it) - `velocity` points
# roughly the opposite way from `to_gem` (the player-to-gem vector).
func _player_moving_away(player: Node2D, to_gem: Vector2) -> bool:
	return player.velocity.length() > 0.0 and player.velocity.dot(to_gem) < 0.0

# Snaps the gem to the player's side, in whichever direction they're
# heading - the side it's already trailing on (so it swings around
# rather than jumping across the player), just outside the pickup
# range so it starts homing in smoothly next frame instead of a second
# teleport onto the player.
func _leash_to_player(player: Node2D, to_gem: Vector2) -> void:
	var side: Vector2 = player.velocity.normalized().orthogonal()
	if side.dot(to_gem) < 0.0:
		side = -side
	global_position = player.global_position + side * LEASH_SIDE_OFFSET

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.add_xp(xp_value)
		queue_free()
