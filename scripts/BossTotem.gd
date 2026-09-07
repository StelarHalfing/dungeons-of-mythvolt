extends Area2D

# The Boss Totem: a pillar WALK_MINUTES of straight walking to the left
# of where the player spawns, with a purple orb floating over it. Walk
# up to it and press E to summon the Ancient Keeper (AncientKeeper.gd),
# which appears SUMMON_DISTANCE away in a random direction; the orb goes
# out and the totem is spent for the rest of the run. Sits right after
# the Background in Main.tscn so it draws under the player and enemies.

const AncientKeeperScene: PackedScene = preload("res://scenes/AncientKeeper.tscn")
const WALK_MINUTES := 5.0
const SUMMON_DISTANCE := 260.0
const FALLBACK_WALK_SPEED := 140.0

var player_inside: bool = false
var used: bool = false
var _orb_tween: Tween = null

@onready var pillar: Sprite2D = $Pillar
@onready var orb: Sprite2D = $Orb
@onready var prompt: Label = $Prompt

func _ready() -> void:
	# The HUD's pointer (TotemPointer.gd) finds the totem through this.
	add_to_group("boss_totems")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.visible = false
	# The distance is fixed at spawn in the player's base walk speed
	# (speed boosts picked up mid-run make it a shorter trip). Read off
	# the Player node directly: this totem comes before Player in
	# Main.tscn, so Player._ready() - which publishes GameManager.player -
	# hasn't run yet.
	var player: Node2D = get_parent().get_node_or_null("Player")
	var walk_speed: float = player.base_speed if player != null else FALLBACK_WALK_SPEED
	var origin: Vector2 = player.global_position if player != null else Vector2.ZERO
	global_position = origin + Vector2(-walk_speed * WALK_MINUTES * 60.0, 0.0)
	_bob_orb()

func _bob_orb() -> void:
	var rest_y: float = orb.position.y
	_orb_tween = create_tween().set_loops()
	_orb_tween.tween_property(orb, "position:y", rest_y - 6.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_orb_tween.tween_property(orb, "position:y", rest_y, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if used or not player_inside:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		summon()
		get_viewport().set_input_as_handled()

func summon() -> void:
	if used:
		return
	used = true
	prompt.visible = false
	if _orb_tween != null:
		_orb_tween.kill()
	orb.visible = false
	pillar.modulate = Color(0.55, 0.55, 0.6)
	var keeper = AncientKeeperScene.instantiate()
	get_parent().add_child(keeper)
	keeper.global_position = global_position + Vector2.RIGHT.rotated(randf() * TAU) * SUMMON_DISTANCE

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		prompt.visible = not used

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		prompt.visible = false
