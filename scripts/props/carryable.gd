class_name Carryable
extends Interactable
## Anything the player can pick up in one hand and put down again (boxes, bills).
## The player holds ONE thing at a time. Subclasses add their own behaviour.

## Extra offset from the hold point while carried (x right, y up, z back), e.g.
## to push a big box further away so it doesn't fill the screen.
@export var hold_offset: Vector3 = Vector3.ZERO

# Where it lives in the world, restored when it is put down.
var _home_parent: Node = null
var _saved_collision_layer: int = 1


func can_interact(who: Node) -> bool:
	return (who as Player).hands_empty()


func interact(who: Node) -> void:
	(who as Player).pick_up(self)
	super(who)


## Attach to the player's hold point and switch collision off so it can't block
## the interact ray or push the player around. `home` is where it returns to.
func on_picked_up(hold_point: Node3D, home: Node = null) -> void:
	_home_parent = home if home != null else get_parent()
	_saved_collision_layer = collision_layer
	collision_layer = 0
	reparent(hold_point, false)
	transform = Transform3D(Basis.IDENTITY, hold_offset)
	reset_physics_interpolation()


## Return to the world at `world_transform` and re-enable collision.
func on_dropped(world_transform: Transform3D) -> void:
	reparent(_home_parent, false)
	global_transform = world_transform
	# Teleport: don't let physics interpolation slide it over from the hold point.
	reset_physics_interpolation()
	collision_layer = _saved_collision_layer
