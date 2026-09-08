# Screen-edge wrapping, shared by XP gems (XPGem.gd) and enemies
# (Zombie.gd, and so TankZombie/Skeleton/Slime/Reaper). Something the
# player has left fully off one edge of the screen, with the player
# still walking away from it along that axis, comes back on at the
# opposite edge - off the left, back on at the right; off the top, back
# on at the bottom - keeping its place along the other axis, so the
# field reads as scrolling round rather than a thing jumping across the
# player. Each axis is handled on its own, so diagonal walking wraps
# whichever edges it actually fell off. Something that was off-screen
# along the other axis too (an enemy killed off-screen by a tornado
# dropping its gem there, say) is pulled in to the nearest edge there,
# so every wrap lands it in view. Nothing happens to what the player is
# walking toward, or while they stand still.
#
# `margin` is how far past the edge it must be before it wraps (at
# least half its sprite, so it's fully hidden, with enough slack that a
# wiggling player doesn't ping-pong it); `inset` is how far inside the
# far edge it reappears.

# The camera's view in world coordinates: the viewport's rect mapped
# back through the canvas transform, so the zoom, the real window
# aspect (stretch aspect "expand") and any camera shake all count.
static func visible_world_rect(item: CanvasItem) -> Rect2:
	var to_world: Transform2D = item.get_canvas_transform().affine_inverse()
	var viewport: Rect2 = item.get_viewport_rect()
	var top_left: Vector2 = to_world * viewport.position
	var bottom_right: Vector2 = to_world * viewport.end
	return Rect2(top_left, bottom_right - top_left)

# Moves `item` if it has fallen off the screen behind the walking
# `player` (a CharacterBody2D - its `velocity` is the walking
# direction); true when it did.
static func wrap_across_screen(item: Node2D, player: Node2D, margin: float, inset: float) -> bool:
	var vel: Vector2 = player.velocity
	if vel == Vector2.ZERO:
		return false
	var view: Rect2 = visible_world_rect(item)
	var pos: Vector2 = item.global_position
	var wrapped := false
	if vel.x > 0.0 and pos.x < view.position.x - margin:
		pos.x = view.end.x - inset
		wrapped = true
	elif vel.x < 0.0 and pos.x > view.end.x + margin:
		pos.x = view.position.x + inset
		wrapped = true
	if vel.y > 0.0 and pos.y < view.position.y - margin:
		pos.y = view.end.y - inset
		wrapped = true
	elif vel.y < 0.0 and pos.y > view.end.y + margin:
		pos.y = view.position.y + inset
		wrapped = true
	if not wrapped:
		return false
	var pad: Vector2 = Vector2.ONE * inset
	item.global_position = pos.clamp(view.position + pad, view.end - pad)
	return true
