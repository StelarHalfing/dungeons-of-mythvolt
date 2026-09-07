extends CanvasLayer

@onready var hp_bar: TextureProgressBar = $HPBar
@onready var xp_bar: TextureProgressBar = $XPBar
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
# Under the choices: Reroll (label carries the cost - free while free
# ones remain, then 50 coins doubling; see GameManager.reroll_upgrades)
# and Ban (label carries the bans left this run; see ban_upgrade). Ban
# is a mode: press it, then click the choice to ban, or press it again
# to cancel - the title says which the panel is waiting for.
@onready var upgrade_title: Label = $UpgradePanel/VBoxContainer/TitleLabel
@onready var reroll_button: Button = $UpgradePanel/VBoxContainer/ActionRow/RerollButton
@onready var ban_button: Button = $UpgradePanel/VBoxContainer/ActionRow/BanButton
var ban_mode: bool = false
# Collection grid: GameManager.GRID_SLOTS_PER_ROW boxes per row. The
# top row's first get_weapon_slots() boxes are open and show the
# weapons owned this run in pickup order (empty box = a free slot), the
# rest are locked; the bottom row is the same for passives. Buying a
# Weapon/Passive Slots level opens one more box on the next run.
const IconSlotScene := preload("res://scenes/IconSlot.tscn")
@onready var weapon_grid: GridContainer = $WeaponGrid
var weapon_slots: Array = []
var passive_slots: Array = []
# Banner under the run clock announcing an unlock earned mid-run
# (GameManager.unlock_earned); fades out after TOAST_HOLD seconds.
@onready var unlock_toast: Label = $UnlockToast
const TOAST_HOLD := 3.0
const TOAST_FADE := 1.0
var toast_tween: Tween
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
	GameManager.unlock_earned.connect(_on_unlock_earned)
	_build_collection_grid()

	for i in range(upgrade_buttons.size()):
		upgrade_buttons[i].pressed.connect(_on_upgrade_pressed.bind(i))
	reroll_button.pressed.connect(_on_reroll_pressed)
	ban_button.pressed.connect(_on_ban_pressed)
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

	var fps_cap_button: Button = $GameSettingsPanel/VBoxContainer/FpsRow/FpsCapButton
	fps_cap_button.text = GameManager.fps_cap_label()
	fps_cap_button.pressed.connect(func():
		GameManager.cycle_fps_cap()
		fps_cap_button.text = GameManager.fps_cap_label()
	)

func _build_collection_grid() -> void:
	for slot in weapon_grid.get_children():
		weapon_grid.remove_child(slot)
		slot.queue_free()
	weapon_grid.columns = GameManager.GRID_SLOTS_PER_ROW
	weapon_slots = _add_slot_row(true, GameManager.get_weapon_slots())
	passive_slots = _add_slot_row(false, GameManager.get_passive_slots())
	_refresh_collection_grid()

# An unlock earned this run opens its slot right away: rebuild the grid
# so the lock disappears, and say why.
func _on_unlock_earned(id: String) -> void:
	_build_collection_grid()
	var def: Dictionary = GameManager.UNLOCK_DEFS[id]
	unlock_toast.text = "%s unlocked - %s" % [def["display_name"], def["description"].trim_suffix(".").to_lower()]
	unlock_toast.modulate.a = 1.0
	unlock_toast.visible = true
	if toast_tween != null:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(TOAST_HOLD)
	toast_tween.tween_property(unlock_toast, "modulate:a", 0.0, TOAST_FADE)
	toast_tween.tween_callback(func(): unlock_toast.visible = false)

# Returns the row's open (unlocked) slots, left to right.
func _add_slot_row(is_weapon: bool, open_slots: int) -> Array:
	var open: Array = []
	for i in range(GameManager.GRID_SLOTS_PER_ROW):
		var slot = IconSlotScene.instantiate()
		slot.locked = i >= open_slots
		slot.is_weapon = is_weapon
		weapon_grid.add_child(slot)
		if not slot.locked:
			open.append(slot)
	return open

# Open boxes show the run's pickups in order; boxes past the last
# pickup stay empty. Cheap enough to do every frame (a dozen slots).
func _refresh_collection_grid() -> void:
	for i in range(weapon_slots.size()):
		weapon_slots[i].icon_id = GameManager.weapon_order[i] if i < GameManager.weapon_order.size() else ""
	for i in range(passive_slots.size()):
		passive_slots[i].icon_id = GameManager.passive_order[i] if i < GameManager.passive_order.size() else ""

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_try_toggle_pause()
	_refresh_collection_grid()

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
	if choices.is_empty():
		# Nothing to pick (GameManager guards this, but never show a
		# panel with no buttons - there'd be no way to close it).
		upgrade_panel.visible = false
		return
	current_choices = choices
	for i in range(upgrade_buttons.size()):
		if i < choices.size():
			var info: Dictionary = GameManager.get_choice_text(choices[i])
			upgrade_labels[i].text = "%s\n%s" % [info["name"], info["desc"]]
			upgrade_icons[i].configure(choices[i], false)
			upgrade_buttons[i].visible = true
		else:
			upgrade_buttons[i].visible = false
	# A fresh set of choices (new level-up, reroll, or a ban's
	# replacement) always starts in normal pick mode.
	ban_mode = false
	_refresh_action_buttons()
	upgrade_panel.visible = true

func _refresh_action_buttons() -> void:
	var cost: int = GameManager.get_reroll_cost()
	var free_left: int = GameManager.get_free_rerolls_left()
	if cost > 0:
		reroll_button.text = "Reroll (%d coins)" % cost
	elif free_left > 1:
		reroll_button.text = "Reroll (%d free)" % free_left
	else:
		reroll_button.text = "Reroll (Free)"
	# Greyed out when unaffordable, when nothing new is left to show, or
	# while a ban is being chosen (a reroll would silently end ban mode).
	reroll_button.disabled = not GameManager.can_reroll() or ban_mode

	if ban_mode:
		ban_button.text = "Cancel ban"
		ban_button.disabled = false
		upgrade_title.text = "Choose an upgrade to ban:"
	else:
		ban_button.text = "Ban (%d left)" % GameManager.get_bans_left()
		ban_button.disabled = not GameManager.can_ban()
		upgrade_title.text = "Level Up! Choose an upgrade:"

func _on_upgrade_pressed(index: int) -> void:
	if ban_mode:
		# On success GameManager re-emits level_up_choices with the banned
		# slot refilled, which redraws the panel back in pick mode.
		GameManager.ban_upgrade(current_choices[index])
		return
	upgrade_panel.visible = false
	GameManager.choose_upgrade(current_choices[index])

func _on_reroll_pressed() -> void:
	# On success GameManager re-emits level_up_choices, which redraws the
	# panel (and this button's new cost) through _on_level_up_choices.
	GameManager.reroll_upgrades()

func _on_ban_pressed() -> void:
	ban_mode = not ban_mode
	_refresh_action_buttons()

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
