extends Area2D

# Enemies use Area2D (not CharacterBody2D) so they're cheap to spawn
# in large numbers - no physics collision resolution needed, just
# "am I touching the player" and "move toward the player."
#
# This is the base enemy (Zombie). TankZombie.gd extends this script
# and overrides _process()/_drop_loot() for its dash attack and
# different loot, while reusing take_damage()/die()/contact
# damage/damage numbers/coin drops as-is.

@export var speed: float = 60.0
@export var max_hp: float = 20.0
@export var contact_damage: float = 10.0
@export var xp_gem_scene: PackedScene = preload("res://scenes/XPGem.tscn")
@export var xp_gem_count: int = 1
@export var coin_pickup_scene: PackedScene = preload("res://scenes/CoinPickup.tscn")
@export var damage_number_scene: PackedScene = preload("res://scenes/DamageNumber.tscn")
@export var magnet_pickup_scene: PackedScene = preload("res://scenes/MagnetPickup.tscn")
@export var gold_dream_pickup_scene: PackedScene = preload("res://scenes/GoldDreamPickup.tscn")
@export var death_burst_scene: PackedScene = preload("res://scenes/DeathBurst.tscn")

# Damage numbers are pooled - see DamageNumber.spawn(). XP gems are
# capped on the field - see XPGem.spawn().
const DamageNumberScript := preload("res://scripts/DamageNumber.gd")
const XPGemScript := preload("res://scripts/XPGem.gd")

# 0.1% chance per kill at Luck x1; both the Magnet and the Gold Dream
# roll multiply it by GameManager.get_luck_mult() (0.2% at max luck).
const MAGNET_DROP_CHANCE := 0.001

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

# Most enemies are slower than the player (this base Zombie's `speed`
# is well under Player.base_speed), so over a long run plenty fall so
# far behind they'll never catch up - dead weight still paying for
# movement, contact-damage checks and animation every frame, and
# nothing ever fights them again until EnemySpawner wipes the field at
# the 15:01 Reaper. One that has fallen fully off the edge of the
# screen behind the player wraps round to the edge ahead of them
# instead, keeping its place along the other axis - see ScreenWrap.gd
# (XP gems do exactly the same) - so a straggler comes back as an
# actual threat instead of permanent simulated cost for nothing, and a
# batch of them comes back spread along the edge the way they were
# spread behind, not stacked on one point. WRAP_MARGIN allows for the
# biggest sprite that takes this (the Reaper at 5x) being fully hidden
# first; WRAP_INSET puts it a body inside the edge so it walks in
# rather than pops in. The Ancient Keeper has its own _process() and
# never wraps - it belongs at its totem.
const ScreenWrapScript := preload("res://scripts/ScreenWrap.gd")
const WRAP_MARGIN := 96.0
const WRAP_INSET := 32.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if slow_timer > 0.0:
		slow_timer -= delta
	if _wrap_if_behind():
		return
	if not _update_knockback(delta):
		_move_toward_player(delta)
	_update_facing()
	_update_contact_damage(delta)

# True when this enemy just wrapped round the screen (see above), in
# which case the frame's movement is skipped - it starts its chase
# afresh from the far edge next frame.
func _wrap_if_behind() -> bool:
	var player: Node2D = GameManager.player
	if player == null:
		return false
	return ScreenWrapScript.wrap_across_screen(self, player, WRAP_MARGIN, WRAP_INSET)

func apply_slow(duration: float = 0.25) -> void:
	slow_timer = duration

# Knockback (a sword slash, today): the enemy is shoved `distance` px
# along `direction` as an impulse velocity that decelerates at
# KNOCKBACK_DECEL - its starting speed is whatever covers exactly that
# distance (v^2 / 2a) - and chases again once it stops. A second hit
# mid-shove restarts the shove rather than stacking onto it.
const KNOCKBACK_DECEL := 1200.0
var knockback_velocity: Vector2 = Vector2.ZERO

