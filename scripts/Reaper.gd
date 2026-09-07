extends "res://scripts/Zombie.gd"

# The 15:01 finale, summoned by EnemySpawner._summon_reaper() once the
# field has been wiped: one enemy that runs the player down and ends the
# run. A placeholder end until there is more game to survive - move
# EnemySpawner.REAPER_TIME later when there is. Its scene (Reaper.tscn:
# the dark skeleton at 5x, tinted) gives it a billion HP (it can be hit
# and shows damage numbers, but never dies), contact damage that kills
# in one tick and speed no build outruns; here it just refuses the
# crowd control every other enemy takes.

func apply_knockback(_direction: Vector2, _distance: float) -> void:
	pass

func apply_slow(_duration: float = 0.25) -> void:
	pass
