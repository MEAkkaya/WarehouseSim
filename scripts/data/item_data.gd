class_name ItemData
extends Resource
## Definition of one kind of product (not a physical item in the world).
##
## GDScript concept: a Resource is a data object that can be saved as a `.tres`
## file and edited in the Inspector, like a ScriptableObject in Unity. To add a
## new product: FileSystem dock -> right-click data/items -> New Resource ->
## ItemData, then fill in the fields. No code needed.

## Stable identifier used by orders and save data (never shown to the player).
@export var id: StringName = &""
## Name shown on shelves, the HUD and orders.
@export var display_name: String = "Item"
## Base value in dollars (used later for wages, black market, fence prices).
@export var price: int = 1
## How many packing spaces the item takes in a box: 1 = mini (toothbrush), 2-3 =
## medium, 4 = large (toilet paper). A medium box has 8 spaces.
@export_range(1, 4) var size: int = 2
## Weight in kg. The total weight of the box you carry slows you down.
@export var weight: float = 0.5
## Can be eaten (E key) for energy. Eating at work in view of a supervisor can be a
## rule violation.
@export var edible: bool = false
@export var energy_restore: float = 0.0
## Optional real model (one model = one item). It is centred and stood on its feet
## automatically, so the model's own origin does not matter.
## Leave empty to use the placeholder cuboid below.
@export var model: PackedScene
## Scales the model to real-world metres. Models are often drawn at another scale in
## Blender: a model 1.15 long that should be a 15 cm bar needs 0.13 here.
@export var model_scale: float = 1.0

@export_group("Placeholder (used when no model is set)")
@export var placeholder_size: Vector3 = Vector3(0.25, 0.25, 0.25)
@export var placeholder_color: Color = Color(0.8, 0.8, 0.8)


## Like create_visual(), but shrunk (never enlarged) and turned 90 degrees if that
## helps, so its footprint fits a `cell` of (width, depth) metres. Used for
## packing items into box slots, whatever their size or model.
func create_packed_visual(cell: Vector2) -> Node3D:
	var visual := create_visual()
	var bounds := _measure(visual, Transform3D.IDENTITY)
	var wrapper := Node3D.new()
	if bounds.size.x <= 0.0001 or bounds.size.z <= 0.0001:
		wrapper.add_child(visual)
		return wrapper
	# Centre the footprint on the wrapper's origin, feet on y = 0.
	visual.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	wrapper.add_child(visual)
	var scale_upright := minf(cell.x / bounds.size.x, cell.y / bounds.size.z)
	var scale_turned := minf(cell.x / bounds.size.z, cell.y / bounds.size.x)
	var chosen := scale_upright
	if scale_turned > scale_upright:
		chosen = scale_turned
		wrapper.rotation.y = PI * 0.5
	wrapper.scale = Vector3.ONE * minf(chosen, 1.0)
	return wrapper


## Bounding box of all meshes under `node`, in the root's local space.
## (`xf` is the transform accumulated from the root down to `node`.)
func _measure(node: Node3D, xf: Transform3D) -> AABB:
	var result := AABB()
	var has_any := false
	var node_xf := xf * node.transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result = node_xf * (node as MeshInstance3D).get_aabb()
		has_any = true
	for child in node.get_children():
		if child is Node3D:
			var child_box := _measure(child, node_xf)
			if child_box.size != Vector3.ZERO:
				result = child_box if not has_any else result.merge(child_box)
				has_any = true
	return result


var _placeholder_mesh: BoxMesh = null


## Builds a visual for this item with its origin at the bottom centre, so it
## sits on a shelf board or inside a box when placed at a slot position.
## Callers own the returned node (add it to the tree, free it when done).
func create_visual() -> Node3D:
	if model != null:
		return _create_model_visual()
	# All placeholder copies of an item share one mesh and one material (a shelf
	# holds thousands of items, so this matters).
	if _placeholder_mesh == null:
		_placeholder_mesh = BoxMesh.new()
		_placeholder_mesh.size = placeholder_size
		var material := StandardMaterial3D.new()
		material.albedo_color = placeholder_color
		_placeholder_mesh.material = material
	var root := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _placeholder_mesh
	mesh_instance.position.y = placeholder_size.y * 0.5
	root.add_child(mesh_instance)
	return root


## The size of a visual made by create_visual() (public wrapper for _measure).
func measure_visual(visual: Node3D) -> AABB:
	return _measure(visual, Transform3D.IDENTITY)


# The model's bounding box before scaling, measured once per item.
var _model_bounds: AABB = AABB()
var _model_bounds_known: bool = false


## The model, scaled by `model_scale`, with its feet at y = 0 and its middle at x = z = 0.
func _create_model_visual() -> Node3D:
	var instance := model.instantiate() as Node3D
	if not _model_bounds_known:
		_model_bounds = _measure(instance, Transform3D.IDENTITY)
		_model_bounds_known = true
	var root := Node3D.new()
	instance.scale = Vector3.ONE * model_scale
	instance.position = -Vector3(_model_bounds.get_center().x, _model_bounds.position.y,
			_model_bounds.get_center().z) * model_scale
	root.add_child(instance)
	return root
