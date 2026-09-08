extends CanvasLayer

@onready var hp_bar: TextureProgressBar = $HPBar
@onready var xp_bar: TextureProgressBar = $XPBar
@onready var time_label: Label = $TimeLabel
@onready var level_label: Label = $LevelLabel
@onready var coins_label: Label = $CoinsLabel
# Countdown shown beside the coin counter while a Gold Dream is running.
@onready var gold_dream_label: Label = $GoldDreamLabel
# Top centre, under the clock, while a boss (the "bosses" group - see
# AncientKeeper.gd) is alive: its name and current / max HP.
@onready var boss_bar: ProgressBar = $BossBar
@onready var boss_label: Label = $BossLabel
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
# Armour rows under the passives (ItemCell.tscn: icon in a rarity frame,
# affix lines as tooltip): the five worn pieces (GameManager.run_worn),
# then the three stowed in the run backpack; blank spacers pad both
# rows out to the grid's six columns.
const ItemCellScene := preload("res://scenes/ItemCell.tscn")
var worn_cells: Dictionary = {}
var backpack_cells: Array = []
# The chest-opening reveal (ChestReveal.gd), played off
# GameManager.chest_opened while the run is paused for it.
@onready var chest_reveal: Control = $ChestReveal
# Top right: the kill count, and under it whether this run's finds are
# still at risk ("Secure loot at 15:00") or banked ("Loot secured").
@onready var kills_label: Label = $KillsLabel
@onready var secure_label: Label = $SecureLabel
# The pause menu's Backpack panel (RunBackpackPanel.gd): opened by the
# Backpack button beside Settings, Back (or Escape) returns to the
# pause panel.
@onready var run_backpack_panel: Panel = $RunBackpackPanel
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
	GameManager.chest_opened.connect(chest_reveal.play)
	GameManager.haul_secured.connect(_on_haul_secured)
	_build_collection_grid()

	for i in range(upgrade_buttons.size()):
		upgrade_buttons[i].pressed.connect(_on_upgrade_pressed.bind(i))
	reroll_button.pressed.connect(_on_reroll_pressed)
	ban_button.pressed.connect(_on_ban_pressed)
	$GameOverPanel/VBoxContainer/RestartButton.pressed.connect(_on_restart_pressed)
	$GameOverPanel/VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)
	$PausePanel/VBoxContainer/ResumeButton.pressed.connect(_resume)
	$PausePanel/VBoxContainer/SettingsButton.pressed.connect(_on_pause_settings_pressed)
	$PausePanel/VBoxContainer/BackpackButton.pressed.connect(_on_pause_backpack_pressed)
	$PausePanel/VBoxContainer/QuitGameButton.pressed.connect(_on_quit_game_pressed)
	run_backpack_panel.back_pressed.connect(_on_backpack_back_pressed)
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
	_add_armor_rows()
	_refresh_collection_grid()

func _add_armor_rows() -> void:
	worn_cells.clear()
	backpack_cells.clear()
	for i in range(GameManager.GRID_SLOTS_PER_ROW):
		if i < GameManager.ARMOR_SLOTS.size():
			var cell = ItemCellScene.instantiate()
			weapon_grid.add_child(cell)
			worn_cells[GameManager.ARMOR_SLOTS[i]] = cell
		else:
			weapon_grid.add_child(_grid_spacer())
	for i in range(GameManager.GRID_SLOTS_PER_ROW):
		if i < GameManager.BACKPACK_SLOTS:
			var cell = ItemCellScene.instantiate()
			weapon_grid.add_child(cell)
			backpack_cells.append(cell)
		else:
			weapon_grid.add_child(_grid_spacer())

func _grid_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(48, 48)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

# An unlock earned this run opens its slot right away: rebuild the grid
# so the lock disappears, and say why.
func _on_unlock_earned(id: String) -> void:
	_build_collection_grid()
	var def: Dictionary = GameManager.UNLOCK_DEFS[id]
	_show_toast("%s unlocked - %s" % [def["display_name"], def["description"].trim_suffix(".").to_lower()])

func _on_haul_secured(count: int) -> void:
	if count == 0:
		_show_toast("15:00 - you made it!")
	elif count == 1:
		_show_toast("Secured 1 item - extract it from the Backpack in the main menu")
	else:
		_show_toast("Secured %d items - extract them from the Backpack in the main menu" % count)

