extends Area2D

# Thrown by MjolnirCaster.gd. Spins through the air at `speed`, bending
# its path toward `target` while that enemy lives (a thrown hammer that
# seeks, so a throw is rarely wasted on an enemy that stepped aside),
# and on touching any enemy deals `damage` to it, starts a
# LightningChain there (LightningChain.gd) and vanishes. Expires unspent
# if it flies for `lifetime` seconds without touching anything. Mirrors
# Fireball.gd's Area2D setup; the sprite is the item sheet's hammer.

const LightningChainScript := preload("res://scripts/LightningChain.gd")
# How fast the hammer can bend its path toward the target (radians/s).
const TURN_RATE := 5.0
const SPIN_RATE := TAU * 2.5
const HIT_RADIUS := 10.0

var target: Node2D = null
var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: float = 18.0
# Lightning jumps after the hit, and how far each may reach.
var chains: int = 2
var chain_range: float = 90.0
var lifetime: float = 2.5
# area_entered can fire for two enemies in one frame; strike once.
var struck: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Enemies are Area2D too, so we listen for area_entered, not
	# body_entered (that's only for PhysicsBody2D like the Player).
	area_entered.connect(_on_area_entered)
	var shape := CircleShape2D.new()
	shape.radius = HIT_RADIUS
	$CollisionShape2D.shape = shape

func _process(delta: float) -> void:
	if is_instance_valid(target) and not target.get("is_dead"):
		var wanted: Vector2 = (target.global_position - global_position).normalized()
		var turn: float = clampf(direction.angle_to(wanted), -TURN_RATE * delta, TURN_RATE * delta)
		direction = direction.rotated(turn)
	global_position += direction * speed * delta
	sprite.rotation += SPIN_RATE * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if struck or not area.is_in_group("enemies"):
		return
	struck = true
	area.take_damage(damage)

	var chain := Node2D.new()
	chain.set_script(LightningChainScript)
	chain.damage = damage
	chain.jumps = chains
	chain.jump_range = chain_range
	chain.struck = [area]
	# Positioned before add_child(): the chain makes its first jump the
	# moment it enters the tree.
	chain.position = area.global_position
	get_parent().add_child(chain)
	queue_free()
