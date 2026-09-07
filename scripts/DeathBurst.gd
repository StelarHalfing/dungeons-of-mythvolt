extends CPUParticles2D

# One-shot spark burst spawned by Zombie.die() at the corpse. A single
# particles node per kill (the emitter settings live in DeathBurst.tscn)
# instead of 8 ColorRects + 8 Tweens; frees itself once every particle
# has faded. Uses local coordinates (the node never moves) - with global
# coordinates the emitter captured its transform before it was placed
# and every burst appeared at the world origin.

func _ready() -> void:
	finished.connect(queue_free)
	emitting = true
