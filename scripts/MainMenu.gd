extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var settings_panel: Panel = $SettingsPanel
@onready var upgrades_panel: Panel = $UpgradesPanel
@onready var volume_slider: HSlider = $SettingsPanel/VBoxContainer/VolumeSlider
@onready var damage_numbers_check: CheckButton = $SettingsPanel/VBoxContainer/DamageNumbersCheck
@onready var fullscreen_check: CheckButton = $SettingsPanel/VBoxContainer/FullscreenCheck

@onready var coins_label: Label = $UpgradesPanel/VBoxContainer/CoinsLabel

# Save-slot picker: the "Saves" button along the bottom opens a panel
# with one column per GameManager slot (built in _build_slot_columns()
# from SLOT_COUNT, so the menu can't disagree with the save code about
# how many slots exist): a slot button marked with the same check icon
# the select screens use when it is the active one, and a Delete button
# under it. Delete opens ConfirmOverlay, a full-screen input blocker
# with the confirmation dialog in the middle, so nothing behind it can
# be clicked until the player answers.
const CHECK_ICON: Texture2D = preload("res://assets/ui/icon_check.tres")
const SLOT_BUTTON_SIZE := Vector2(220, 92)
const DELETE_BUTTON_SIZE := Vector2(220, 54)
@onready var save_slot_button: Button = $SaveSlotButton
@onready var save_panel: Panel = $SavePanel
@onready var slot_row: HBoxContainer = $SavePanel/VBoxContainer/SlotRow
@onready var confirm_overlay: Control = $ConfirmOverlay
@onready var confirm_message: Label = $ConfirmOverlay/ConfirmPanel/VBoxContainer/MessageLabel
@onready var cancel_button: Button = $ConfirmOverlay/ConfirmPanel/VBoxContainer/ButtonRow/CancelButton
# Index i is slot i + 1.
var slot_buttons: Array[Button] = []
var slot_checks: Array[TextureRect] = []
var delete_buttons: Array[Button] = []
# Slot awaiting the delete confirmation (0 = none).
var pending_delete_slot: int = 0

# Unlocks panel (the "Unlocks" button in the bottom-right corner): one
# row per GameManager.UNLOCK_DEFS entry, built in _build_unlock_rows(),
# showing the condition, the reward and whether the active save has
# earned it - the same check icon as elsewhere when it has, the grid's
# lock glyph when it hasn't.
const WeaponIconScript := preload("res://scripts/WeaponIcon.gd")
const UNLOCK_ICON_SIZE := Vector2(40, 40)
@onready var unlocks_button: Button = $UnlocksButton
@onready var unlocks_panel: Panel = $UnlocksPanel
@onready var unlock_list: VBoxContainer = $UnlocksPanel/VBoxContainer/ScrollContainer/UnlockList
# Unlock id -> {"check": TextureRect, "lock": Control, "status": Label}
var unlock_rows: Dictionary = {}

# Upgrade id -> {"info": Label, "button": Button}, one row per
# GameManager.PERMANENT_UPGRADE_DEFS entry, built in _build_upgrade_rows()
# in table order - a new permanent upgrade is a table entry only.
@onready var upgrade_list: VBoxContainer = $UpgradesPanel/VBoxContainer/ScrollContainer/UpgradeList
@onready var upgrade_scroll: ScrollContainer = $UpgradesPanel/VBoxContainer/ScrollContainer
var upgrade_rows: Dictionary = {}
# Wheel travel not yet turned into a row step (precision touchpads send
# many small-factor wheel events per flick; they add up to whole rows).
var _shop_wheel_accum: float = 0.0

