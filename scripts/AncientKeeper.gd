extends "res://scripts/Zombie.gd"

# The Ancient Keeper: the boss the Boss Totem summons (BossTotem.gd).
# Zombie's chase, contact damage, damage numbers and death burst as-is,
# with boss-tier immunity to crowd control (like Reaper.gd), its own
# loot, and two attacks of its own, both built on the same ground ring
# (RockSlam.gd): a circle that sticks to the player's feet, then locks
# in place (turns amber) for its lock window and erupts, hitting anyone
# still inside - through their contact-damage i-frames. Every ring is
# always winnable by reacting: its radius is the ground the player
# covers in its lock window minus reaction_time, so anyone who starts
# moving within reaction_time of the ring turning amber (from a
# standstill, in any direction) and keeps going clears it; someone
# already moving clears it with room to spare; standing still, or
# starting later than that, gets hit. Sized off the player's actual
# speed so a speed passive keeps the same window in seconds.
#
# The ROCK SLAM (State.CHARGE): every slam_interval_min..max seconds
# (trigger to trigger), with the player within attack_range, it stops
# and charges (tinted red, flaring amber when the ring locks) for
# slam_telegraph_time - one big ring, one big hit.
#
# The ROCK BARRAGE (State.BARRAGE): every barrage_cooldown seconds, it
# stops just long enough (tinted orange) to launch barrage_count small
# rings barrage_spacing apart - each on a shorter telegraph, with fewer
# rocks, a quicker fade and a lighter hit - then walks on while they
# play out. Same targeting and the same reaction window as the slam; a
# player who reacts to the first ring and keeps moving clears them all,
# and all of them landing add up to one slam.
#
# Both cooldowns run all the time; an attack only starts from CHASE,
# and the slam goes first if both are due.

const RockSlamScene: PackedScene = preload("res://scenes/RockSlam.tscn")
const CHARGE_TINT := Color(1.0, 0.45, 0.45)
const LOCK_TINT := Color(1.0, 0.75, 0.35)
const BARRAGE_TINT := Color(1.0, 0.6, 0.25)

# Shown on the HUD's boss bar while this is alive (see HUD.gd).
@export var boss_name: String = "Ancient Keeper"
# Shared by both attacks.
@export var attack_range: float = 600.0
@export var reaction_time: float = 0.4
# The rock slam.
@export var slam_interval_min: float = 4.0
@export var slam_interval_max: float = 5.0
@export var slam_damage: float = 45.0
@export var slam_telegraph_time: float = 1.8
@export var slam_lock_time: float = 1.0
@export var slam_radius_min: float = 60.0
@export var slam_radius_max: float = 220.0
# The rock barrage.
@export var barrage_cooldown: float = 3.0
@export var barrage_count: int = 3
@export var barrage_spacing: float = 0.25
@export var barrage_damage: float = 15.0
@export var barrage_telegraph_time: float = 1.1
@export var barrage_lock_time: float = 0.75
@export var barrage_radius_min: float = 32.0
@export var barrage_radius_max: float = 140.0
@export var barrage_rock_count: int = 3
@export var barrage_erupt_lifetime: float = 0.5
@export var boss_xp: int = 250
@export var boss_coins: int = 500

enum State { CHASE, CHARGE, BARRAGE }

var state: State = State.CHASE
var slam_timer: float = 0.0
var charge_elapsed: float = 0.0
var barrage_timer: float = 0.0
var barrage_elapsed: float = 0.0
var barrage_launched: int = 0

func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	slam_timer = _roll_slam_interval()
	barrage_timer = barrage_cooldown

func _process(delta: float) -> void:
	slam_timer -= delta
	barrage_timer -= delta
	match state:
		State.CHASE:
			_move_toward_player(delta)
			if _player_in_range():
				if slam_timer <= 0.0:
					_start_charge()
				elif barrage_timer <= 0.0:
					_start_barrage()
		State.CHARGE:
			charge_elapsed += delta
			# Flares brighter the moment the ring locks - the same cue
			# RockSlam gives on the ground, on the golem itself.
			if charge_elapsed >= slam_telegraph_time - minf(slam_lock_time, slam_telegraph_time):
				sprite.modulate = LOCK_TINT
			if charge_elapsed >= slam_telegraph_time:
				_end_charge()
		State.BARRAGE:
			barrage_elapsed += delta
			# Launches every ring that is due this frame (a long frame can
			# owe more than one). _launch_barrage_ring() ends the barrage
			# itself if the player is gone, which is what the state check
			# in the condition is for.
			while state == State.BARRAGE and barrage_launched < barrage_count \
					and barrage_elapsed >= barrage_launched * barrage_spacing:
				_launch_barrage_ring()
			if state == State.BARRAGE and barrage_launched >= barrage_count:
				_end_barrage()
	_update_facing()
	_update_contact_damage(delta)

