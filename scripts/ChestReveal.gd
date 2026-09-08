extends Control

# The chest-opening reveal on the HUD (design: docs/inventory-extraction-
# plan.md; the look is Vampire Survivors' treasure chests). The run
# pauses (GameManager.open_chest()) and a "Treasure Found!" panel comes
# up with the closed chest. On Open - or after a beat - the chest springs
# open with a burst, beams of light fan up out of it, sparkles and coins
# fountain out while the coin counter ticks up, and the piece rises
# spinning out of the chest into the light; at the top it settles with a
# starburst, its name, rarity and affix lines, and where it went (worn /
# stowed / left behind). Rarity sets the fanfare (FANFARE): how many
# beams, how many coins, how long the show runs, whether the screen
# flashes. Any click or key skips ahead to the settled piece; one more
# closes the panel, and GameManager.close_chest() resumes the run.
# PROCESS_MODE_ALWAYS, so everything here animates while the tree is
# paused; the tweens and particles inherit that.

enum State { HIDDEN, WAIT_OPEN, OPENING, SHOWING, SETTLED }

const OPEN_WAIT := 1.2
const OPENING_TIME := 0.5
const COUNT_TIME := 1.6
const FLASH_TIME := 0.6
# Per rarity (RARITY_DEFS order): beams fanning out of the chest, coins
# thrown, sparkles alive at once, seconds the show runs before the piece
# settles, and the white flash's strength at the settle.
const FANFARE := [
	{"beams": 1, "coins": 12, "sparkles": 24, "show": 1.2, "flash": 0.0},
	{"beams": 1, "coins": 24, "sparkles": 48, "show": 1.6, "flash": 0.0},
	{"beams": 3, "coins": 40, "sparkles": 80, "show": 2.2, "flash": 0.6},
	{"beams": 5, "coins": 80, "sparkles": 140, "show": 3.0, "flash": 0.9},
]
# Panel-local positions (the panel is 460 x 640).
const CHEST_POS := Vector2(230.0, 470.0)
const ITEM_START := Vector2(230.0, 440.0)
const ITEM_END := Vector2(230.0, 190.0)

var state: State = State.HIDDEN
var elapsed: float = 0.0
var count_elapsed: float = 0.0
var item: Dictionary = {}
var outcome: Dictionary = {}
var fanfare: Dictionary = FANFARE[0]
var coins_gained: int = 0

@onready var dim: ColorRect = $Dim
@onready var panel: Panel = $Panel
@onready var fx: Control = $Panel/Fx
@onready var chest: AnimatedSprite2D = $Panel/Chest
@onready var burst: CPUParticles2D = $Panel/Burst
@onready var sparkles: CPUParticles2D = $Panel/Sparkles
@onready var coins: CPUParticles2D = $Panel/Coins
@onready var title_label: Label = $Panel/Title
@onready var coin_label: Label = $Panel/CoinLabel
@onready var item_cell: Panel = $Panel/ItemCell
@onready var name_label: Label = $Panel/NameLabel
@onready var affix_label: Label = $Panel/AffixLabel
@onready var outcome_label: Label = $Panel/OutcomeLabel
@onready var prompt_label: Label = $Panel/PromptLabel
@onready var flash: ColorRect = $Flash

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	chest.position = CHEST_POS
	burst.position = CHEST_POS + Vector2(0.0, -20.0)
	sparkles.position = CHEST_POS + Vector2(0.0, -30.0)
	coins.position = CHEST_POS + Vector2(0.0, -30.0)
	item_cell.pivot_offset = item_cell.size / 2.0

# Connected to GameManager.chest_opened.
func play(new_item: Dictionary, new_outcome: Dictionary) -> void:
	item = new_item
	outcome = new_outcome
	var rarity: int = clampi(int(item["rarity"]), 0, FANFARE.size() - 1)
	fanfare = FANFARE[rarity]
	coins_gained = int(outcome.get("coins", 0))
	var color: Color = GameManager.RARITY_DEFS[rarity]["color"]
	fx.setup(fanfare["beams"], color, CHEST_POS + Vector2(0.0, -40.0))
	sparkles.color = color
	sparkles.amount = fanfare["sparkles"]
	coins.amount = fanfare["coins"]
	sparkles.emitting = false
	coins.emitting = false
	burst.emitting = false
	chest.play("closed")
	title_label.text = "Treasure Found!"
	coin_label.text = ""
	coin_label.visible = false
	item_cell.set_item(item)
	item_cell.visible = false
	item_cell.scale = Vector2.ONE
	_place_item(0.0)
	name_label.text = "%s %s" % [GameManager.rarity_name(item), GameManager.item_name(item)]
	name_label.add_theme_color_override("font_color", color)
	var lines: PackedStringArray = []
	for affix in item["affixes"]:
		lines.append(GameManager.affix_text(affix))
	affix_label.text = "\n".join(lines)
	outcome_label.text = _outcome_text()
	name_label.visible = false
	affix_label.visible = false
	outcome_label.visible = false
	prompt_label.text = "Click or press Space to open"
	prompt_label.visible = true
	flash.color = Color(1.0, 1.0, 1.0, 0.0)
	dim.color = Color(0.0, 0.0, 0.0, 0.0)
	create_tween().tween_property(dim, "color:a", 0.6, 0.2)
	visible = true
	state = State.WAIT_OPEN
	elapsed = 0.0
	count_elapsed = 0.0