func apply_knockback(direction: Vector2, distance: float) -> void:
	if distance <= 0.0 or direction == Vector2.ZERO:
		return
	knockback_velocity = direction.normalized() * sqrt(2.0 * KNOCKBACK_DECEL * distance)

# Moves the enemy along its knockback; true while one is in progress,
# during which it replaces normal chasing (see _process() here and
# TankZombie's).
func _update_knockback(delta: float) -> bool:
	if knockback_velocity == Vector2.ZERO:
		return false
	global_position += knockback_velocity * delta
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_DECEL * delta)
	return true

func _move_toward_player(delta: float) -> void:
	var player: Node2D = GameManager.player
	if player == null:
		return
	var dir: Vector2 = (player.global_position - global_position).normalized()
	var effective_speed: float = speed * (SLOWED_SPEED_MULT if slow_timer > 0.0 else 1.0)
	global_position += dir * effective_speed * delta

# Where this enemy will be `lead_time` seconds from now if the player
# stays at `player_pos` - what GrenadeCaster leads its throws with. The
# base enemy just keeps walking straight at the player (exactly what
# _move_toward_player() does), at SLOWED_SPEED_MULT for as long as any
# slow still has to run, and stops on reaching it rather than walking
# through. TankZombie overrides this to play its telegraph/dash out
# first. A knockback in progress is ignored: it is over in a fraction of
# a second and its direction has nothing to do with the chase.
func predict_position(lead_time: float, player_pos: Vector2) -> Vector2:
	return _predict_chase(global_position, player_pos, 0.0, lead_time)

# The chase leg of a prediction: from `pos` at `from_now` seconds ahead
# straight toward `player_pos` until `until` seconds ahead - never past
# it. Offsetting by from_now is what lets the slow wear off correctly
# partway through a multi-leg prediction (see _predicted_travel()).
func _predict_chase(pos: Vector2, player_pos: Vector2, from_now: float, until: float) -> Vector2:
	var to_player: Vector2 = player_pos - pos
	var distance: float = to_player.length()
	if distance <= 0.0 or until <= from_now:
		return pos
	return pos + to_player / distance * minf(_predicted_travel(speed, from_now, until), distance)

# Distance covered at `base_speed` between `from_now` and `until` seconds
# ahead, with the slow status (if any) expiring partway: slow_timer counts
# down in real time, so the first slow_timer seconds of the window run at
# SLOWED_SPEED_MULT and the rest at full speed.
func _predicted_travel(base_speed: float, from_now: float, until: float) -> float:
	if until <= from_now:
		return 0.0
	var time: float = until - from_now
	var slowed: float = clampf(slow_timer - from_now, 0.0, time)
	return base_speed * (slowed * SLOWED_SPEED_MULT + (time - slowed))

# Split out from _move_toward_player() so the sprite always faces
# wherever the player currently is, independent of whatever direction
# the enemy is actually moving in - matters for TankZombie, whose
# TELEGRAPH/DASH states move along a direction locked in when the
# charge started (see TankZombie._start_telegraph()), which can go
# stale relative to the player's live position by the time the dash
# actually plays out.
func _update_facing() -> void:
	var player: Node2D = GameManager.player
	if player == null:
		return
	var dir_to_player: Vector2 = (player.global_position - global_position).normalized()
	sprite.play(_facing_animation(dir_to_player))

# Picks whichever axis (horizontal/vertical) dominates `dir` and
# returns the matching walk_* animation - the sprite sheets are
# 4-directional (no diagonal frames), so this is the standard way to
# collapse an arbitrary movement vector onto one of the 4. Recomputed
# every frame from raw direction, so an enemy approaching from close
# to a 45-degree angle (extremely common - enemies spawn all around
# the player) would otherwise flicker between two animations on tiny
# frame-to-frame jitter; AnimatedSprite2D.play() restarts from frame 0
# on every actual switch, so that flicker reads as the walk cycle
# constantly stuttering/resetting even though each individual frame is
# a perfectly valid image (confirmed: ~2% jitter around the diagonal
# caused 20 switches in 40 ticks without this guard). facing_horizontal
# is sticky - switching away from the current axis needs a clear
# margin, not just barely crossing the exact diagonal.
var facing_horizontal: bool = false

