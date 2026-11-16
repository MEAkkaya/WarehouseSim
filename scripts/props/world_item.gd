class_name WorldItem
extends RigidBody3D
## ONE physical product lying in the world: on a shelf, on the floor, in a pile.
## Aim at it and it lights up; click to take THAT item (into the open box in your
## hands if it fits, otherwise your hotbar).
##
## On a shelf an item is "frozen" (it stays put and costs almost nothing). The
## moment it is dropped, knocked off by an earthquake, blown by a fan... it is
## unfrozen and becomes a normal falling, bouncing physics body.

## The shelf this item lies on (null for loose items).
var shelf: Shelf = null
var item: ItemData = null

## The collider of an item is at least this thick in every direction, in metres.
const MIN_THICKNESS := 0.05
## An item that falls below this height (it got out of the world) is put back.
const KILL_HEIGHT := -5.0

static var _highlight_material: StandardMaterial3D = null
static var _size_cache: Dictionary = {}  # item id -> collision size


## Gives the item its model, collider and weight. Call before adding to the tree.
func setup(p_item: ItemData, p_shelf: Shelf = null, frozen_in_place: bool = true) -> void:
	item = p_item
	shelf = p_shelf
	mass = maxf(0.05, item.weight)
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = frozen_in_place
	gravity_scale = GameState.gravity_scale
	# Thrown items are fast and small: without continuous collision detection a bar thrown
	# at 15 m/s moves more than a wall is thick in one physics step and slips through it.
	continuous_cd = not frozen_in_place
	var visual := item.create_visual()  # origin at the bottom centre
	add_child(visual)
	var size := _collision_size(item)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# (A flat bar is only 3 cm thick: the collider is never thinner than MIN_THICKNESS.)
	box.size = Vector3(maxf(size.x, MIN_THICKNESS), maxf(size.y, MIN_THICKNESS), maxf(size.z, MIN_THICKNESS))
	size = box.size
	shape.shape = box
	shape.position = Vector3(0.0, size.y / 2.0, 0.0)
	add_child(shape)
	add_to_group("world_items")


## The item's footprint: the placeholder size, or the measured size of its model.
static func _collision_size(p_item: ItemData) -> Vector3:
	if not _size_cache.has(p_item.id):
		var visual := p_item.create_visual()
		var bounds := p_item.measure_visual(visual)
		visual.free()
		_size_cache[p_item.id] = bounds.size if bounds.size.length() > 0.001 else p_item.placeholder_size
	return _size_cache[p_item.id]


## Creates a loose item (a free physics body) and drops it into `parent`.
static func spawn_loose(p_item: ItemData, parent: Node, at: Vector3, velocity: Vector3 = Vector3.ZERO) -> WorldItem:
	var world_item := WorldItem.new()
	world_item.setup(p_item, null, false)
	world_item.position = at  # parents are at the world origin or the interior at 0,0,0
	parent.add_child(world_item)
	world_item.global_position = at
	world_item.linear_velocity = velocity
	return world_item


## Makes the item a free physics body (it falls from where it is).
func release() -> void:
	if shelf != null:
		shelf.item_removed(self)
		shelf = null
	freeze = false
	continuous_cd = true
	sleeping = false
	set_physics_process(true)


func _ready() -> void:
	_last_safe = global_position
	set_physics_process(not freeze)  # frozen shelf items need no per-frame check


## Safety net: an item that somehow ends up far below the ground is dropped back at the
## last place it was safely above it (never lost for good).
func _physics_process(_delta: float) -> void:
	if global_position.y > KILL_HEIGHT:
		if is_on_floor_estimate():
			_last_safe = global_position
		return
	global_position = _last_safe
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false


var _last_safe: Vector3 = Vector3.ZERO


func is_on_floor_estimate() -> bool:
	return linear_velocity.length() < 0.5 and global_position.y > 0.0


# ---- Interaction -------------------------------------------------------------------

func can_interact(who: Node) -> bool:
	var player := who as Player
	var box := player.carried
	if box != null and box.is_open and box.has_room(item.size):
		return true
	return player.inventory.has_room()


func get_prompt(who: Node) -> String:
	var player := who as Player
	var box := player.carried
	if box != null and box.is_open and box.has_room(item.size):
		return "Pack %s into the box (%d spaces, %.1f kg)" % [item.display_name, item.size, item.weight]
	return "Take %s (%.1f kg)" % [item.display_name, item.weight]


func interact(who: Node) -> void:
	var player := who as Player
	var box := player.carried
	if box != null and box.is_open and box.has_room(item.size):
		box.add_item(item)
	elif player.inventory.has_room():
		player.inventory.add(InventoryEntry.make_item(item, null))
	else:
		return
	if shelf != null:
		shelf.item_removed(self)
	queue_free()


## Lights the item up while the player looks at it.
func set_highlighted(on: bool) -> void:
	if _highlight_material == null:
		_highlight_material = StandardMaterial3D.new()
		_highlight_material.albedo_color = Color(1, 1, 1, 0.35)
		_highlight_material.emission_enabled = true
		_highlight_material.emission = Color(1, 0.95, 0.6)
		_highlight_material.emission_energy_multiplier = 1.4
		_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for node in find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = _highlight_material if on else null