# The banner under the clock: shows `text`, holds, then fades.
# Toasts queue rather than overwrite: at 15:00 the fifth passive slot
# unlocks and the haul is secured in the same tick, and both deserve
# their TOAST_HOLD.
var toast_queue: Array = []

func _show_toast(text: String) -> void:
	if unlock_toast.visible and toast_tween != null and toast_tween.is_valid():
		toast_queue.append(text)
		return
	_display_toast(text)

func _display_toast(text: String) -> void:
	unlock_toast.text = text
	unlock_toast.modulate.a = 1.0
	unlock_toast.visible = true
	if toast_tween != null:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(TOAST_HOLD)
	toast_tween.tween_property(unlock_toast, "modulate:a", 0.0, TOAST_FADE)
	toast_tween.tween_callback(_on_toast_done)

func _on_toast_done() -> void:
	unlock_toast.visible = false
	if not toast_queue.is_empty():
		_display_toast(toast_queue.pop_front())

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
	for slot in worn_cells.keys():
		var worn = GameManager.run_worn.get(slot)
		worn_cells[slot].set_item(worn if worn is Dictionary else {})
	for i in range(backpack_cells.size()):
		backpack_cells[i].set_item(GameManager.backpack[i] if i < GameManager.backpack.size() else {})

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_try_toggle_pause()
	_refresh_collection_grid()

	time_label.text = GameManager.format_time()
	coins_label.text = "Coins: %d" % GameManager.coins
	kills_label.text = "Kills: %d" % GameManager.enemies_defeated
	secure_label.text = "Loot secured" if GameManager.run_secured else "Secure loot at 15:00"
	gold_dream_label.visible = GameManager.is_gold_dream_active()
	if gold_dream_label.visible:
		gold_dream_label.text = "Gold Dream %.1fs" % GameManager.gold_dream_timer
	var player: Node2D = GameManager.player
	if player != null:
		hp_bar.max_value = player.max_hp
		hp_bar.value = player.hp

	var boss: Node = get_tree().get_first_node_in_group("bosses")
	var boss_alive: bool = boss != null and not boss.is_dead
	boss_bar.visible = boss_alive
	boss_label.visible = boss_alive
	if boss_alive:
		boss_bar.max_value = boss.max_hp
		boss_bar.value = maxf(boss.hp, 0.0)
		boss_label.text = "%s  %d / %d" % [boss.boss_name, ceili(maxf(boss.hp, 0.0)), int(boss.max_hp)]

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
		if GameManager.is_fallback_panel():
			upgrade_title.text = "Level Up! Pick a bonus:"
		else:
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
	# Past 15:00 the run is a win whatever ends it (the Reaper, usually):
	# the same panel, titled Victory, with the finds it banked; before
	# it, the finds the death cost.
	var won: bool = GameManager.run_secured
	$GameOverPanel/VBoxContainer/GameOverLabel.text = "Victory!" if won else "You Died"
	$GameOverPanel/VBoxContainer/SurvivedLabel.text = "You survived " + GameManager.format_time()
	$GameOverPanel/VBoxContainer/DefeatedLabel.text = "Enemies defeated: %d" % GameManager.enemies_defeated
	if won:
		$GameOverPanel/VBoxContainer/ItemsLabel.text = "Items secured: %d" % GameManager.secured_count
	else:
		$GameOverPanel/VBoxContainer/ItemsLabel.text = "Items lost: %d" % GameManager.lost_count

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_quit_game_pressed() -> void:
	GameManager.end_run()

func _try_toggle_pause() -> void:
	if run_backpack_panel.visible:
		_on_backpack_back_pressed()
	elif game_settings_panel.visible:
		_on_pause_settings_back_pressed()
	elif pause_panel.visible:
		_resume()
	elif not upgrade_panel.visible and not game_over_panel.visible and not chest_reveal.visible:
		_pause()

func _pause() -> void:
	pause_panel.visible = true
	GameManager.is_menu_paused = true
	get_tree().paused = true

func _resume() -> void:
	pause_panel.visible = false
	game_settings_panel.visible = false
	run_backpack_panel.close()
	GameManager.is_menu_paused = false
	get_tree().paused = false

func _on_pause_backpack_pressed() -> void:
	pause_panel.visible = false
	run_backpack_panel.open()

func _on_backpack_back_pressed() -> void:
	run_backpack_panel.close()
	pause_panel.visible = true

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
