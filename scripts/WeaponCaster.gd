extends Node2D

# Base for the weapon caster nodes under Player (SwordCaster,
# FireballCaster, GrenadeCaster, TornadoCaster, MjolnirCaster): the
# cooldown gate every one of them used to spell out by hand. Each frame,
# while the run isn't paused for a level-up and the weapon has been
# picked (level > 0), the timer counts down; when it runs out _cast()
# fires and, if it reports success, the timer reloads with _cooldown()
# stretched by the run's attack-speed bonus (GameManager.get_cooldown_
# mult()). A subclass sets weapon_id in _init(), implements _cast(), and
# overrides _cooldown() only if its rate isn't the weapon's "speed" stat
# in casts per second (Fireball and Mjolnir fire on a fixed interval).
# The Forcefield (ForcefieldWeapon.gd) is an Area2D that ticks damage
# to whatever overlaps it rather than casting, so it keeps its own loop.

# Key into GameManager.weapons / WEAPON_DEFS.
var weapon_id: String = ""
var cast_timer: float = 0.0

func _process(delta: float) -> void:
	if GameManager.is_paused_for_upgrade:
		return
	var stats: Dictionary = GameManager.weapons[weapon_id]
	if stats["level"] <= 0:
		return

	cast_timer -= delta
	if cast_timer <= 0.0 and _cast(stats):
		cast_timer = _cooldown(stats) * GameManager.get_cooldown_mult()

# Fires the weapon. Return false to leave the cooldown ready and try
# again next frame (the Sword waits for something to come within reach).
func _cast(_stats: Dictionary) -> bool:
	return true

# Seconds between casts before the attack-speed bonus: by default the
# weapon's "speed" stat is casts per second.
func _cooldown(stats: Dictionary) -> float:
	return 1.0 / maxf(stats["speed"], 0.01)
