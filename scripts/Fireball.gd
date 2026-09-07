extends Area2D

# Fired by FireballCaster.gd. Flies straight at `speed`; on touching an
# enemy (or when its lifetime runs out) it explodes: direct-hit damage
# to what it touched, then blast damage to everything within the blast
# radius, plus a short ExplosionFlash. Slower and heavier than the
# Laser Pistol's Projectile.gd, which it otherwise mirrors (they share
# the fireball-*.png frames).

const ExplosionFlashScript := preload("res://scripts/ExplosionFlash.gd")
# Blast radius/damage derive from the weapon's size/damage stats so they
# level up together instead of being fixed numbers.
const BLAST_RADIUS_MULT := 3.75
const BLAST_DAMAGE_MULT := 0.6
# Same visible-flame measurement Projectile.gd uses to fit the sprite
# to the collision circle.
const FIREBALL_VISIBLE_SIZE := 19.8
const SPRITE_SCALE_BOOST := 1.25

var direction: Vector2 = Vector2.RIGHT
var speed: float = 100.0
var damage: float = 25.0
var radius: float = 8.0
var lifetime: float = 3.0
# area_entered can fire in the same frame lifetime runs out; explode once.
var exploded: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Enemies are Area2D too, so we listen for area_entered, not
	# body_entered (that's only for PhysicsBody2D like the Player).
	area_entered.connect(_on_area_entered)
	rotation = direction.angle()
	# Own CircleShape2D per instance so resizing it (as Fireball levels
	# up) doesn't affect every other fireball.
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	sprite.scale = Vector2.ONE * (radius * 2.0 / FIREBALL_VISIBLE_SIZE * SPRITE_SCALE_BOOST)

func _process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_explode()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies") and not exploded:
		area.take_damage(damage)
		_explode()

func _explode() -> void:
	if exploded:
		return
	exploded = true
	var blast_radius: float = radius * BLAST_RADIUS_MULT

	var flash = ExplosionFlashScript.new()
	flash.radius = blast_radius
	get_parent().add_child(flash)
	flash.global_position = global_position

	# Blast damage to everything in range (the direct-hit target too:
	# enemies take their own deferred path through take_damage()).
	var blast_damage: float = damage * BLAST_DAMAGE_MULT
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(enemy.global_position) <= blast_radius:
			enemy.take_damage(blast_damage)

	queue_free()
