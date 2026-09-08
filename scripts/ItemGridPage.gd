extends Control

# One tab's page on the Inventory screen: a title line, an optional
# action button (the Backpack tab's Extract All), a scrolling grid of
# ItemCells built from a list, and an empty-state line when the list is
# empty. The page is also a drop target: dropping a piece dragged out
# of an Equip bar slot anywhere on the bag page unequips it (the cells
# forward drops too, so an occupied spot works the same as empty
# space). Only relays: the InventoryScreen decides what a drop, a
# double-click or a right-click means.

signal action_pressed
signal cell_activated(cell)
signal cell_secondary(cell)
signal drop_received(data: Dictionary)

const ItemCellScene := preload("res://scenes/ItemCell.tscn")
const CELL_SIZE := Vector2(72, 72)
# Widest the grid is allowed to get. Past this an ultrawide window would
# string every piece out on one line instead of reading as a block.
const MAX_COLUMNS := 16

# Drag sources whose drops land on this page ("equip" for the bag).
var accept_drops_from: Array = []
# Optional extra gate on page-level drops, e.g. the run backpack's
# "only while a cell is free"; given the payload, returns whether the
# drop is possible.
var can_accept: Callable = Callable()
var cell_mode: String = "static"
var cells: Array = []

@onready var title_label: Label = $VBox/TitleLabel
@onready var action_button: Button = $VBox/ActionButton
@onready var scroll: ScrollContainer = $VBox/Scroll
@onready var grid: GridContainer = $VBox/Scroll/Grid
@onready var empty_label: Label = $VBox/EmptyLabel

func _ready() -> void:
	action_button.visible = false
	action_button.pressed.connect(func(): action_pressed.emit())
	scroll.resized.connect(_update_columns)
	_update_columns()

# As many cells as fit across (up to MAX_COLUMNS), so a wide window
# fills its rows instead of leaving the grid stuck at ten columns with
# the rest of the page empty, and a narrow one drops a column rather
# than scrolling sideways. The vertical scrollbar's width is always
# reserved, so the count can't flicker as the bar appears and goes.
func _update_columns() -> void:
	var h_sep: float = float(grid.get_theme_constant("h_separation"))
	var bar_width: float = scroll.get_v_scroll_bar().get_combined_minimum_size().x
	var available: float = scroll.size.x - bar_width
	var columns: int = int(floor((available + h_sep) / (CELL_SIZE.x + h_sep)))
	grid.columns = clampi(columns, 1, MAX_COLUMNS)

# min_cells pads the grid with empty cells in the same mode (the run
# backpack always shows its three cells, so an empty one is a drop
# target); with padding the empty-state line never shows.
func populate(title: String, items: Array, mode: String, empty_text: String, min_cells: int = 0) -> void:
	title_label.text = title
	cell_mode = mode
	for cell in cells:
		grid.remove_child(cell)
		cell.queue_free()
	cells.clear()
	for item in items:
		_add_cell(mode, item)
	while cells.size() < min_cells:
		_add_cell(mode, {})
	empty_label.text = empty_text
	empty_label.visible = cells.is_empty()
	scroll.visible = not cells.is_empty()

func _add_cell(mode: String, item: Dictionary) -> void:
	var cell = ItemCellScene.instantiate()
	cell.custom_minimum_size = CELL_SIZE
	cell.set_mode(mode)
	grid.add_child(cell)
	cell.set_item(item)
	cell.activated.connect(func(c): cell_activated.emit(c))
	cell.secondary.connect(func(c): cell_secondary.emit(c))
	cell.dropped.connect(func(_c, data): drop_received.emit(data))
	cells.append(cell)

func set_action(text: String, shown: bool) -> void:
	action_button.text = text
	action_button.visible = shown

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or not (data.get("item") is Dictionary) or not data["item"].has("id"):
		return false
	if not accept_drops_from.has(str(data.get("source", ""))):
		return false
	return not can_accept.is_valid() or can_accept.call(data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	drop_received.emit(data)
