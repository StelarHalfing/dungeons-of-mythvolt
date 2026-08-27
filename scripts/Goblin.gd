extends Area2D

# Enemies use Area2D (not CharacterBody2D) so they're cheap to spawn
# in large numbers - no physics collision resolution needed, just
# "am I touching the player" and "move toward the player."
#
# This is the base enemy (Goblin). Minotaur.gd extends this script
# and overrides _process()/_drop_loot() for its dash attack and
# different loot, while reusing take_damage()/die()/contact
# damage/damage numbers/coin drops as-is.

@export var speed: float = 60.0
@export var max_hp: float = 20.0
@export var contact_damage: float = 10.0
@export var xp_gem_scene: PackedScene = preload("res://scenes/XPGem.tscn")
@export var coin_pickup_scene: PackedScene = preload("res://scenes/CoinPickup.tscn")
@export var damage_number_scene: PackedScene = preload("res://scenes/DamageNumber.tscn")
@export var magnet_pickup_scene: PackedScene = preload("res://scenes/MagnetPickup.tscn")

const MAGNET_DROP_CHANCE := 0.001  # 0.1% chance per kill

var hp: float
var damage_tick_timer: float = 0.0
var overlapping_player: Node2D = null
var is_dead: bool = false

# Slow status (e.g. Tornado): while slow_timer > 0, movement speed is
# multiplied by SLOWED_SPEED_MULT. The timer counts down on its own
# each frame rather than something un-slowing it on exit - simpler,
# and avoids depending on whichever node's _process() happens to run
# first each frame. apply_slow() just keeps refreshing it while the
# source effect is still in contact.
const SLOWED_SPEED_MULT := 0.4
var slow_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if slow_timer > 0.0:
		slow_timer -= delta
	_move_toward_player(delta)
	_update_contact_damage(delta)

func apply_slow(duration: float = 0.25) -> void:
	slow_timer = duration

func _move_toward_player(delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player: Node2D = players[0]
		var dir: Vector2 = (player.global_position - global_position).normalized()
		var effective_speed: float = speed * (SLOWED_SPEED_MULT if slow_timer > 0.0 else 1.0)
		global_position += dir * effective_speed * delta
		sprite.play(_facing_animation(dir))

# Picks whichever axis (horizontal/vertical) dominates `dir` and
# returns the matching walk_* animation - the sprite sheets are
# 4-directional (no diagonal frames), so this is the standard way to
# collapse an arbitrary movement vector onto one of the 4.
func _facing_animation(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "walk_right" if dir.x > 0.0 else "walk_left"
	else:
		return "walk_down" if dir.y > 0.0 else "walk_up"

func _update_contact_damage(delta: float) -> void:
	if overlapping_player != null:
		damage_tick_timer -= delta
		if damage_tick_timer <= 0:
			overlapping_player.take_damage(contact_damage)
			damage_tick_timer = 0.5

func take_damage(amount: float) -> void:
	hp -= amount
	if GameManager.show_damage_numbers:
		_spawn_damage_number(amount)
	# take_damage() can run mid physics-query-flush (a Projectile's
	# area_entered fires from inside it) - spawning loot and freeing
	# this node right here would change collision state while the
	# physics engine is still mid-pass, which errors. call_deferred()
	# pushes die() to just after the pass finishes instead. is_dead
	# guards against a second hit (e.g. Forcefield tick + projectile
	# same frame) queuing die() twice before the deferred call runs.
	if hp <= 0 and not is_dead:
		is_dead = true
		die.call_deferred()

func _spawn_damage_number(amount: float) -> void:
	var num = damage_number_scene.instantiate()
	get_parent().add_child(num)
	num.setup(amount, self)

func die() -> void:
	GameManager.enemies_defeated += 1
	_drop_loot()

	if GameManager.enemies_defeated % 10 == 0:
		var coin = coin_pickup_scene.instantiate()
		get_parent().add_child(coin)
		coin.global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))

	if randf() < MAGNET_DROP_CHANCE:
		var magnet = magnet_pickup_scene.instantiate()
		get_parent().add_child(magnet)
		magnet.global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))

	queue_free()

# Overridden by Minotaur to drop a RedXPGem instead.
func _drop_loot() -> void:
	var gem = xp_gem_scene.instantiate()
	get_parent().add_child(gem)
	gem.global_position = global_position

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		overlapping_player = body
		damage_tick_timer = 0.0

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		overlapping_player = null