func _ready() -> void:
	settings_panel.visible = false
	upgrades_panel.visible = false

	$MainButtons/PlayButton.pressed.connect(_on_play_pressed)
	$MainButtons/SettingsButton.pressed.connect(_on_settings_pressed)
	$MainButtons/UpgradesButton.pressed.connect(_on_upgrades_pressed)
	$QuitButton.pressed.connect(_on_quit_pressed)
	$SettingsPanel/VBoxContainer/BackButton.pressed.connect(_on_settings_back_pressed)
	$UpgradesPanel/VBoxContainer/BackButton.pressed.connect(_on_upgrades_back_pressed)
	_build_upgrade_rows()
	# The bar is a child of the container and handles the wheel itself
	# first, so it gets the same row-snapping handler.
	upgrade_scroll.gui_input.connect(_on_upgrade_scroll_input)
	upgrade_scroll.get_v_scroll_bar().gui_input.connect(_on_upgrade_scroll_input)

	unlocks_panel.visible = false
	unlocks_button.pressed.connect(_on_unlocks_pressed)
	$UnlocksPanel/VBoxContainer/BackButton.pressed.connect(_on_unlocks_back_pressed)
	_build_unlock_rows()

	save_panel.visible = false
	confirm_overlay.visible = false
	save_slot_button.pressed.connect(_on_save_pressed)
	$SavePanel/VBoxContainer/BackButton.pressed.connect(_on_save_back_pressed)
	$ConfirmOverlay/ConfirmPanel/VBoxContainer/ButtonRow/ConfirmButton.pressed.connect(_on_confirm_delete)
	cancel_button.pressed.connect(_on_cancel_delete)
	_build_slot_columns()
	_refresh_slots()

	var bus_idx := AudioServer.get_bus_index("Master")
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	volume_slider.value_changed.connect(_on_volume_changed)

	damage_numbers_check.button_pressed = GameManager.show_damage_numbers
	damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)

	fullscreen_check.button_pressed = GameManager.is_fullscreen
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	var fps_cap_button: Button = $SettingsPanel/VBoxContainer/FpsRow/FpsCapButton
	fps_cap_button.text = GameManager.fps_cap_label()
	fps_cap_button.pressed.connect(func():
		GameManager.cycle_fps_cap()
		fps_cap_button.text = GameManager.fps_cap_label()
	)

func _on_play_pressed() -> void:
	# Character select -> map select -> the game (see RunSetup.gd).
	get_tree().change_scene_to_file("res://scenes/RunSetup.tscn")

# The title and slot picker hide with the main buttons while a panel is
# open, so the (taller) Upgrades panel never overlaps them on a 16:9
# window.
func _set_menu_visible(shown: bool) -> void:
	main_buttons.visible = shown
	$TitleLabel.visible = shown
	save_slot_button.visible = shown
	unlocks_button.visible = shown
	if shown:
		_refresh_slots()

func _on_unlocks_pressed() -> void:
	_set_menu_visible(false)
	unlocks_panel.visible = true
	_refresh_unlocks()

func _on_unlocks_back_pressed() -> void:
	unlocks_panel.visible = false
	_set_menu_visible(true)

func _build_unlock_rows() -> void:
	for id in GameManager.UNLOCK_DEFS.keys():
		var def: Dictionary = GameManager.UNLOCK_DEFS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		unlock_list.add_child(row)

		# Status picture: the check icon once earned, the lock glyph until
		# then (both the same size, so the text never shifts).
		var check := TextureRect.new()
		check.texture = CHECK_ICON
		check.custom_minimum_size = UNLOCK_ICON_SIZE
		check.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(check)
		var lock := Control.new()
		lock.set_script(WeaponIconScript)
		lock.custom_minimum_size = UNLOCK_ICON_SIZE
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lock)
		# Full-strength glyph: the dimmed one all but vanishes on the panel.
		lock.configure("", false)

		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var name_label := Label.new()
		name_label.text = def["display_name"]
		name_label.add_theme_font_size_override("font_size", 32)
		text.add_child(name_label)
		var desc_label := Label.new()
		desc_label.text = "%s Reward: %s." % [def["description"], GameManager.unlock_reward_text(id)]
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(desc_label)

		var status := Label.new()
		status.custom_minimum_size = Vector2(110, 0)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(status)
		unlock_rows[id] = {"check": check, "lock": lock, "status": status}

