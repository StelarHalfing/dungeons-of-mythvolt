extends CharacterBody2D

@export var base_speed: float = 140.0
@export var max_hp: float = 100.0
@export var attack_cooldown: float = 0.6
@export var projectile_scene: PackedScene = preload("res://scenes/Projectile.tscn")

var hp: float = 100.0
var invuln_timer: float = 0.0
var fire_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	add_to_group("player")
	GameManager.player = self
	max_hp = GameManager.get_max_hp()
	hp = max_hp

# Drops the shared reference on the way out (see GameManager.player) so
# nothing keeps reading a freed node once the scene changes.
func _exit_tree() -> void:
	if GameManager.player == self:
		GameManager.player = null

func _physics_process(delta: float) -> void:
	if GameManager.is_paused_for_upgrade:
		return

	# Max HP follows GameManager.get_max_hp() every frame: a gain (a
	# Helmet found mid-run, a max-HP upgrade) is free extra HP, and a
	# drop just lowers the cap. The drop matters at run start - this
	# node's _ready() runs before Main.gd's GameManager.reset(), so the
	# first value it read may still carry last run's armour.
	var new_max: float = GameManager.get_max_hp()
	if new_max > max_hp:
		hp += (new_max - max_hp)
	max_hp = new_max
	hp = minf(hp, max_hp)

	# HP/sec from the permanent Health Regeneration upgrade plus this
	# run's Vitality Elixir passive - the one place regen is applied.
	var regen_rate: float = GameManager.get_health_regen_rate()
	if regen_rate > 0.0 and hp < max_hp:
		hp = min(hp + regen_rate * delta, max_hp)

	var input_dir: Vector2 = get_input_dir()
	velocity = input_dir * base_speed * GameManager.get_speed_mult()
	move_and_slide()
	_update_sprite(input_dir)

	if invuln_timer > 0:
		invuln_timer -= delta
		modulate.a = 0.5 if int(invuln_timer * 10) % 2 == 0 else 1.0
	else:
		modulate.a = 1.0
	_update_shake(delta)

	fire_timer -= delta
	if fire_timer <= 0:
		try_fire()
		fire_timer = attack_cooldown * GameManager.get_cooldown_mult()

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

	# Only the Laser Pistol fires from here. Every other weapon has its
	# own caster node under Player (Forcefield, TornadoCaster,
	# GrenadeCaster, FireballCaster) with its own cooldown and its own
	# scene - iterating GameManager.weapons here would fire a second,
	# broken copy of each of those as a laser projectile.
	var stats: Dictionary = GameManager.weapons["laser_pistol"]
	if stats["level"] <= 0:
		return
	var projectile_count: int = GameManager.get_projectile_count("laser_pistol")
	var shots: int = min(projectile_count, enemies.size())
	var damage: float = stats["damage"] * GameManager.get_damage_mult()

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

# Hit feedback. The flash tweens the *sprite's* modulate so it stays
# independent of the invulnerability blink, which writes this node's
# modulate.a every physics frame. Both use real time: a call_deferred()
# reset runs at the end of the same tick, before anything is drawn, so
# the effect would never be visible.
const HIT_FLASH_TIME := 0.1
const SHAKE_DURATION := 0.15
const SHAKE_STRENGTH := 5.0
var shake_time: float = 0.0
var _flash_tween: Tween = null

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	sprite.modulate = Color(1.0, 0.35, 0.35)
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, HIT_FLASH_TIME)

# Random camera offset that decays to zero over SHAKE_DURATION; driven
# from _physics_process so it actually plays out over several frames.
func _update_shake(delta: float) -> void:
	if shake_time > 0.0:
		shake_time -= delta
		var strength: float = SHAKE_STRENGTH * max(shake_time, 0.0) / SHAKE_DURATION
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

# pierce_invuln: land even inside the 0.5s of invulnerability a hit
# grants - for a telegraphed attack the player had every chance to dodge
# (the Ancient Keeper's rock slam, RockSlam.gd), which a stray contact
# tick a moment earlier must not cancel. It still grants i-frames after.
func take_damage(amount: float, pierce_invuln: bool = false) -> void:
	if GameManager.is_paused_for_upgrade or (invuln_timer > 0 and not pierce_invuln):
		return
	hp -= amount
	invuln_timer = 0.5
	_flash()
	shake_time = SHAKE_DURATION
	if hp <= 0:
		die()

func die() -> void:
	# GameManager.end_run() flags the game over, writes any coins still
	# waiting on the debounced save and emits player_died (which opens the
	# HUD's game-over panel) - the same path the pause menu's Quit takes,
	# so a crash right after death can't lose the last second's pickups.
	GameManager.end_run()
	get_tree().paused = true
