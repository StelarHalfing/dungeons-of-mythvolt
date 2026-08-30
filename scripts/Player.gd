extends CharacterBody2D

@export var base_speed: float = 140.0
@export var max_hp: float = 100.0
@export var attack_cooldown: float = 0.6
@export var projectile_scene: PackedScene = preload("res://scenes/Projectile.tscn")

var hp: float = 100.0
var invuln_timer: float = 0.0
var fire_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("player")
	max_hp = 100.0 + GameManager.max_hp_bonus
	hp = max_hp

func _physics_process(delta: float) -> void:
	if GameManager.is_paused_for_upgrade:
		return

	# Pick up any "max HP" upgrades gained mid-run as free extra HP.
	var new_max: float = 100.0 + GameManager.max_hp_bonus
	if new_max > max_hp:
		hp += (new_max - max_hp)
		max_hp = new_max

	# Permanent (coin-bought) health regeneration upgrade.
	var regen_rate: float = GameManager.get_health_regen_rate()
	if regen_rate > 0.0 and hp < max_hp:
		hp = min(hp + regen_rate * delta, max_hp)

	var input_dir: Vector2 = get_input_dir()
	velocity = input_dir * base_speed * GameManager.speed_mult
	move_and_slide()
	_update_sprite(input_dir)

	if invuln_timer > 0:
		invuln_timer -= delta
		modulate.a = 0.5 if int(invuln_timer * 10) % 2 == 0 else 1.0
	else:
		modulate.a = 1.0

	fire_timer -= delta
	if fire_timer <= 0:
		try_fire()
		fire_timer = attack_cooldown

# Tracks the last nonzero movement direction so idle keeps facing
# whichever way the player was last walking, instead of snapping back
# to a default facing the instant input stops.
var facing_dir: Vector2 = Vector2.DOWN

# Sticky per Zombie.gd's _facing_animation() - switching away from the
# current axis needs a clear margin, not just barely crossing the
# diagonal, or facing flickers between side/up/down on tiny frame-to-
# frame jitter around a ~45-degree input.
var facing_horizontal: bool = false

func _update_sprite(input_dir: Vector2) -> void:
	var moving: bool = input_dir.length() > 0
	if moving:
		facing_dir = input_dir

	const HYSTERESIS := 1.15
	if facing_horizontal:
		facing_horizontal = abs(facing_dir.x) * HYSTERESIS > abs(facing_dir.y)
	else:
		facing_horizontal = abs(facing_dir.x) > abs(facing_dir.y) * HYSTERESIS

	var direction_suffix: String
	if facing_horizontal:
		direction_suffix = "side"
		sprite.flip_h = facing_dir.x < 0.0
	else:
		direction_suffix = "up" if facing_dir.y < 0.0 else "down"

	sprite.play(("run_" if moving else "idle_") + direction_suffix)

func get_input_dir() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if dir.length() > 0:
		dir = dir.normalized()
	return dir

func try_fire() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	enemies.sort_custom(func(a, b):
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)

	var stats: Dictionary = GameManager.weapons["laser_pistol"]
	var projectile_count: int = int(stats.get("projectile_count", 1.0))
	var shots: int = min(projectile_count, enemies.size())
	var damage: float = stats["damage"] * GameManager.get_permanent_damage_mult()

	for i in range(shots):
		var target: Node2D = enemies[i]
		var dir: Vector2 = (target.global_position - global_position).normalized()
		var proj = projectile_scene.instantiate()
		# Set before add_child(): Projectile._ready() reads direction
		# (for rotation) and radius (for its CollisionShape2D/sprite
		# scale) immediately/synchronously when added to the tree
		# (Godot does not defer _ready() for runtime-added nodes) -
		# setting them after add_child() would leave every projectile
		# stuck at the class defaults (facing right, radius 4)
		# regardless of actual aim direction or weapon level.
		proj.direction = dir
		proj.damage = damage
		proj.speed = stats["speed"]
		proj.radius = stats["size"]
		get_parent().add_child(proj)
		proj.global_position = global_position

func take_damage(amount: float) -> void:
	if invuln_timer > 0 or GameManager.is_paused_for_upgrade:
		return
	hp -= amount
	invuln_timer = 0.5
	if hp <= 0:
		die()

func die() -> void:
	GameManager.is_game_over = true
	GameManager.player_died.emit()
	get_tree().paused = true
