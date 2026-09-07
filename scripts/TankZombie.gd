extends "res://scripts/Zombie.gd"

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
	add_to_group("tank_zombies")
	dash_timer = dash_interval

func _process(delta: float) -> void:
	# Base _process() is overridden here (different per-state
	# movement), so slow_timer's countdown has to happen here too -
	# Zombie's _process() never runs for a TankZombie instance.
	if slow_timer > 0.0:
		slow_timer -= delta
	var speed_mult: float = SLOWED_SPEED_MULT if slow_timer > 0.0 else 1.0

	# A knockback shoves it in every state: it replaces chasing, and
	# displaces a telegraph or dash without cancelling them.
	var knocked: bool = _update_knockback(delta)
	match state:
		State.CHASE:
			if not knocked:
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

	# Called unconditionally across every state (not just CHASE, where
	# base Zombie's _process() would call it) - see _update_facing()'s
	# own comment: the sprite should always track the player's current
	# position, even mid-TELEGRAPH/DASH where actual movement follows
	# a direction locked in back at _start_telegraph().
	_update_facing()
	_update_contact_damage(delta)

func _start_telegraph() -> void:
	state = State.TELEGRAPH
	state_elapsed = 0.0
	sprite.modulate = Color(1.0, 0.6, 0.1)
	var player: Node2D = GameManager.player
	dash_direction = (player.global_position - global_position).normalized() if player != null else Vector2.RIGHT

func _start_dash() -> void:
	state = State.DASH
	state_elapsed = 0.0
	sprite.modulate = Color.WHITE

# Plays the dash cycle above forward instead of assuming a straight walk
# (Zombie.predict_position()): a tank that is telegraphing stands still
# and then covers dash_speed * dash_duration (380px) along dash_direction,
# which a walk at its 30px/s base speed puts nowhere near - grenades led
# that way landed where no tank would be. A dash due to start inside the
# window (dash_timer running out mid-chase) is played out too, aimed at
# `player_pos` since that is where _start_telegraph() would aim it.
# dash_interval (8s) is far longer than any lead time, so at most one
# cycle is ever in the window.
func predict_position(lead_time: float, player_pos: Vector2) -> Vector2:
	var pos: Vector2 = global_position
	var t: float = 0.0
	match state:
		State.CHASE:
			var chase_until: float = minf(dash_timer, lead_time)
			pos = _predict_chase(pos, player_pos, t, chase_until)
			t = chase_until
			if t < lead_time:
				t = minf(t + telegraph_time, lead_time)
				var dash_until: float = minf(t + dash_duration, lead_time)
				pos = _predict_dash(pos, (player_pos - pos).normalized(), t, dash_until)
				t = dash_until
		State.TELEGRAPH:
			t = minf(maxf(telegraph_time - state_elapsed, 0.0), lead_time)
			var dash_until: float = minf(t + dash_duration, lead_time)
			pos = _predict_dash(pos, dash_direction, t, dash_until)
			t = dash_until
		State.DASH:
			var dash_until: float = minf(maxf(dash_duration - state_elapsed, 0.0), lead_time)
			pos = _predict_dash(pos, dash_direction, t, dash_until)
			t = dash_until
	# Whatever is left of the window is spent chasing again.
	return _predict_chase(pos, player_pos, t, lead_time)

# The dash leg: straight along `direction` at dash_speed (slowed like the
# real dash in _process()) between `from_now` and `until` seconds ahead,
# through the player if that is where it leads - a dash never stops short.
func _predict_dash(pos: Vector2, direction: Vector2, from_now: float, until: float) -> Vector2:
	return pos + direction * _predicted_travel(dash_speed, from_now, until)

func _drop_loot() -> void:
	XPGemScript.spawn(red_xp_gem_scene, get_parent(), global_position)
