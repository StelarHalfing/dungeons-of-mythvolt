extends Area2D

@export var xp_value: int = 1
@export var gem_color: Color = Color(0.2, 1.0, 0.4)
@export var gem_radius: float = 5.0

var homing: bool = false
var current_speed: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("gems")
	body_entered.connect(_on_body_entered)
	sprite.modulate = gem_color

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
		GameManager.add_xp(xp_value)
		queue_free()
