extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var settings_panel: Panel = $SettingsPanel
@onready var upgrades_panel: Panel = $UpgradesPanel
@onready var volume_slider: HSlider = $SettingsPanel/VBoxContainer/VolumeSlider
@onready var damage_numbers_check: CheckButton = $SettingsPanel/VBoxContainer/DamageNumbersCheck
@onready var fullscreen_check: CheckButton = $SettingsPanel/VBoxContainer/FullscreenCheck

@onready var coins_label: Label = $UpgradesPanel/VBoxContainer/CoinsLabel

# Save-slot picker: the "Saves" button along the bottom opens a
# panel with one button per GameManager slot (the active one marked with
# the same check icon the select screens use) and a Delete button under
# each, which asks for confirmation before wiping the slot.
const CHECK_ICON: Texture2D = preload("res://assets/ui/icon_check.tres")
@onready var save_slot_button: Button = $SaveSlotButton
@onready var save_panel: Panel = $SavePanel
@onready var confirm_panel: Panel = $ConfirmPanel
@onready var slot_buttons: Array = [
	$SavePanel/VBoxContainer/SlotRow/Slot1Col/Slot1,
	$SavePanel/VBoxContainer/SlotRow/Slot2Col/Slot2,
	$SavePanel/VBoxContainer/SlotRow/Slot3Col/Slot3,
]
@onready var delete_buttons: Array = [
	$SavePanel/VBoxContainer/SlotRow/Slot1Col/Delete1,
	$SavePanel/VBoxContainer/SlotRow/Slot2Col/Delete2,
	$SavePanel/VBoxContainer/SlotRow/Slot3Col/Delete3,
]
# Slot awaiting the delete confirmation (0 = none).
var pending_delete_slot: int = 0

# Maps upgrade id -> {info_label, buy_button}. Add a row here (plus
# matching nodes in the .tscn) to add a new permanent upgrade without
# duplicating the refresh/purchase logic below.
@onready var upgrade_rows: Dictionary = {
	"health_regen": {
		"info": $UpgradesPanel/VBoxContainer/ScrollContainer/UpgradeList/HealthRegenInfoLabel,
		"button": $UpgradesPanel/VBoxContainer/ScrollContainer/UpgradeList/HealthRegenBuyButton,
	},
	"damage": {
		"info": $UpgradesPanel/VBoxContainer/ScrollContainer/UpgradeList/DamageInfoLabel,
		"button": $UpgradesPanel/VBoxContainer/ScrollContainer/UpgradeList/DamageBuyButton,
	},
	"xp_gain": {
		"info": $UpgradesPanel/VBoxContainer/ScrollContainer/UpgradeList/XpGainInfoLabel,
		"button": $UpgradesPanel/VBoxContainer/ScrollContainer/UpgradeList/XpGainBuyButton,
	},
}

func _ready() -> void:
	settings_panel.visible = false
	upgrades_panel.visible = false

	$MainButtons/PlayButton.pressed.connect(_on_play_pressed)
	$MainButtons/SettingsButton.pressed.connect(_on_settings_pressed)
	$MainButtons/UpgradesButton.pressed.connect(_on_upgrades_pressed)
	$QuitButton.pressed.connect(_on_quit_pressed)
	$SettingsPanel/VBoxContainer/BackButton.pressed.connect(_on_settings_back_pressed)
	$UpgradesPanel/VBoxContainer/BackButton.pressed.connect(_on_upgrades_back_pressed)

	for id in upgrade_rows.keys():
		upgrade_rows[id]["button"].pressed.connect(_on_upgrade_buy_pressed.bind(id))

	save_panel.visible = false
	confirm_panel.visible = false
	save_slot_button.pressed.connect(_on_save_pressed)
	$SavePanel/VBoxContainer/BackButton.pressed.connect(_on_save_back_pressed)
	for i in range(slot_buttons.size()):
		slot_buttons[i].pressed.connect(_on_slot_pressed.bind(i + 1))
		delete_buttons[i].pressed.connect(_on_delete_pressed.bind(i + 1))
	$ConfirmPanel/VBoxContainer/ButtonRow/ConfirmButton.pressed.connect(_on_confirm_delete)
	$ConfirmPanel/VBoxContainer/ButtonRow/CancelButton.pressed.connect(_on_cancel_delete)
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
	if shown:
		_refresh_slots()

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
	confirm_panel.visible = false
	save_panel.visible = false
	_set_menu_visible(true)

func _on_slot_pressed(slot: int) -> void:
	GameManager.select_slot(slot)
	_refresh_slots()

func _on_delete_pressed(slot: int) -> void:
	pending_delete_slot = slot
	confirm_panel.visible = true

func _on_confirm_delete() -> void:
	if pending_delete_slot > 0:
		GameManager.delete_slot(pending_delete_slot)
	pending_delete_slot = 0
	confirm_panel.visible = false
	_refresh_slots()

func _on_cancel_delete() -> void:
	pending_delete_slot = 0
	confirm_panel.visible = false

func _refresh_slots() -> void:
	for i in range(slot_buttons.size()):
		var slot: int = i + 1
		var summary: Dictionary = GameManager.slot_summary(slot)
		var button: Button = slot_buttons[i]
		var detail: String = "%d coins" % summary["coins"] if summary["exists"] else "Empty"
		button.text = "Slot %d\n%s" % [slot, detail]
		button.icon = CHECK_ICON if slot == GameManager.active_slot else null
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

func _refresh_upgrades() -> void:
	coins_label.text = "Coins: %d" % GameManager.coins
	for id in upgrade_rows.keys():
		_refresh_upgrade_row(id)

func _refresh_upgrade_row(id: String) -> void:
	var info_label: Label = upgrade_rows[id]["info"]
	var buy_button: Button = upgrade_rows[id]["button"]

	var def: Dictionary = GameManager.PERMANENT_UPGRADE_DEFS[id]
	var level: int = GameManager.get_upgrade_level(id)
	var max_level: int = def["max_level"]
	var per_level: float = def["per_level_value"]
	var current_bonus: String = _format_bonus(id, level * per_level)

	if level >= max_level:
		info_label.text = "%s - Lv %d/%d (MAX)\n+%s now" % [def["display_name"], level, max_level, current_bonus]
		buy_button.text = "Maxed"
		buy_button.disabled = true
	else:
		var cost: int = GameManager.get_upgrade_cost(id)
		var next_bonus: String = _format_bonus(id, per_level)
		info_label.text = "%s - Lv %d/%d\n+%s now (next level: +%s)" % [def["display_name"], level, max_level, current_bonus, next_bonus]
		buy_button.text = "Buy Lv %d (%d coins)" % [level + 1, cost]
		buy_button.disabled = GameManager.coins < cost

# Health Regeneration is a flat HP/sec value; Damage and XP Gain are
# percentages.
func _format_bonus(id: String, value: float) -> String:
	if id == "damage" or id == "xp_gain":
		return "%d%%" % int(round(value * 100.0))
	return "%.1f HP/sec" % value

func _on_upgrade_buy_pressed(id: String) -> void:
	if GameManager.purchase_upgrade(id):
		_refresh_upgrades()
