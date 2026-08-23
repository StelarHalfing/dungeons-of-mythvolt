extends Panel

# icon_id: the weapon/passive id this slot represents, or "" for a
# not-yet-implemented future slot (always shown locked).
# is_weapon: which GameManager registry to check for "acquired".
# Passives don't exist yet, so is_weapon=false slots are always
# locked for now - this is intentional, not a bug.
@export var icon_id: String = ""
@export var is_weapon: bool = true

@onready var icon: Control = $WeaponIcon

func _ready() -> void:
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	var acquired: bool = false
	if icon_id != "" and is_weapon:
		var weapons: Dictionary = GameManager.weapons
		acquired = weapons.has(icon_id) and weapons[icon_id]["level"] > 0
	icon.configure(icon_id, not acquired)
