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

# A gem the player leaves behind isn't lost: once it has fallen fully
# off one edge of the screen with the player still walking away from it
# along that axis, it wraps to the opposite edge, keeping its place
# along the other axis - see ScreenWrap.gd (enemies do exactly the
# same). WRAP_MARGIN: how far past the edge it must be before it wraps
# (fully hidden, with enough slack that a wiggling player doesn't
# ping-pong it). WRAP_INSET: how far inside the far edge it reappears
# (the sprite fully in view).
const ScreenWrapScript := preload("res://scripts/ScreenWrap.gd")
const WRAP_MARGIN := 24.0
const WRAP_INSET := 12.0

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
	var dist: float = global_position.distance_to(player.global_position)
	var pickup_range: float = 60.0 * GameManager.pickup_range_mult
	if dist < pickup_range:
		homing = true
	if homing:
		current_speed = min(current_speed + 800.0 * delta, 500.0)
		global_position = global_position.move_toward(player.global_position, current_speed * delta)
	else:
		ScreenWrapScript.wrap_across_screen(self, player, WRAP_MARGIN, WRAP_INSET)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.add_xp(xp_value)
		queue_free()