func apply_knockback(_direction: Vector2, _distance: float) -> void:
	pass

func apply_slow(_duration: float = 0.25) -> void:
	pass

func _roll_slam_interval() -> float:
	return randf_range(slam_interval_min, slam_interval_max)

func _player_in_range() -> bool:
	var player: Node2D = GameManager.player
	return player != null and global_position.distance_to(player.global_position) <= attack_range

# One ground ring on the player (RockSlam.gd), sized so its lock window
# minus reaction_time is exactly what it takes to walk out of it - see
# the header. Returns the ring so a caller can tweak its eruption.
func _spawn_ring(player: Node2D, telegraph: float, lock: float, radius_min: float, radius_max: float, ring_damage: float) -> Node2D:
	# The lock can't outlast the telegraph it is the tail of.
	lock = minf(lock, telegraph)
	var player_speed: float = player.base_speed * GameManager.speed_mult
	var dodge_time: float = maxf(lock - reaction_time, 0.0)
	var ring = RockSlamScene.instantiate()
	ring.radius = clampf(player_speed * dodge_time, radius_min, radius_max)
	ring.damage = ring_damage
	ring.telegraph_time = telegraph
	ring.lock_time = lock
	var world: Node = get_parent()
	world.add_child(ring)
	# Right after the floor (Main's first child) so the marker reads as
	# painted on the ground, under the sprites, not over them.
	world.move_child(ring, mini(1, world.get_child_count() - 1))
	# Starts on the player; RockSlam keeps it there until it locks.
	ring.global_position = player.global_position
	return ring

func _start_charge() -> void:
	var player: Node2D = GameManager.player
	if player == null:
		return
	state = State.CHARGE
	charge_elapsed = 0.0
	# Trigger to trigger, like TankZombie's dash_timer.
	slam_timer = _roll_slam_interval()
	sprite.modulate = CHARGE_TINT
	_spawn_ring(player, slam_telegraph_time, slam_lock_time, slam_radius_min, slam_radius_max, slam_damage)

func _end_charge() -> void:
	state = State.CHASE
	sprite.modulate = Color.WHITE

func _start_barrage() -> void:
	if GameManager.player == null:
		return
	state = State.BARRAGE
	barrage_elapsed = 0.0
	barrage_launched = 0
	barrage_timer = barrage_cooldown
	sprite.modulate = BARRAGE_TINT
	if barrage_count <= 0:
		_end_barrage()
		return
	_launch_barrage_ring()

func _launch_barrage_ring() -> void:
	var player: Node2D = GameManager.player
	if player == null:
		_end_barrage()
		return
	var ring = _spawn_ring(player, barrage_telegraph_time, barrage_lock_time, barrage_radius_min, barrage_radius_max, barrage_damage)
	ring.rock_count = barrage_rock_count
	ring.erupt_lifetime = barrage_erupt_lifetime
	barrage_launched += 1

func _end_barrage() -> void:
	state = State.CHASE
	sprite.modulate = Color.WHITE

# Stands still for the rest of a charge, or of a barrage's launch window
# (it walks on the moment the last ring is out), then chases as Zombie
# does.
func predict_position(lead_time: float, player_pos: Vector2) -> Vector2:
	var still_for: float
	match state:
		State.CHARGE:
			still_for = slam_telegraph_time - charge_elapsed
		State.BARRAGE:
			still_for = (barrage_count - 1) * barrage_spacing - barrage_elapsed
		_:
			return super.predict_position(lead_time, player_pos)
	still_for = minf(maxf(still_for, 0.0), lead_time)
	return _predict_chase(global_position, player_pos, still_for, lead_time)

# One big gem and one big coin pile rather than a shower of each - a
# single pickup node apiece however much they're worth. The gem is
# placed directly (not through XPGem.spawn()) so the field cap can't
# fold the boss drop into some stray gem.
func _drop_loot() -> void:
	var gem = xp_gem_scene.instantiate()
	gem.xp_value = boss_xp
	get_parent().add_child(gem)
	gem.global_position = global_position
	var coin = coin_pickup_scene.instantiate()
	coin.coin_value = boss_coins
	coin.scale = Vector2(2.0, 2.0)
	get_parent().add_child(coin)
	coin.global_position = global_position + Vector2(24.0, 0.0)
