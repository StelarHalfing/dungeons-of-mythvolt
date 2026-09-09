extends Panel

# The Equip bar: the Knight's portrait with the five wear slots around
# it (Helmet above, Armor and Shield beside, Gloves and Boots below),
# a Salvage zone and the coins. Slides in from the left edge while the
# Inventory tab is up and back out when it isn't (show_bar/hide_bar).
# Every slot is an ItemCell in "equip" mode filtered to its slot, so
# the drag-and-drop rules live in ItemCell.gd; this script only relays
# what happened to the InventoryScreen and shows what is equipped.
# The Salvage zone is a drop target on the bar itself: a piece dragged
# from the bag or straight off a slot and let go over it is salvaged
# (Epic and Legendary ask first, see InventoryScreen).
# run_mode (phase 6, the pause menu's Backpack panel) shows run_worn
# instead of equipped and turns the zone into "Drop".

signal equip_requested(item: Dictionary)
signal unequip_requested(slot: String)
signal salvage_requested(data: Dictionary, always_confirm: bool)
# run_mode only: a piece let go over the Drop zone is to be left behind.
signal drop_requested(data: Dictionary)

const ItemCellScene := preload("res://scenes/ItemCell.tscn")
const CELL_SIZE := Vector2(72, 72)
const SLIDE_TIME := 0.2
const HIDDEN_X := -340.0
const SHOWN_X := 0.0
# The slots, their captions and the portrait are laid out inside a
# fixed 300 x 314 block which _layout_slots() centres in the $Slots
# area, so the bar reads the same whatever height the screen gives it
# (600 in the pause menu's Backpack panel, the window height minus the
# tabs row on the Inventory screen). Positions are block-local.
const BLOCK_SIZE := Vector2(300, 314)
const SLOT_POSITIONS := {
	"helmet": Vector2(114, 0),
	"armor": Vector2(22, 106),
	"shield": Vector2(206, 106),
	"gloves": Vector2(60, 218),
	"boots": Vector2(168, 218),
}
const PORTRAIT_POSITION := Vector2(102, 106)
const CAPTION_OFFSET := Vector2(-14, 74)
const CAPTION_SIZE := Vector2(100, 22)
const ZONE_ACCEPTS := ["inventory", "equip"]
const RUN_ZONE_ACCEPTS := ["run_stowed", "run_worn"]

# Set in the scene that instances the bar: the pause menu's Backpack
# panel shows run_worn (finds draggable, brought-in gear greyed and
# fixed) and a Drop zone; the Inventory screen shows equipped gear and
# a Salvage zone.
@export var run_mode: bool = false
var cells: Dictionary = {}
var shown: bool = false
var _captions: Dictionary = {}
var _tween: Tween

@onready var title_label: Label = $Title
@onready var slots_area: Control = $Slots
@onready var portrait: TextureRect = $Slots/Portrait
@onready var salvage_zone: Panel = $SalvageZone
@onready var salvage_label: Label = $SalvageZone/Label
@onready var coins_label: Label = $CoinsLabel

func _ready() -> void:
	for slot in GameManager.ARMOR_SLOTS:
		var cell = ItemCellScene.instantiate()
		cell.custom_minimum_size = CELL_SIZE
		cell.size = CELL_SIZE
		cell.set_mode("run_worn" if run_mode else "equip", slot)
		slots_area.add_child(cell)
		cell.dropped.connect(_on_cell_dropped)
		cell.activated.connect(_on_cell_activated)
		if not run_mode:
			cell.secondary.connect(_on_cell_secondary)
		cells[slot] = cell
		var caption := Label.new()
		caption.text = GameManager.ARMOR_DEFS[slot]["display_name"]
		caption.size = CAPTION_SIZE
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 18)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slots_area.add_child(caption)
		_captions[slot] = caption
	slots_area.resized.connect(_layout_slots)
	_layout_slots()
	refresh()

