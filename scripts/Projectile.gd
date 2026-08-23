extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var damage: float = 10.0
var radius: float = 4.0
var lifetime: float = 2.0
var pierce: int = 1
var hit_enemies: Array = []

# fireball-*.png's 29x27 canvas has a lot of transparent padding
# around the actual flame - this is the average opaque (visible)
# pixel size, measured directly from the source frames, not the raw
# canvas size. Used to scale the sprite to match `radius` (which
# grows as Laser Pistol levels up) so the VISIBLE flame matches the
# collision circle, same idea as the CollisionShape2D below.
const FIREBALL_VISIBLE_SIZE := 19.8
# All sprites render 25% larger than their collision box (kept as
# its own factor rather than folded into FIREBALL_VISIBLE_SIZE, so
# that constant stays an honest measurement, not a fudged one).
const SPRITE_SCALE_BOOST := 1.25

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Enemies are Area2D too, so we listen for area_entered, not
	# body_entered (that's only for PhysicsBody2D like the Player).
	area_entered.connect(_on_area_entered)
	rotation = direction.angle()
	# Give this instance its own CircleShape2D so resizing it (as
	# Laser Pistol levels up) doesn't affect every other projectile.
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	sprite.scale = Vector2.ONE * (radius * 2.0 / FIREBALL_VISIBLE_SIZE * SPRITE_SCALE_BOOST)

func _process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies") and not hit_enemies.has(area):
		area.take_damage(damage)
		hit_enemies.append(area)
		pierce -= 1
		if pierce <= 0:
			queue_free()
