extends Panel

# The pause menu's Backpack panel (design: docs/inventory-extraction-
# plan.md, decision 7): the same EquipBar and ItemGridPage the main
# menu's Inventory screen uses, in run mode. The bar shows what is worn
# right now (GameManager.run_worn - this run's finds draggable, the
# brought-in gear greyed and fixed) with a Drop zone; the page shows the
# three backpack cells. Drag a stowed piece onto its slot to wear it
# (the find it displaces takes the freed cell), drag a worn find into
# the cells to stow it (only while one is free), let go over Drop to
# leave a piece behind for good - that drag is the only way to leave one
# behind, a double-click wears or stows instead. Every change goes
# through GameManager's backpack ops and the panel re-reads afterwards,
# so it can never disagree with the HUD rows.

signal back_pressed

@onready var equip_bar: Panel = $EquipBar
@onready var stowed_page: Control = $StowedPage
@onready var back_button: Button = $BackButton

func _ready() -> void:
	visible = false
	stowed_page.accept_drops_from = ["run_worn"]
	stowed_page.can_accept = func(_data): return GameManager.backpack.size() < GameManager.BACKPACK_SLOTS
	stowed_page.drop_received.connect(_on_stow_drop)
	stowed_page.cell_activated.connect(func(cell): _wear(cell.item))
	equip_bar.equip_requested.connect(_wear)
	equip_bar.unequip_requested.connect(_stow)
	equip_bar.drop_requested.connect(_leave_behind)
	back_button.pressed.connect(func(): back_pressed.emit())

func open() -> void:
	visible = true
	refresh()

func close() -> void:
	visible = false

func refresh() -> void:
	equip_bar.refresh()
	stowed_page.populate("Stowed   %d / %d" % [GameManager.backpack.size(), GameManager.BACKPACK_SLOTS],
		GameManager.backpack, "run_stowed", "", GameManager.BACKPACK_SLOTS)

func _wear(item: Dictionary) -> void:
	var index: int = GameManager.backpack.find(item)
	if index >= 0 and GameManager.wear_from_backpack(index):
		refresh()

func _stow(slot: String) -> void:
	if GameManager.stow_worn(slot):
		refresh()

func _on_stow_drop(data: Dictionary) -> void:
	if str(data.get("source", "")) == "run_worn":
		_stow(str(data.get("from_slot", "")))

func _leave_behind(data: Dictionary) -> void:
	match str(data.get("source", "")):
		"run_stowed":
			var index: int = GameManager.backpack.find(data["item"])
			if index >= 0 and GameManager.drop_from_backpack(index):
				refresh()
		"run_worn":
			if GameManager.discard_worn(str(data.get("from_slot", ""))):
				refresh()
