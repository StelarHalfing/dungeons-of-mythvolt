extends Area2D

# Dropped by Zombie.gd (and everything that inherits its die()) with the
# same tiny chance as the Magnet (Zombie.MAGNET_DROP_CHANCE). Homes to
# the player exactly like XPGem.gd/CoinPickup.gd/MagnetPickup.gd; on
# pickup it starts the Gold Dream (GameManager.activate_gold_dream()):
# for GOLD_DREAM_DURATION seconds every kill drops a coin and gold is
# worth double. The gold bar sprite is the item sheet's ingot; the halo
# is drawn here so it reads as "special" like the Magnet.

var homing: bool = false
var current_speed: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	var player: Node2D = GameManager.player
	if player == null:
		return
	var dist: float = global_position.distance_to(player.global_position)
	var pickup_range: float = 60.0 * GameManager.get_pickup_range_mult()
	if dist < pickup_range:
		homing = true
	if homing:
		current_speed = min(current_speed + 800.0 * delta, 500.0)
		global_position = global_position.move_toward(player.global_position, current_speed * delta)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.activate_gold_dream()
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.85, 0.2, 0.22))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.4, 0.5), 2.0)
