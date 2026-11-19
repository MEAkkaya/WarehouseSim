class_name HillForest
extends Node3D
## The trees on the hills and mountain slopes of the Landscape: far too many to place by hand,
## so they are planted by a seeded scatter (the same forest every run) and drawn as MultiMesh
## chunks with TWO levels of detail:
##   - close up (within `near_range`): your pine model, tree2.glb,
##   - further away: a plain 6-sided cone of the same size and colour (12 triangles instead of
##     about 480), visible out to `far_range`.
## The two overlap a little and cross-fade, so nothing pops. The trees stand on the slopes
## between `min_height` and the tree line (`tree_line`), thinning out towards it, and keep off
## steep rock and off the tunnels' entrances. They have no collision (the hills cannot be
## reached: the invisible border walls keep you in the town).

const MODEL := "res://assets/models/tree2.glb"
const CHUNK := 90.0
## The pine's crown, measured from the model: it starts 0.83 m above the origin, is 5.9 m tall
## and 2.15 m in radius; the trunk reaches 1 m below the origin.
const CROWN_BOTTOM := 0.83
const CROWN_HEIGHT := 5.9
const CROWN_RADIUS := 2.15
const CROWN_COLOR := Color(0.2, 0.44, 0.2)

## The landscape whose height decides where trees stand (set by TownBuilder).
var landscape: Landscape = null
## Distance between planting spots, in metres (a tree stands on most of them).
@export var spacing: float = 8.0
## Full model within this distance of you, cone beyond it (and out to `far_range`).
@export var near_range: float = 170.0
@export var far_range: float = 1000.0
## Trees grow on ground higher than this (the flat land round the town is left to the grass)
## and thin out towards the tree line.
@export var min_height: float = 2.5
@export var tree_line: float = 75.0
@export var noise_seed: int = 5

var _rng := RandomNumberGenerator.new()
var _count: int = 0


func get_count() -> int:
	return _count


func build() -> void:
	if landscape == null:
		return
	_rng.seed = noise_seed
	var near_trees: Array[Transform3D] = []
	var far_trees: Array[Transform3D] = []
	var outer := landscape.inner.grow(landscape.reach)
	var columns := int(outer.size.x / spacing)
	var rows := int(outer.size.y / spacing)
	for j in rows:
		for i in columns:
			var p := outer.position + (Vector2(i, j) + Vector2(_rng.randf(), _rng.randf())) * spacing
			if landscape.distance_outside(p) < 3.0:
				continue
			var tree := _tree_at(p)
			if tree == Transform3D.IDENTITY:
				continue
			near_trees.append(tree)
	# Random order, so that a chunk showing only its first N trees (the graphics setting
	# "Forest") is thinned evenly instead of losing a strip.
	for i in range(near_trees.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := near_trees[i]
		near_trees[i] = near_trees[j]
		near_trees[j] = swap
	far_trees = near_trees.duplicate()
	_count = near_trees.size()
	_batch_model(near_trees)
	_batch_cones(far_trees)


## The transform of the tree planted at `p`, or IDENTITY when none grows there.
func _tree_at(p: Vector2) -> Transform3D:
	var h := landscape.height_at(p.x, p.y)
	if h < min_height or h > tree_line:
		return Transform3D.IDENTITY
	# thinner and thinner towards the tree line
	if _rng.randf() > 1.0 - smoothstep(tree_line - 22.0, tree_line, h):
		return Transform3D.IDENTITY
	# not on steep rock
	var step := 3.0
	var slope := Vector2(landscape.height_at(p.x + step, p.y) - landscape.height_at(p.x - step, p.y),
			landscape.height_at(p.x, p.y + step) - landscape.height_at(p.x, p.y - step)).length() / (2.0 * step)
	if slope > 1.1:
		return Transform3D.IDENTITY
	# not in front of a tunnel (the portal and its roof stand there)
	for tunnel in TownLayout.TUNNELS:
		var rel := p - (tunnel.spot as Vector2)
		if rel.dot(tunnel.dir as Vector2) < 45.0 and absf(rel.cross(tunnel.dir as Vector2)) < 20.0:
			return Transform3D.IDENTITY
	var size_scale := _rng.randf_range(1.6, 3.0)
	# (the trunk reaches 1 m under the model's origin, so it is lifted by one scale)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3.ONE * size_scale)
	return Transform3D(basis, Vector3(p.x, Landscape.BASE_Y + h + size_scale * 0.9, p.y))


# ---- Drawing -----------------------------------------------------------------------------

func _batch_model(trees: Array[Transform3D]) -> void:
	if trees.is_empty():
		return
	var root := (load(MODEL) as PackedScene).instantiate() as Node3D
	var parts: Array[Dictionary] = []
	var leaf_materials := Foliage.make_materials(root, 0.06)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var local := Transform3D.IDENTITY
		var walker: Node = mesh_instance
		while walker != root:
			local = (walker as Node3D).transform * local
			walker = walker.get_parent()
		parts.append({"mesh": mesh_instance.mesh, "local": local, "material": leaf_materials.get(mesh_instance)})
	root.free()
	var group := Node3D.new()
	group.name = "Pines"
	add_child(group)
	var chunks := _chunks(trees)
	for part in parts:
		for key in chunks:
			var list: Array = chunks[key]
			var holder := _holder(part.mesh as Mesh, list, part.local as Transform3D)
			holder.name = "Chunk_%d_%d" % [key.x, key.y]
			if part.material != null:
				holder.material_override = part.material
			holder.visibility_range_end = near_range
			holder.visibility_range_end_margin = 25.0
			holder.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			group.add_child(holder)
			Graphics.register_thinnable(holder, "forest")


func _batch_cones(trees: Array[Transform3D]) -> void:
	if trees.is_empty():
		return
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = CROWN_RADIUS
	cone.height = CROWN_HEIGHT
	cone.radial_segments = 6
	cone.rings = 1
	cone.cap_bottom = false
	var material := StandardMaterial3D.new()
	material.albedo_color = CROWN_COLOR
	material.roughness = 1.0
	cone.material = material
	var local := Transform3D(Basis(), Vector3(0, CROWN_BOTTOM + CROWN_HEIGHT / 2.0, 0))
	var group := Node3D.new()
	group.name = "FarPines"
	add_child(group)
	var chunks := _chunks(trees)
	for key in chunks:
		var holder := _holder(cone, chunks[key] as Array, local)
		holder.name = "Chunk_%d_%d" % [key.x, key.y]
		holder.visibility_range_begin = near_range - 25.0
		holder.visibility_range_begin_margin = 25.0
		holder.visibility_range_end = far_range
		holder.visibility_range_end_margin = 50.0
		holder.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(holder)
		Graphics.register_thinnable(holder, "forest")


func _chunks(trees: Array[Transform3D]) -> Dictionary:
	var chunks := {}
	for t in trees:
		var key := Vector2i(floori(t.origin.x / CHUNK), floori(t.origin.z / CHUNK))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(t)
	return chunks


func _holder(mesh: Mesh, list: Array, local: Transform3D) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = list.size()
	for i in list.size():
		multimesh.set_instance_transform(i, (list[i] as Transform3D) * local)
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = multimesh
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return holder