func _refresh_unlocks() -> void:
	for id in unlock_rows.keys():
		var earned: bool = GameManager.unlocks.get(id, false)
		unlock_rows[id]["check"].visible = earned
		unlock_rows[id]["lock"].visible = not earned
		unlock_rows[id]["status"].text = "Unlocked" if earned else "Locked"
		unlock_rows[id]["status"].modulate = Color(1, 1, 1, 1) if earned else Color(1, 1, 1, 0.6)

func _on_settings_pressed() -> void:
	_set_menu_visible(false)
	settings_panel.visible = true

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	_set_menu_visible(true)

func _on_upgrades_pressed() -> void:
	_set_menu_visible(false)
	upgrades_panel.visible = true
	_refresh_upgrades()

func _on_upgrades_back_pressed() -> void:
	upgrades_panel.visible = false
	_set_menu_visible(true)

func _on_save_pressed() -> void:
	_set_menu_visible(false)
	save_panel.visible = true
	_refresh_slots()

func _on_save_back_pressed() -> void:
	_close_confirm()
	save_panel.visible = false
	_set_menu_visible(true)

# One column per slot: the slot button (with a check-mark overlay in its
# bottom-right corner, shown while it is the active slot) and a Delete
# button under it.
func _build_slot_columns() -> void:
	for i in range(GameManager.SLOT_COUNT):
		var slot: int = i + 1
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		slot_row.add_child(column)

		var slot_button := Button.new()
		slot_button.custom_minimum_size = SLOT_BUTTON_SIZE
		slot_button.pressed.connect(_on_slot_pressed.bind(slot))
		column.add_child(slot_button)
		slot_buttons.append(slot_button)

		var check := TextureRect.new()
		check.texture = CHECK_ICON
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		check.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		check.offset_left = -46.0
		check.offset_top = -46.0
		check.offset_right = -6.0
		check.offset_bottom = -6.0
		slot_button.add_child(check)
		slot_checks.append(check)

		var delete_button := Button.new()
		delete_button.custom_minimum_size = DELETE_BUTTON_SIZE
		delete_button.text = "Delete Save"
		delete_button.pressed.connect(_on_delete_pressed.bind(slot))
		column.add_child(delete_button)
		delete_buttons.append(delete_button)

func _on_slot_pressed(slot: int) -> void:
	GameManager.select_slot(slot)
	_refresh_slots()

func _on_delete_pressed(slot: int) -> void:
	pending_delete_slot = slot
	confirm_message.text = "Resetting Slot %d will delete all of its data. Are you sure?" % slot
	confirm_overlay.visible = true
	# Keyboard/gamepad focus starts on the safe answer, and the two
	# dialog buttons' focus neighbours point only at each other (see the
	# .tscn), so focus can't wander to the buttons under the overlay.
	cancel_button.grab_focus()

func _on_confirm_delete() -> void:
	if pending_delete_slot > 0:
		GameManager.delete_slot(pending_delete_slot)
	_close_confirm()
	_refresh_slots()

func _on_cancel_delete() -> void:
	_close_confirm()

func _close_confirm() -> void:
	pending_delete_slot = 0
	confirm_overlay.visible = false

func _refresh_slots() -> void:
	for i in range(slot_buttons.size()):
		var slot: int = i + 1
		var summary: Dictionary = GameManager.slot_summary(slot)
		var lines: PackedStringArray = ["Slot %d" % slot]
		if summary["exists"]:
			lines.append("%d coins" % summary["coins"])
			lines.append("Upgrades: %d" % summary["upgrade_levels"])
		else:
			lines.append("Empty")
		slot_buttons[i].text = "\n".join(lines)
		slot_checks[i].visible = slot == GameManager.active_slot
		# Nothing to delete in an empty slot.
		delete_buttons[i].disabled = not summary["exists"]

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_volume_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(max(value, 0.0001)))

