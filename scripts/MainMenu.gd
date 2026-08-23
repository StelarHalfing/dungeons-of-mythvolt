extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var settings_panel: Panel = $SettingsPanel
@onready var upgrades_panel: Panel = $UpgradesPanel
@onready var volume_slider: HSlider = $SettingsPanel/VBoxContainer/VolumeSlider
@onready var damage_numbers_check: CheckButton = $SettingsPanel/VBoxContainer/DamageNumbersCheck
@onready var fullscreen_check: CheckButton = $SettingsPanel/VBoxContainer/FullscreenCheck

@onready var coins_label: Label = $UpgradesPanel/VBoxContainer/CoinsLabel

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

	var bus_idx := AudioServer.get_bus_index("Master")
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	volume_slider.value_changed.connect(_on_volume_changed)

	damage_numbers_check.button_pressed = GameManager.show_damage_numbers
	damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)

	fullscreen_check.button_pressed = GameManager.is_fullscreen
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_settings_pressed() -> void:
	main_buttons.visible = false
	settings_panel.visible = true

func _on_settings_back_pressed() -> void:
	settings_panel.visible = false
	main_buttons.visible = true

func _on_upgrades_pressed() -> void:
	main_buttons.visible = false
	upgrades_panel.visible = true
	_refresh_upgrades()

func _on_upgrades_back_pressed() -> void:
	upgrades_panel.visible = false
	main_buttons.visible = true

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

# Health Regeneration is a flat HP/sec value; Damage is a percentage.
func _format_bonus(id: String, value: float) -> String:
	if id == "damage":
		return "%d%%" % int(round(value * 100.0))
	return "%.1f HP/sec" % value

func _on_upgrade_buy_pressed(id: String) -> void:
	if GameManager.purchase_upgrade(id):
		_refresh_upgrades()
