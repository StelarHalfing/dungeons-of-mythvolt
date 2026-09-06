extends Panel

# icon_id: the weapon/passive id this slot represents, or "" for a
# not-yet-implemented future slot (always shown locked).
# is_weapon: which GameManager registry to check for "acquired" -
# GameManager.weapons (WEAPON_DEFS) or GameManager.passives
# (PASSIVE_DEFS). Both store {"level": int}; level 0 = locked.
@export var icon_id: String = ""
@export var is_weapon: bool = true

@onready var icon: Control = $WeaponIcon

func _ready() -> void:
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	var acquired: bool = false
	if icon_id != "":
		var registry: Dictionary = GameManager.weapons if is_weapon else GameManager.passives
		acquired = registry.has(icon_id) and registry[icon_id]["level"] > 0
	icon.configure(icon_id, not acquired)