func _on_damage_numbers_toggled(enabled: bool) -> void:
	GameManager.set_show_damage_numbers(enabled)

func _on_fullscreen_toggled(enabled: bool) -> void:
	GameManager.set_fullscreen(enabled)

func _build_upgrade_rows() -> void:
	for id in GameManager.PERMANENT_UPGRADE_DEFS.keys():
		var info := Label.new()
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		upgrade_list.add_child(info)
		# Height comes from the theme's button style (68px with the
		# 16px font), the same as every other themed button.
		var buy := Button.new()
		buy.pressed.connect(_on_upgrade_buy_pressed.bind(id))
		upgrade_list.add_child(buy)
		upgrade_rows[id] = {"info": info, "button": buy}

# The shop shows three rows at a time and the mouse wheel moves one whole
# row per notch - snapping to the next row's top (rows can differ in
# height when a label wraps) instead of ScrollContainer's default eighth
# of a page. Handled on the gui_input signal, which fires before the
# control's own handling, so accept_event() replaces it. A notch is a
# wheel event with factor 1; touchpads send fractions, which accumulate.
func _on_upgrade_scroll_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_shop_wheel_accum += event.factor
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_shop_wheel_accum -= event.factor
	else:
		return
	upgrade_scroll.accept_event()
	while absf(_shop_wheel_accum) >= 1.0:
		var direction: float = signf(_shop_wheel_accum)
		_shop_wheel_accum -= direction
		_scroll_shop_by_row(direction > 0.0)

func _scroll_shop_by_row(down: bool) -> void:
	var current: int = upgrade_scroll.scroll_vertical
	var target: int = -1
	for id in upgrade_rows.keys():
		var top: int = int(upgrade_rows[id]["info"].position.y)
		if down and top > current:
			target = top
			break
		if not down and top < current:
			target = top
	if target >= 0:
		upgrade_scroll.scroll_vertical = target

func _refresh_upgrades() -> void:
	coins_label.text = "Coins: %d" % GameManager.coins
	for id in upgrade_rows.keys():
		_refresh_upgrade_row(id)

# Row text comes from the upgrade's def (stat_label/format) through the
# same GameManager.format_bonus() the level-up cards use, e.g.
# "+10% damage now (next level: +10%)" / "+0.2 HP/sec now (next level: +0.2)".
func _refresh_upgrade_row(id: String) -> void:
	var info_label: Label = upgrade_rows[id]["info"]
	var buy_button: Button = upgrade_rows[id]["button"]

	var def: Dictionary = GameManager.PERMANENT_UPGRADE_DEFS[id]
	var level: int = GameManager.get_upgrade_level(id)
	var max_level: int = def["max_level"]
	var current_bonus: String = GameManager.format_bonus(def, GameManager.get_permanent_bonus(id))
	var stat_label: String = def["stat_label"]

	if level >= max_level:
		info_label.text = "%s - Lv %d/%d (MAX)\n%s %s now" % [def["display_name"], level, max_level, current_bonus, stat_label]
		buy_button.text = "Maxed"
		buy_button.disabled = true
	else:
		var cost: int = GameManager.get_upgrade_cost(id)
		var next_bonus: String = GameManager.format_bonus(def, def["per_level_value"])
		info_label.text = "%s - Lv %d/%d\n%s %s now (next level: %s)" % [def["display_name"], level, max_level, current_bonus, stat_label, next_bonus]
		buy_button.text = "Buy Lv %d (%d coins)" % [level + 1, cost]
		buy_button.disabled = GameManager.coins < cost

func _on_upgrade_buy_pressed(id: String) -> void:
	if GameManager.purchase_upgrade(id):
		_refresh_upgrades()