func _facing_animation(dir: Vector2) -> String:
	const HYSTERESIS := 1.15
	if facing_horizontal:
		facing_horizontal = abs(dir.x) * HYSTERESIS > abs(dir.y)
	else:
		facing_horizontal = abs(dir.x) > abs(dir.y) * HYSTERESIS

	if facing_horizontal:
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
	# Already dying (die() is queued below): a second hit in the same frame
	# - a Tornado tick and a Grenade blast, say - would put another damage
	# number on a corpse and restart its flash.
	if is_dead:
		return
	hp -= amount
	if GameManager.show_damage_numbers:
		_spawn_damage_number(amount)
	_flash()
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
	DamageNumberScript.spawn(damage_number_scene, get_parent(), amount, self)

func die() -> void:
	GameManager.enemies_defeated += 1
	_drop_loot()
	# A chest, luck-weighted and throttled (GameManager.try_drop_chest).
	GameManager.try_drop_chest(global_position)

	# A coin every 10th kill - every kill while a Gold Dream is running.
	if GameManager.is_gold_dream_active() or GameManager.enemies_defeated % 10 == 0:
		var coin = coin_pickup_scene.instantiate()
		get_parent().add_child(coin)
		coin.global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))

	if randf() < MAGNET_DROP_CHANCE * GameManager.get_luck_mult():
		var magnet = magnet_pickup_scene.instantiate()
		get_parent().add_child(magnet)
		magnet.global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))

	# The Gold Dream power-up is just as rare as the Magnet (its own roll).
	if randf() < MAGNET_DROP_CHANCE * GameManager.get_luck_mult():
		var dream = gold_dream_pickup_scene.instantiate()
		get_parent().add_child(dream)
		dream.global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))

	# Spark burst at the corpse: one one-shot CPUParticles2D that frees
	# itself (see DeathBurst.tscn) rather than 8 ColorRects + 8 Tweens
	# per kill on the hottest path in the game.
	var burst = death_burst_scene.instantiate()
	# Positioned before add_child(): the burst starts emitting in its
	# _ready(), and particles spawned at the origin would sit on the
	# player instead of the corpse.
	burst.position = global_position
	get_parent().add_child(burst)

	queue_free()

# Overridden by TankZombie to drop a RedXPGem instead. xp_gem_count
# above 1 (e.g. Skeleton) spreads the extra gems out slightly so they
# don't spawn stacked exactly on top of each other - same small-offset
# idea as the coin/magnet drops in die(). Gems go through XPGem.spawn(),
# which folds a drop into an existing gem once the field is full.
func _drop_loot() -> void:
	for i in range(xp_gem_count):
		var offset: Vector2 = Vector2.ZERO if i == 0 else Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		XPGemScript.spawn(xp_gem_scene, get_parent(), global_position + offset)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		overlapping_player = body
		damage_tick_timer = 0.0

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		overlapping_player = null

# Brief red tint on hit. A Tween rather than call_deferred(): a deferred
# call runs at the end of the *same* tick, before anything is drawn, so
# a deferred reset made the flash invisible. Tweens this node's modulate
# (not the sprite's) so it stays independent of TankZombie's orange
# telegraph tint, which lives on sprite.modulate. Works unchanged for
# TankZombie even though it overrides _process(): nothing here depends
# on the per-frame loop.
const HIT_FLASH_TIME := 0.1
var _flash_tween: Tween = null

func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = Color(1.0, 0.35, 0.35)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, HIT_FLASH_TIME)
