extends Area2D

# A treasure chest on the field (design: docs/inventory-extraction-
# plan.md, decisions 5 and 6). Dropped at a corpse by
# GameManager.try_drop_chest() or beside the Ancient Keeper's loot by
# spawn_chest(). Walking into it opens it: one piece of armour is rolled
# (min_rarity floors the rarity - the Keeper's chest is Rare or better)
# and handed to GameManager.open_chest(), which decides where the piece
# goes, pays the chest's gold, pauses the run and starts the HUD's
# reveal (ChestReveal.gd). The open chest lingers on the ground a moment
# once the run resumes, then goes. Left behind unopened it wraps round
# the screen edge like a gem (ScreenWrap.gd) rather than being lost.

const ScreenWrapScript := preload("res://scripts/ScreenWrap.gd")
const WRAP_MARGIN := 24.0
const WRAP_INSET := 16.0
const LINGER_TIME := 0.8

@export var min_rarity: int = 0

var opened: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# GameManager.can_drop_chest() counts this group: one on the field
	# at a time.
	add_to_group("chests")
	body_entered.connect(_on_body_entered)
	sprite.play("closed")

func _process(_delta: float) -> void:
	if opened:
		return
	var player: Node2D = GameManager.player
	if player == null:
		return
	ScreenWrapScript.wrap_across_screen(self, player, WRAP_MARGIN, WRAP_INSET)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		open()

# Returns the piece it held (empty if it was already open).
func open() -> Dictionary:
	if opened:
		return {}
	opened = true
	remove_from_group("chests")
	sprite.play("open")
	var item: Dictionary = GameManager.roll_armor(min_rarity)
	GameManager.open_chest(item)
	# The timer pauses with the tree, so this counts from when the
	# reveal closes and the run resumes.
	get_tree().create_timer(LINGER_TIME, false).timeout.connect(queue_free)
	return item
