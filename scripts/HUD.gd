extends CanvasLayer

@onready var hp_bar: ProgressBar = $HPBar
@onready var xp_bar: ProgressBar = $XPBar
@onready var time_label: Label = $TimeLabel
@onready var level_label: Label = $LevelLabel
@onready var coins_label: Label = $CoinsLabel
@onready var upgrade_panel: Panel = $UpgradePanel
@onready var upgrade_buttons: Array = [
	$UpgradePanel/VBoxContainer/ScrollContainer/ButtonList/Button1,
	$UpgradePanel/VBoxContainer/ScrollContainer/ButtonList/Button2,
	$UpgradePanel/VBoxContainer/ScrollContainer/ButtonList/Button3,
]
@onready var upgrade_labels: Array = [
	$UpgradePanel/VBoxContainer/ScrollContainer/ButtonList/Button1/HBoxContainer/Label,
	$UpgradePanel/VBoxContainer/ScrollContainer/ButtonList/Button2/HBoxContainer/Label,
	$UpgradePanel/VBoxContainer/ScrollContainer/ButtonList/Button3/HBoxContainer/Label,
]
@onready var upgrade_icons: Array = [
	$UpgradePanel/VBoxContainer/ScrollContainer/ButtonList/Button1/HBoxContainer/Icon,
	$UpgradePanel/VBoxContainer/ScrollContainer/ButtonList/Button2/HBoxContainer/Icon,
	$UpgradePanel/VBoxContainer/ScrollContainer/ButtonList/Button3/HBoxContainer/Icon,
]
@onready var game_over_panel: Panel = $GameOverPanel
@onready var pause_panel: Panel = $PausePanel
@onready var game_settings_panel: Panel = $GameSettingsPanel

var current_choices: Array = []

func _ready() -> void:
	# Stay responsive while the tree is paused for a level-up choice.
	process_mode = Node.PROCESS_MODE_ALWAYS
	upgrade_panel.visible = false
	game_over_panel.visible = false
	pause_panel.visible = false
	game_settings_panel.visible = false

	GameManager.xp_changed.connect(_on_xp_changed)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.level_up_choices.connect(_on_level_up_choices)
	GameManager.player_died.connect(_on_player_died)

	for i in range(upgrade_buttons.size()):
		upgrade_buttons[i].pressed.connect(_on_upgrade_pressed.bind(i))
	$GameOverPanel/VBoxContainer/RestartButton.pressed.connect(_on_restart_pressed)
	$GameOverPanel/VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)
	$PausePanel/VBoxContainer/ResumeButton.pressed.connect(_resume)
	$PausePanel/VBoxContainer/SettingsButton.pressed.connect(_on_pause_settings_pressed)
	$PausePanel/VBoxContainer/QuitGameButton.pressed.connect(_on_quit_game_pressed)
	$GameSettingsPanel/VBoxContainer/BackButton.pressed.connect(_on_pause_settings_back_pressed)

	var volume_slider: HSlider = $GameSettingsPanel/VBoxContainer/VolumeSlider
	var bus_idx := AudioServer.get_bus_index("Master")
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
	volume_slider.value_changed.connect(_on_game_volume_changed)

	var damage_numbers_check: CheckButton = $GameSettingsPanel/VBoxContainer/DamageNumbersCheck
	damage_numbers_check.button_pressed = GameManager.show_damage_numbers
	damage_numbers_check.toggled.connect(_on_damage_numbers_toggled)

	var fullscreen_check: CheckButton = $GameSettingsPanel/VBoxContainer/FullscreenCheck
	fullscreen_check.button_pressed = GameManager.is_fullscreen
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_try_toggle_pause()

	time_label.text = GameManager.format_time()
	coins_label.text = "Coins: %d" % GameManager.coins
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player = players[0]
		hp_bar.max_value = player.max_hp
		hp_bar.value = player.hp

func _on_xp_changed(current: int, needed: int) -> void:
	xp_bar.max_value = needed
	xp_bar.value = current

func _on_level_changed(new_level: int) -> void:
	level_label.text = "Lv %d" % new_level

func _on_level_up_choices(choices: Array) -> void:
	current_choices = choices
	for i in range(upgrade_buttons.size()):
		if i < choices.size():
			var info: Dictionary = GameManager.get_weapon_choice_text(choices[i])
			upgrade_labels[i].text = "%s\n%s" % [info["name"], info["desc"]]
			upgrade_icons[i].configure(choices[i], false)
			upgrade_buttons[i].visible = true
		else:
			upgrade_buttons[i].visible = false
	upgrade_panel.visible = true

func _on_upgrade_pressed(index: int) -> void:
	upgrade_panel.visible = false
	GameManager.choose_upgrade(current_choices[index])

func _on_player_died() -> void:
	pause_panel.visible = false
	game_settings_panel.visible = false
	game_over_panel.visible = true
	$GameOverPanel/VBoxContainer/SurvivedLabel.text = "You survived " + GameManager.format_time()
	$GameOverPanel/VBoxContainer/DefeatedLabel.text = "Enemies defeated: %d" % GameManager.enemies_defeated

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_quit_game_pressed() -> void:
	GameManager.end_run()

func _try_toggle_pause() -> void:
	if game_settings_panel.visible:
		_on_pause_settings_back_pressed()
	elif pause_panel.visible:
		_resume()
	elif not upgrade_panel.visible and not game_over_panel.visible:
		_pause()

func _pause() -> void:
	pause_panel.visible = true
	GameManager.is_menu_paused = true
	get_tree().paused = true

func _resume() -> void:
	pause_panel.visible = false
	game_settings_panel.visible = false
	GameManager.is_menu_paused = false
	get_tree().paused = false

func _on_pause_settings_pressed() -> void:
	pause_panel.visible = false
	game_settings_panel.visible = true

func _on_pause_settings_back_pressed() -> void:
	game_settings_panel.visible = false
	pause_panel.visible = true

func _on_game_volume_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(max(value, 0.0001)))

func _on_damage_numbers_toggled(enabled: bool) -> void:
	GameManager.set_show_damage_numbers(enabled)

func _on_fullscreen_toggled(enabled: bool) -> void:
	GameManager.set_fullscreen(enabled)
