extends Panel

# One box in the HUD's collection grid. Three looks:
#  - locked  (locked == true): the darker frame with the lock glyph - a
#              slot the run can't use yet (the permanent Weapon Slots /
#              Passive Slots upgrades open them).
#  - unowned (open, icon_id at level 0 or ""): the normal frame, empty -
#              a free slot, with something to collect if icon_id is set.
#  - owned   (level > 0): the normal frame with the item's icon.
#
# icon_id: the weapon/passive id this slot represents ("" for an open
# slot with nothing defined for it yet). is_weapon: which GameManager
# registry to check for "owned" - GameManager.weapons (WEAPON_DEFS) or
# GameManager.passives (PASSIVE_DEFS). Both store {"level": int}.
@export var icon_id: String = ""
@export var is_weapon: bool = true
@export var locked: bool = false

@onready var icon: Control = $WeaponIcon

func _ready() -> void:
	theme_type_variation = &"IconSlotLocked" if locked else &"IconSlot"
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if locked:
		icon.configure("", true)
		return
	if icon_id == "":
		icon.set_blank()
		return
	var registry: Dictionary = GameManager.weapons if is_weapon else GameManager.passives
	var owned: bool = registry.has(icon_id) and registry[icon_id]["level"] > 0
	if owned:
		icon.configure(icon_id, false)
	else:
		icon.set_blank()
