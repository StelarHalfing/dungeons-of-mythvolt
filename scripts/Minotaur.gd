extends "res://scripts/Goblin.gd"

# Every dash_interval seconds: brief telegraph (stands still, flashes
# orange) then charges in a straight line at the player's position
# (locked in at the moment the telegraph starts) for dash_duration
# seconds, then resumes normal chasing until the next cycle.

@export var red_xp_gem_scene: PackedScene = preload("res://scenes/RedXPGem.tscn")
@export var dash_interval: float = 8.0
@export var dash_duration: float = 1.0
@export var dash_speed: float = 380.0
@export var telegraph_time: float = 0.3

enum State { CHASE, TELEGRAPH, DASH }

var state: State = State.CHASE
var state_elapsed: float = 0.0
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	add_to_group("minotaurs")
	dash_timer = dash_interval

func _process(delta: float) -> void:
	# Base _process() is overridden here (different per-state
	# movement), so slow_timer's countdown has to happen here too -
	# Goblin's _process() never runs for a Minotaur instance.
	if slow_timer > 0.0:
		slow_timer -= delta
	var speed_mult: float = SLOWED_SPEED_MULT if slow_timer > 0.0 else 1.0

	match state:
		State.CHASE:
			_move_toward_player(delta)
			dash_timer -= delta
			if dash_timer <= 0.0:
				# Reset now so "once every 8 seconds" measures
				# trigger-to-trigger, regardless of how long the
				# telegraph/dash itself takes.
				dash_timer = dash_interval
				_start_telegraph()
		State.TELEGRAPH:
			state_elapsed += delta
			if state_elapsed >= telegraph_time:
				_start_dash()
		State.DASH:
			state_elapsed += delta
			global_position += dash_direction * dash_speed * speed_mult * delta
			if state_elapsed >= dash_duration:
				state = State.CHASE

	_update_contact_damage(delta)

func _start_telegraph() -> void:
	state = State.TELEGRAPH
	state_elapsed = 0.0
	sprite.modulate = Color(1.0, 0.6, 0.1)
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		dash_direction = (players[0].global_position - global_position).normalized()
	else:
		dash_direction = Vector2.RIGHT
	# Face (and hold) the charge direction through both TELEGRAPH and
	# DASH, since dash_direction is locked in right here and neither
	# state calls _move_toward_player() to update facing on its own.
	sprite.play(_facing_animation(dash_direction))

func _start_dash() -> void:
	state = State.DASH
	state_elapsed = 0.0
	sprite.modulate = Color.WHITE

func _drop_loot() -> void:
	var gem = red_xp_gem_scene.instantiate()
	get_parent().add_child(gem)
	gem.global_position = global_position
