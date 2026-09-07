extends Panel

# One box in the HUD's collection grid. Three looks:
#  - locked   (icon_id == ""): the darker frame with the lock glyph - a
#               slot with nothing behind it yet (future content).
#  - unowned  (a real id at level 0): the normal frame, empty - you can
#               see there's something to collect here.
#  - owned    (level > 0): the normal frame with the item's icon.
#
# icon_id: the weapon/passive id this slot represents, or "" for a
# locked slot. is_weapon: which GameManager registry to check for
# "owned" - GameManager.weapons (WEAPON_DEFS) or GameManager.passives
# (PASSIVE_DEFS). Both store {"level": int}; level 0 = not yet owned.
@export var icon_id: String = ""
@export var is_weapon: bool = true

@onready var icon: Control = $WeaponIcon

func _ready() -> void:
	theme_type_variation = &"IconSlot" if icon_id != "" else &"IconSlotLocked"
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if icon_id == "":
		icon.configure("", true)
		return
	var registry: Dictionary = GameManager.weapons if is_weapon else GameManager.passives
	var owned: bool = registry.has(icon_id) and registry[icon_id]["level"] > 0
	if owned:
		icon.configure(icon_id, false)
	else:
		icon.set_blank()
