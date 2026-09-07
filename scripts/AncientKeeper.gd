extends "res://scripts/Zombie.gd"

# The Ancient Keeper: the boss the Boss Totem summons (BossTotem.gd).
# Zombie's chase, contact damage, damage numbers and death burst as-is,
# with boss-tier immunity to crowd control (like Reaper.gd), its own
# loot, and one attack of its own - the rock slam:
#
# Every slam_interval_min..max seconds (trigger to trigger), if the
# player is within slam_range, it stops and charges up (tinted red) for
# slam_telegraph_time while a red circle (RockSlam.gd) marks where the
# player is *headed* - their current velocity played forward over the
# telegraph. When the telegraph ends the ground there erupts and hits
# anyone still inside. The circle's radius is slam_dodge_fraction of
# the ground the player can cover during the telegraph, so someone who
# keeps running lands dead centre, someone who stops or turns the
# moment the circle appears clears it, and a late reaction gets hit.

const RockSlamScene: PackedScene = preload("res://scenes/RockSlam.tscn")

# Shown on the HUD's boss bar while this is alive (see HUD.gd).
@export var boss_name: String = "Ancient Keeper"
@export var slam_interval_min: float = 4.0
@export var slam_interval_max: float = 5.0
@export var slam_range: float = 600.0
@export var slam_damage: float = 45.0
@export var slam_telegraph_time: float = 1.5
@export var slam_dodge_fraction: float = 0.55
@export var slam_radius_min: float = 60.0
@export var slam_radius_max: float = 220.0
@export var boss_xp: int = 250
@export var boss_coins: int = 500

enum State { CHASE, CHARGE }

var state: State = State.CHASE
var slam_timer: float = 0.0
var charge_elapsed: float = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	slam_timer = _roll_slam_interval()

func _process(delta: float) -> void:
	match state:
		State.CHASE:
			_move_toward_player(delta)
			slam_timer -= delta
			if slam_timer <= 0.0 and _player_in_slam_range():
				_start_charge()
		State.CHARGE:
			charge_elapsed += delta
			if charge_elapsed >= slam_telegraph_time:
				_end_charge()
	_update_facing()
	_update_contact_damage(delta)

func apply_knockback(_direction: Vector2, _distance: float) -> void:
	pass

func apply_slow(_duration: float = 0.25) -> void:
	pass

func _roll_slam_interval() -> float:
	return randf_range(slam_interval_min, slam_interval_max)

func _player_in_slam_range() -> bool:
	var player: Node2D = GameManager.player
	return player != null and global_position.distance_to(player.global_position) <= slam_range

func _start_charge() -> void:
	var player: Node2D = GameManager.player
	if player == null:
		return
	state = State.CHARGE
	charge_elapsed = 0.0
	# Trigger to trigger, like TankZombie's dash_timer.
	slam_timer = _roll_slam_interval()
	sprite.modulate = Color(1.0, 0.45, 0.45)

	var player_speed: float = player.base_speed * GameManager.speed_mult
	var slam = RockSlamScene.instantiate()
	slam.radius = clampf(slam_dodge_fraction * player_speed * slam_telegraph_time, slam_radius_min, slam_radius_max)
	slam.damage = slam_damage
	slam.telegraph_time = slam_telegraph_time
	var world: Node = get_parent()
	world.add_child(slam)
	# Right after the floor (Main's first child) so the marker reads as
	# painted on the ground, under the sprites, not over them.
	world.move_child(slam, mini(1, world.get_child_count() - 1))
	slam.global_position = player.global_position + player.velocity * slam_telegraph_time

func _end_charge() -> void:
	state = State.CHASE
	sprite.modulate = Color.WHITE

# Stands still for the rest of a charge, then chases as Zombie does.
func predict_position(lead_time: float, player_pos: Vector2) -> Vector2:
	if state != State.CHARGE:
		return super.predict_position(lead_time, player_pos)
	var still_for: float = minf(maxf(slam_telegraph_time - charge_elapsed, 0.0), lead_time)
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
