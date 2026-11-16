class_name Interactor
extends RayCast3D
## Lives under a player's camera and looks at whatever the player is aiming at.
## One instance per player, so there is no global "current target" - local co-op
## later just means a second Player scene with its own Interactor.
##
## It extends RayCast3D directly: set `target_position` in the inspector for the
## reach distance (default 2.5 m straight ahead along -Z).
##
## A target is ANY physics body that has the three interaction methods
## (can_interact, get_prompt, interact) - an Interactable (StaticBody3D) or a
## WorldItem (RigidBody3D). If it also has `set_highlighted(bool)`, it is lit up
## while you can interact with it.

## Fired when the aimed-at thing changes (null = looking at nothing).
signal focus_changed(target: Node3D)
## Fired when the text to show changes. Empty string = hide the prompt.
signal prompt_changed(text: String)

## Who is doing the interacting (set by the Player in its _ready). Passed to
## targets so they know which player acted.
var user: Node = null
var focused: Node3D = null
var _highlighted: Node3D = null
var _last_prompt: String = ""


func _physics_process(_delta: float) -> void:
	# RayCast3D updates itself every physics frame; we just read the result.
	var target: Node3D = null
	if is_colliding():
		var collider := get_collider() as Node3D
		# Walls and the floor have no get_prompt method, so they are never targets.
		if collider != null and collider.has_method("get_prompt"):
			target = collider

	if target != focused:
		focused = target
		focus_changed.emit(focused)

	# Light up the focused thing, but only while it can actually be used.
	var wanted: Node3D = null
	if is_instance_valid(focused) and focused.can_interact(user):
		wanted = focused
	if wanted != _highlighted:
		if is_instance_valid(_highlighted) and _highlighted.has_method("set_highlighted"):
			_highlighted.set_highlighted(false)
		_highlighted = wanted
		if _highlighted != null and _highlighted.has_method("set_highlighted"):
			_highlighted.set_highlighted(true)

	_update_prompt()


## Called by the Player when the interact key is pressed. Carrying state lives
## on the player, so targets receive `user` to read/modify it.
func try_interact() -> void:
	if is_instance_valid(focused) and focused.can_interact(user):
		focused.interact(user)


func _update_prompt() -> void:
	var text := ""
	if is_instance_valid(focused) and focused.can_interact(user):
		text = focused.get_prompt(user)
	# Only emit on change so the HUD isn't spammed every physics tick.
	if text != _last_prompt:
		_last_prompt = text
		prompt_changed.emit(text)