# Centres the slot block in the space the bar has, so a taller window
# spreads the gear out instead of leaving dead panel below the coins.
func _layout_slots() -> void:
	var origin := Vector2(
		maxf((slots_area.size.x - BLOCK_SIZE.x) * 0.5, 0.0),
		maxf((slots_area.size.y - BLOCK_SIZE.y) * 0.5, 0.0))
	portrait.position = origin + PORTRAIT_POSITION
	for slot in cells.keys():
		cells[slot].position = origin + SLOT_POSITIONS[slot]
		_captions[slot].position = origin + SLOT_POSITIONS[slot] + CAPTION_OFFSET

func refresh() -> void:
	var source: Dictionary = GameManager.run_worn if run_mode else GameManager.equipped
	for slot in cells.keys():
		var worn = source.get(slot)
		var cell = cells[slot]
		cell.set_item(worn if worn is Dictionary else {})
		if run_mode and worn is Dictionary:
			# Brought-in gear is safe whatever happens and can't be moved
			# here, so it reads greyed; a find is the live thing.
			var found: bool = worn.get("found", false)
			cell.icon.modulate = Color.WHITE if found else Color(1.0, 1.0, 1.0, 0.5)
			cell.tooltip_text = GameManager.item_tooltip(worn) + ("\nFound this run" if found else "\nBrought in - safe whatever happens")
		else:
			cell.icon.modulate = Color.WHITE
	title_label.text = "Worn" if run_mode else "Equip"
	coins_label.text = "Coins: %d" % GameManager.coins
	salvage_label.text = "Drop\nleave a piece behind" if run_mode else "Salvage\ndrag a piece here for coins"

func _zone_sources() -> Array:
	return RUN_ZONE_ACCEPTS if run_mode else ZONE_ACCEPTS

func show_bar(instant: bool = false) -> void:
	shown = true
	_slide_to(SHOWN_X, instant)

func hide_bar(instant: bool = false) -> void:
	shown = false
	_slide_to(HIDDEN_X, instant)

func _slide_to(x: float, instant: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if instant:
		position.x = x
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:x", x, SLIDE_TIME)

func _on_cell_dropped(_cell, data: Dictionary) -> void:
	equip_requested.emit(data["item"])

func _on_cell_activated(cell) -> void:
	unequip_requested.emit(cell.slot_filter)

# Right-click a worn piece: the same salvage the bag cells offer and
# the same one dragging it to the zone does - InventoryScreen._salvage
# unequips an "equip" payload first. It always asks first, whatever the
# rarity (the `true`): a right-click is one click on the piece itself,
# with no gesture to abandon halfway, so without a prompt a mis-click
# destroys the gear outright. Dragging to the zone keeps the narrower
# Epic-and-above gate - the drag is already the deliberate part.
# Menu mode only: run mode's Drop is destructive and is deliberately
# left to the zone, where a drag has already refused brought-in gear
# (ItemCell.is_draggable()) that a right-click would not.
func _on_cell_secondary(cell) -> void:
	salvage_requested.emit(cell.drag_payload(), true)

# The Salvage / Drop zone: any drop over it from the bag or a slot (menu
# mode), or from a stowed cell or a worn find (run mode).
func zone_accepts(at_position: Vector2, data) -> bool:
	if not (data is Dictionary) or not (data.get("item") is Dictionary):
		return false
	return salvage_zone.get_rect().has_point(at_position) and _zone_sources().has(str(data.get("source", "")))

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return zone_accepts(at_position, data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if run_mode:
		drop_requested.emit(data)
	else:
		salvage_requested.emit(data, false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data = get_viewport().gui_get_drag_data()
		var lit: bool = data is Dictionary and _zone_sources().has(str(data.get("source", "")))
		salvage_zone.modulate = Color(0.6, 1.0, 0.7) if lit else Color.WHITE
	elif what == NOTIFICATION_DRAG_END:
		salvage_zone.modulate = Color.WHITE
