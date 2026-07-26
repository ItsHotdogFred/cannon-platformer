extends Node
## Raycast + grapple hook lifecycle. Pure orchestrator: the player fires
## `try_attach()` on the interaction action and we own everything from there
## to release.

const GRAPPLING_HOOK = preload("uid://dum12y78crq6f")

@export var max_grapple_distance: float = 72.0

var body: CharacterBody2D
var ray_cast: RayCast2D
var active: Node2D = null
## Called BEFORE the hook reparents the player, so the player is frozen
## during the reparent. Implementations typically disable physics + collision.
var on_attach: Callable = Callable()
## Called when the hook self-clears (release, death, or forced cancel).
var on_release: Callable = Callable()


func bind(body: CharacterBody2D, ray_cast: RayCast2D) -> void:
	self.body = body
	self.ray_cast = ray_cast


## Aim the raycast at the cursor, capped to `max_grapple_distance` so
## out-of-range hits can't be grappled.
func aim() -> void:
	var mouse_pos := body.get_global_mouse_position()
	var aim_offset := ray_cast.to_local(mouse_pos)
	ray_cast.target_position = aim_offset.limit_length(max_grapple_distance)


## Attach if the raycast hit something in range and we're not already hooked.
## Disables player physics before reparenting so a `move_and_slide` can't
## fire mid-reparent.
func try_attach() -> bool:
	if active != null and is_instance_valid(active):
		return false
	if not ray_cast.is_colliding():
		return false
	## Range-check the hit point too, so a stale raycast result can never
	## create an attachment outside the configured range.
	var hook_position := ray_cast.get_collision_point()
	if body.global_position.distance_to(hook_position) > max_grapple_distance:
		return false

	var hook_target := ray_cast.get_collider() as Node2D
	on_attach.call()
	var hook := GRAPPLING_HOOK.instantiate()
	body.get_tree().current_scene.add_child(hook)
	active = hook
	hook.start_hook(hook_position, hook_target)
	return true


## Tear down an active grapple without starting a new one.
## reactivate_player: false during death so force_release doesn't re-enable physics.
func cancel(reactivate_player: bool = true) -> void:
	if active != null and is_instance_valid(active):
		_active_cancelling = not reactivate_player
		active.force_release(reactivate_player)
		_active_cancelling = false
	active = null


## Hook self-clears on detach. No-op if the caller is a stale instance.
## `on_release` is fired only for normal releases — forced cancels (death)
## already decided the player's active state inside force_release.
func clear(hook: Node2D = null) -> void:
	if hook == null or active == hook:
		active = null
		if not _active_cancelling:
			on_release.call()

var _active_cancelling: bool = false
