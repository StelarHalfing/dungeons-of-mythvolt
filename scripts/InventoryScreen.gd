extends Control

# The Inventory screen (design: docs/inventory-extraction-plan.md, "The
# Inventory screen"). Opened by the main menu's Inventory button: five
# tabs across the top - Inventory, Key Items, Ingredients, Potions,
# Backpack - each an ItemGridPage; the Inventory tab slides the Equip
# bar in from the left. Everything here is a relay between the pages,
# the bar and GameManager's data ops (equip / unequip / salvage /
# extract_all), which write the slot themselves; after any change the
# whole screen re-reads GameManager, so the pages and the bar can never
# disagree. Salvaging asks first through the main menu's confirm dialog
# (confirm_requested) whenever it was a right-click, and for an Epic or
# Legendary however it was asked for - see _salvage().

signal closed
signal confirm_requested(message: String, yes_text: String, on_confirm: Callable)

const TAB_INVENTORY := 0
const TAB_KEY_ITEMS := 1
const TAB_INGREDIENTS := 2
const TAB_POTIONS := 3
const TAB_BACKPACK := 4
# Where the pages start with the Equip bar in (Inventory tab) and out.
const PAGES_LEFT_WITH_BAR := 330.0
const PAGES_LEFT_WITHOUT_BAR := 20.0
const CONFIRM_FROM_RARITY := 2

var current_tab: int = TAB_INVENTORY
var tabs: Array = []
var pages: Array = []
var _button_group := ButtonGroup.new()

@onready var tabs_row: HBoxContainer = $Tabs
@onready var pages_root: Control = $Pages
@onready var equip_bar: Panel = $EquipBar
@onready var badge: Label = $Tabs/BackpackTab/Badge
@onready var back_button: Button = $BackButton
@onready var coins_label: Label = $CoinsLabel

func _ready() -> void:
	visible = false
	tabs = [$Tabs/InventoryTab, $Tabs/KeyItemsTab, $Tabs/IngredientsTab, $Tabs/PotionsTab, $Tabs/BackpackTab]
	pages = [$Pages/InventoryPage, $Pages/KeyItemsPage, $Pages/IngredientsPage, $Pages/PotionsPage, $Pages/BackpackPage]
	for i in range(tabs.size()):
		tabs[i].toggle_mode = true
		tabs[i].button_group = _button_group
		tabs[i].pressed.connect(_show_tab.bind(i))
	back_button.pressed.connect(close)
	var bag = pages[TAB_INVENTORY]
	bag.accept_drops_from = ["equip"]
	bag.drop_received.connect(_on_bag_drop)
	bag.cell_activated.connect(func(cell): _equip(cell.item))
	bag.cell_secondary.connect(func(cell): _salvage(cell.drag_payload(), true))
	pages[TAB_BACKPACK].action_pressed.connect(_extract_all)
	equip_bar.equip_requested.connect(_equip)
	equip_bar.unequip_requested.connect(_unequip)
	equip_bar.salvage_requested.connect(_salvage)
	equip_bar.hide_bar(true)

func open() -> void:
	visible = true
	_show_tab(TAB_INVENTORY)

func close() -> void:
	equip_bar.hide_bar(true)
	visible = false
	closed.emit()

func _show_tab(index: int) -> void:
	current_tab = index
	for i in range(pages.size()):
		pages[i].visible = i == index
	if not tabs[index].button_pressed:
		tabs[index].button_pressed = true
	var with_bar: bool = index == TAB_INVENTORY
	pages_root.offset_left = PAGES_LEFT_WITH_BAR if with_bar else PAGES_LEFT_WITHOUT_BAR
	if with_bar:
		equip_bar.show_bar()
	else:
		equip_bar.hide_bar()
	refresh()

# Re-reads everything from GameManager.
func refresh() -> void:
	coins_label.text = "Coins: %d" % GameManager.coins
	pages[TAB_INVENTORY].populate("Inventory", sorted_inventory(), "inventory",
		"No armour yet. Open chests in a run and survive to 15:00 to bring some back.")
	pages[TAB_KEY_ITEMS].populate("Key Items", [], "static",
		"Key items - totem keys, map unlocks - will be kept here.")
	pages[TAB_INGREDIENTS].populate("Ingredients", [], "static",
		"Ingredients dropped by enemies will be kept here, for re-rolling affixes later.")
	pages[TAB_POTIONS].populate("Potions", [], "static",
		"Potions to carry into a run will be kept here.")
	var haul_count: int = GameManager.haul.size()
	pages[TAB_BACKPACK].populate("From your last run - %d %s" % [haul_count, "item" if haul_count == 1 else "items"],
		GameManager.haul, "haul",
		"Nothing to extract. Survive to 15:00 with loot to bring some back.")
	pages[TAB_BACKPACK].set_action("Extract All", haul_count > 0)
	badge.text = str(haul_count)
	badge.visible = haul_count > 0
	equip_bar.refresh()

# Rarity first (best at the top), then slot order, so the grid reads
# as a list of what is worth wearing.
func sorted_inventory() -> Array:
	var items: Array = GameManager.inventory.duplicate()
	items.sort_custom(func(a, b):
		if a["rarity"] != b["rarity"]:
			return a["rarity"] > b["rarity"]
		return GameManager.ARMOR_SLOTS.find(a["id"]) < GameManager.ARMOR_SLOTS.find(b["id"]))
	return items

func _on_bag_drop(data: Dictionary) -> void:
	if str(data.get("source", "")) == "equip":
		_unequip(str(data.get("from_slot", "")))

func _equip(item: Dictionary) -> void:
	if GameManager.equip(item):
		refresh()

func _unequip(slot: String) -> void:
	if GameManager.unequip(slot):
		refresh()

# data is a drag payload: {"item", "source", "from_slot"}. A piece off a
# slot is unequipped first, then salvaged like any bag piece.
# Salvaging is destructive and there is no undo, so what decides whether
# it asks first is how easy the gesture was to trigger by accident, not
# only what the piece is worth. A drag to the Salvage zone is deliberate
# enough to go straight through below Epic; a right-click is a single
# click on the piece itself, so it always asks (always_confirm) - before
# that, one stray right-click destroyed a Common or Rare outright.
func _salvage(data: Dictionary, always_confirm: bool = false) -> void:
	var item: Dictionary = data["item"]
	var source: String = str(data.get("source", ""))
	var from_slot: String = str(data.get("from_slot", ""))
	var do_salvage := func():
		if source == "equip":
			GameManager.unequip(from_slot)
		GameManager.salvage(item)
		refresh()
	if always_confirm or int(item["rarity"]) >= CONFIRM_FROM_RARITY:
		var paid: int = GameManager.RARITY_DEFS[int(item["rarity"])]["salvage"]
		confirm_requested.emit("Salvage your %s %s for %d coins?" % [GameManager.rarity_name(item), GameManager.item_name(item), paid], "Salvage", do_salvage)
	else:
		do_salvage.call()

func _extract_all() -> void:
	var moved: int = GameManager.extract_all()
	refresh()
	if moved > 0:
		pages[TAB_BACKPACK].title_label.text = "Extracted %d %s into your Inventory" % [moved, "item" if moved == 1 else "items"]
