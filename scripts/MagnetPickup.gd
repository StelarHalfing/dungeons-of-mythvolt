extends Area2D

# Dropped by Zombie.gd/TankZombie.gd on kill with a tiny 0.1% chance
# (Zombie.MAGNET_DROP_CHANCE). Homes to the player exactly like
# XPGem.gd/CoinPickup.gd; on pickup, instead of granting its own
# value, it sets every XP gem and coin currently on the field homing
# toward the player - same per-frame accelerate-and-move_toward
# logic they already use once the player walks into pickup range
# (see XPGem.gd/CoinPickup.gd), just triggered instantly and from
# anywhere on the map instead of waiting for proximity. Each one
# still grants its value/frees itself the normal way once it
# actually reaches the player (_on_body_entered in XPGem.gd/
# CoinPickup.gd) - the magnet itself has nothing left to do once
# homing is set, so it frees immediately.

var homing: bool = false
var current_speed: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node2D = players[0]
	var dist: float = global_position.distance_to(player.global_position)
	var pickup_range: float = 60.0 * GameManager.pickup_range_mult
	if dist < pickup_range:
		homing = true
	if homing:
		current_speed = min(current_speed + 800.0 * delta, 500.0)
		global_position = global_position.move_toward(player.global_position, current_speed * delta)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_pull_in_all()
		queue_free()

# Sets every XP gem and coin currently in the scene homing - the
# "gems"/"coins" groups already exist for this exact kind of
# field-wide lookup (see XPGem.gd/CoinPickup.gd). Doesn't touch
# their value or free them directly; that still happens on their own
# once they physically arrive at the player.
func _pull_in_all() -> void:
	for gem in get_tree().get_nodes_in_group("gems"):
		gem.homing = true
	for coin in get_tree().get_nodes_in_group("coins"):
		coin.homing = true

func _draw() -> void:
	var color := Color(0.85, 0.15, 0.15) # red magnet body
	var tip_color := Color(0.82, 0.82, 0.88) # silver pole tips
	var leg_w: float = 3.0
	var leg_x: float = 4.5
	# glowing halo so it reads as "special" against the plain gem/coin sprites
	draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.9, 0.3, 0.2))
	# U-shaped body: two vertical legs + a connecting bottom arc
	draw_rect(Rect2(-leg_x - leg_w / 2.0, -6.0, leg_w, 9.0), color)
	draw_rect(Rect2(leg_x - leg_w / 2.0, -6.0, leg_w, 9.0), color)
	draw_arc(Vector2(0.0, 3.0), leg_x, 0.0, PI, 16, color, leg_w)
	# silver pole tips
	draw_rect(Rect2(-leg_x - leg_w / 2.0, -6.0, leg_w, 2.5), tip_color)
	draw_rect(Rect2(leg_x - leg_w / 2.0, -6.0, leg_w, 2.5), tip_color)
