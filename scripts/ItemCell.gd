extends Panel

# One armour box: the piece's icon (WeaponIcon.configure_item()) inside
# a frame drawn in the rarity's colour, with the name and affix lines as
# its tooltip. Empty, it is the plain IconSlot frame.
#
# `mode` says what the box is in, which decides what can be dragged out
# of it and dropped onto it (Godot's built-in drag and drop):
#  - "inventory": a bag cell. Drag out; double-click to equip; right-click
#    to salvage (always asks first); takes a drop from an equip cell
#    (= unequip).
#  - "equip": an Equip bar slot (`slot_filter` names it). Takes only a
#    piece for that slot from the bag; drag out or double-click to
#    unequip; right-click to salvage (unequipped first, always asks).
#  - "haul": last run's haul on the Backpack tab. Look only until
#    Extract All.
#  - "static": the HUD rows, key items: no drag, no drop.
#  - "run_worn" / "run_stowed": the pause menu's Backpack panel (phase 6);
#    only run finds are draggable there.
# While a drag is in flight every cell hears about it: one that would
# take the payload draws a green frame, an equip slot that wouldn't dims,
# so where a piece can go is obvious the moment the drag starts.
# The cell only emits; whoever owns it (ItemGridPage, EquipBar) acts.

signal activated(cell)
signal secondary(cell)
signal dropped(cell, data: Dictionary)

const WeaponIconScript := preload("res://scripts/WeaponIcon.gd")
const FRAME_WIDTH := 3.0
const DRAG_PREVIEW_SIZE := 64.0
const ACCEPT_COLOR := Color(0.45, 1.0, 0.55)

var item: Dictionary = {}
var mode: String = "static"
var slot_filter: String = ""
# 1 = would take the drag in flight, -1 = an equip slot that wouldn't,
# 0 = not involved.
var drag_target: int = 0

@onready var icon: Control = $WeaponIcon

func _ready() -> void:
	_refresh()

func set_mode(new_mode: String, filter: String = "") -> void:
	mode = new_mode
	slot_filter = filter

# Cheap to call every frame: nothing happens unless the piece changed.
func set_item(new_item: Dictionary) -> void:
	if is_same(new_item, item) or (new_item.is_empty() and item.is_empty()):
		return
	item = new_item
	_refresh()

func _refresh() -> void:
	if icon == null:
		return
	if item.is_empty():
		icon.set_blank()
		tooltip_text = ""
	else:
		icon.configure_item(item)
		tooltip_text = GameManager.item_tooltip(item)
	queue_redraw()

func _draw() -> void:
	if drag_target > 0:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-FRAME_WIDTH / 2.0), ACCEPT_COLOR, false, FRAME_WIDTH)
		if item.is_empty():
			return
	if item.is_empty():
		return
	var color: Color = GameManager.RARITY_DEFS[clampi(int(item["rarity"]), 0, 3)]["color"]
	draw_rect(Rect2(Vector2.ZERO, size).grow(-FRAME_WIDTH / 2.0 - (FRAME_WIDTH if drag_target > 0 else 0.0)), color, false, FRAME_WIDTH)

# --- Drag source ---

func is_draggable() -> bool:
	if item.is_empty():
		return false
	match mode:
		"inventory", "equip", "run_stowed":
			return true
		"run_worn":
			return item.get("found", false)
	return false

func drag_payload() -> Dictionary:
	return {"item": item, "source": mode, "from_slot": slot_filter}

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_draggable():
		return null
	var preview := Control.new()
	var preview_icon := Control.new()
	preview_icon.set_script(WeaponIconScript)
	preview_icon.size = Vector2.ONE * DRAG_PREVIEW_SIZE
	preview_icon.position = -preview_icon.size / 2.0
	preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(preview_icon)
	preview_icon.configure_item(item)
	# Only a real drag can carry a preview (a direct call, as the
	# harness makes, would trip an engine check).
	if get_viewport().gui_is_dragging():
		set_drag_preview(preview)
	else:
		preview.free()
	return drag_payload()

# --- Drop target ---

func accepts(data) -> bool:
	if not (data is Dictionary) or not (data.get("item") is Dictionary) or not data["item"].has("id"):
		return false
	var source: String = str(data.get("source", ""))
	match mode:
		"equip":
			return data["item"]["id"] == slot_filter and source != "equip"
		"inventory":
			return source == "equip"
		"run_worn":
			return data["item"]["id"] == slot_filter and source == "run_stowed"
		"run_stowed":
			# A worn find can be stowed only while a backpack cell is free.
			return source == "run_worn" and GameManager.backpack.size() < GameManager.BACKPACK_SLOTS
	return false

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return accepts(data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped.emit(self, data)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data = get_viewport().gui_get_drag_data()
		if accepts(data):
			drag_target = 1
		elif mode == "equip" or mode == "run_worn":
			drag_target = -1
		else:
			drag_target = 0
		_apply_drag_look()
	elif what == NOTIFICATION_DRAG_END:
		drag_target = 0
		_apply_drag_look()

func _apply_drag_look() -> void:
	modulate = Color(1.0, 1.0, 1.0, 0.45) if drag_target < 0 else Color.WHITE
	queue_redraw()

# --- Clicks: the no-drag fallbacks ---

func _gui_input(event: InputEvent) -> void:
	if item.is_empty() or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		accept_event()
		activated.emit(self)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		secondary.emit(self)