func _outcome_text() -> String:
	var left = outcome.get("left")
	var displaced = outcome.get("displaced")
	match outcome.get("outcome", ""):
		"worn":
			if left != null:
				return "Worn!   %s left behind" % _short_name(left)
			if displaced != null:
				return "Worn!   %s stowed in your backpack" % _short_name(displaced)
			return "Worn!"
		"stowed":
			return "Stowed in your backpack"
		"swapped":
			return "Stowed   -   %s left behind" % _short_name(left)
		"left":
			return "Backpack full   -   left behind"
	return ""

func _short_name(piece: Dictionary) -> String:
	return "%s %s" % [GameManager.rarity_name(piece), GameManager.item_name(piece)]

func _process(delta: float) -> void:
	if state == State.HIDDEN:
		return
	elapsed += delta
	match state:
		State.WAIT_OPEN:
			if elapsed >= OPEN_WAIT:
				_open()
		State.OPENING:
			fx.progress = clampf(elapsed / OPENING_TIME, 0.0, 1.0)
			if elapsed >= OPENING_TIME:
				_show()
		State.SHOWING:
			count_elapsed += delta
			var t: float = clampf(elapsed / fanfare["show"], 0.0, 1.0)
			_place_item(t)
			_tick_counter()
			if t >= 1.0:
				_settle()
		State.SETTLED:
			count_elapsed += delta
			_tick_counter()

func _input(event: InputEvent) -> void:
	if state == State.HIDDEN:
		return
	var pressed: bool = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	elif event is InputEventKey and event.pressed and not event.echo:
		pressed = event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	advance()

# What a click or key does: open, skip to the settled piece, close.
func advance() -> void:
	match state:
		State.WAIT_OPEN:
			_open()
		State.OPENING, State.SHOWING:
			_settle()
		State.SETTLED:
			finish()

func _open() -> void:
	state = State.OPENING
	elapsed = 0.0
	prompt_label.visible = false
	chest.play("open")
	burst.restart()

func _show() -> void:
	state = State.SHOWING
	elapsed = 0.0
	count_elapsed = 0.0
	fx.progress = 1.0
	sparkles.emitting = true
	coins.restart()
	item_cell.visible = true
	coin_label.visible = true
	_tick_counter()

# The piece rises out of the chest into the light, easing out, spinning
# like a flipped coin (scale.x runs through three full turns and ends
# facing forward).
func _place_item(t: float) -> void:
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	item_cell.position = ITEM_START.lerp(ITEM_END, eased) - item_cell.size / 2.0
	item_cell.scale = Vector2(cos(t * PI * 6.0), 1.0)

func _tick_counter() -> void:
	var t: float = clampf(count_elapsed / COUNT_TIME, 0.0, 1.0)
	coin_label.text = "+%d coins" % int(round(coins_gained * t))

func _settle() -> void:
	state = State.SETTLED
	elapsed = 0.0
	fx.progress = 1.0
	chest.play("open")
	sparkles.emitting = false
	item_cell.visible = true
	coin_label.visible = true
	_place_item(1.0)
	fx.starburst(ITEM_END)
	name_label.visible = true
	affix_label.visible = true
	outcome_label.visible = true
	prompt_label.text = "Click or press Space to continue"
	prompt_label.visible = true
	if fanfare["flash"] > 0.0:
		flash.color = Color(1.0, 1.0, 1.0, fanfare["flash"])
		create_tween().tween_property(flash, "color:a", 0.0, FLASH_TIME)

func finish() -> void:
	if state == State.HIDDEN:
		return
	state = State.HIDDEN
	visible = false
	sparkles.emitting = false
	coins.emitting = false
	burst.emitting = false
	GameManager.close_chest()
