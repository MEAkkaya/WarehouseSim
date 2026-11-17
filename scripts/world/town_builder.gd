class_name TownBuilder
extends Node3D
## The town generator: only what is too numerous to place by hand. The world is ONE scene
## (scenes/levels/world.tscn): the ground, roads, railway, lakes, fields, every building
## (houses and apartment blocks, factories, shops, barns, station, the two special apartment
## blocks), props and trees are ordinary nodes under `Town` that you see and move in the
## editor. At game start this node
##   - reads those nodes (TownLayout.scan), so nothing generated lands on them,
##   - cuts the night club's stair shaft into the ground slab,
##   - puts an invisible fence round the lakes,
##   - lays sidewalks along every road and scatters vegetation (TownScenery, MultiMesh),
##   - adds street lamps, utility poles with cables and road markings (StreetFurniture),
##   - builds the world border and the scenery beyond it (Landscape: forested hills, mountains and
##     the hillsides of the tunnels; HillForest: their trees with two levels of detail).
## Nodes in the group "editor_only" (reference boxes) are removed when the game starts.

## The node with the hand-placed town (ground, roads, buildings...).
@export var town_path: NodePath = ^"../Town"
## Chunks further away than this are hidden (should match the fog).
@export var view_distance: float = 330.0

const G := TownLayout.GROUND_TOP

var _materials: Dictionary = {}
var _town: Node = null
## Rectangles (x, z) of everything built so far, so later things avoid them.
var _occupied: Array[Rect2] = []
## Rectangles cut out of the ground for the lakes (see LakeBasin).
var _lake_holes: Array[Rect2] = []


func _ready() -> void:
	_town = get_node_or_null(town_path)
	if _town == null:
		push_warning("TownBuilder: no town node at %s" % town_path)
		return
	for node in get_tree().get_nodes_in_group("editor_only"):
		node.get_parent().remove_child(node)
		node.queue_free()
	TownLayout.scan(_town)
	_collect_occupied()
	_build_lakes()
	_build_ground()
	_build_scenery()
	_build_street_furniture()
	_build_border()
	_build_landscape()


# ---- Helpers -------------------------------------------------------------------

func _material(color: Color, vertex_colors: bool = false) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), vertex_colors]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.vertex_color_use_as_albedo = vertex_colors
		_materials[key] = material
	return _materials[key]


func _yaw_between(a: Vector2, b: Vector2) -> float:
	# Rotation about Y that turns a box's long axis (local X) along a -> b.
	return atan2(-(b.y - a.y), b.x - a.x)


## A single solid box (visible, optionally with collision).
func _solid_box(parent: Node3D, center: Vector3, size: Vector3, color: Color,
		yaw: float = 0.0, collide: bool = true) -> void:
	var holder: Node3D
	if collide:
		holder = StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		holder.add_child(shape)
	else:
		holder = Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	mesh_instance.mesh = mesh
	holder.add_child(mesh_instance)
	holder.position = center
	holder.rotation.y = yaw
	parent.add_child(holder)


func _group(group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	add_child(node)
	return node


func _rect_of(x: float, z: float, w: float, d: float) -> Rect2:
	return Rect2(x - w / 2.0, z - d / 2.0, w, d)


# ---- What is already standing ------------------------------------------------------

## Fills `_occupied` from the scene: every mesh under Buildings and Props, the lakes and the
## two special apartment blocks (whose rooms are built in code, so they are measured by hand).
func _collect_occupied() -> void:
	for lake in TownLayout.LAKES:
		_occupied.append(Rect2(lake.center - lake.radius, lake.radius * 2.0))
	for holder_name in ["Buildings", "Props"]:
		var holder := _town.get_node_or_null(holder_name)
		if holder != null:
			_collect_footprints(holder)


func _collect_footprints(node: Node) -> void:
	if node is ApartmentBuilding:
		var spot := Vector2((node as Node3D).global_position.x, (node as Node3D).global_position.z)
		_occupied.append(_rect_of(spot.x, spot.y, 9.0, 8.0))
		if node is ClubApartment:
			# the club's back door opens on a yard where no house stands
			_occupied.append(_rect_of(spot.x, spot.y - 8.5, 11.0, 9.0))
		return
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		_occupied.append(TownLayout.footprint(node as MeshInstance3D))
	for child in node.get_children():
		_collect_footprints(child)


# ---- Ground, lakes -------------------------------------------------------------------

## The ground slab in the scene is one big box. The night club's stair shaft and the lakes are
## holes in it, so the slab is replaced by pieces around the holes (same colour, same height).
func _build_ground() -> void:
	var ground := _town.get_node_or_null("Ground") as StaticBody3D
	if ground == null:
		return
	var mesh_node: MeshInstance3D = null
	for child in ground.get_children():
		if child is MeshInstance3D:
			mesh_node = child
			break
	if mesh_node == null:
		return
	var rect := TownLayout.footprint(mesh_node)
	var box := mesh_node.global_transform * mesh_node.get_aabb()
	var color := Color(0.36, 0.52, 0.32)
	if mesh_node.mesh.material is StandardMaterial3D:
		color = (mesh_node.mesh.material as StandardMaterial3D).albedo_color
	var pieces: Array[Rect2] = [rect]
	var holes: Array[Rect2] = TownLayout.ground_holes()
	holes.append_array(_lake_holes)
	for hole in holes:
		var next: Array[Rect2] = []
		for piece in pieces:
			next.append_array(_carve(piece, hole))
		pieces = next
	if pieces.size() == 1 and pieces[0] == rect:
		return  # no hole in this slab: leave it as it is
	ground.get_parent().remove_child(ground)
	ground.queue_free()
	var group := _group("Ground")
	for piece in pieces:
		_solid_box(group, Vector3(piece.get_center().x, box.position.y + box.size.y / 2.0, piece.get_center().y),
				Vector3(piece.size.x, box.size.y, piece.size.y), color)


## `rect` minus `hole`, as up to four rectangles (or `rect` itself when they do not touch).
func _carve(rect: Rect2, hole: Rect2) -> Array[Rect2]:
	if not rect.intersects(hole):
		return [rect]
	var cut := rect.intersection(hole)   # (the hole may stick out of the rectangle)
	var parts: Array[Rect2] = []
	parts.append(Rect2(rect.position.x, rect.position.y, cut.position.x - rect.position.x, rect.size.y))
	parts.append(Rect2(cut.end.x, rect.position.y, rect.end.x - cut.end.x, rect.size.y))
	parts.append(Rect2(cut.position.x, rect.position.y, cut.size.x, cut.position.y - rect.position.y))
	parts.append(Rect2(cut.position.x, cut.end.y, cut.size.x, rect.end.y - cut.end.y))
	var result: Array[Rect2] = []
	for part in parts:
		if part.size.x > 0.01 and part.size.y > 0.01:
			result.append(part)
	return result


## Digs the lakes (LakeBasin: bed, banks, sand, water with depth) and fences the shore, so
## nobody walks onto the water. The TownLake node is lowered to the water level and gets the
## water shader; the flat sand disc of the scene is replaced by the sand of the bank.
func _build_lakes() -> void:
	var group := _group("Lakes")
	var holder := _town.get_node_or_null("Lakes")
	if holder == null:
		return
	var basin := LakeBasin.new()
	basin.name = "Basins"
	group.add_child(basin)
	var water := ShaderMaterial.new()
	water.shader = load("res://assets/shaders/lake_water.gdshader")
	var sands: Array[Node] = []
	var lake_nodes: Array[TownLake] = []
	for node in holder.get_children():
		var lake := node as TownLake
		if lake == null:
			continue
		var sand := holder.get_node_or_null(String(lake.name) + "Sand") as MeshInstance3D
		if sand == null and lake.beach:
			sand = holder.get_node_or_null("BeachSand") as MeshInstance3D
		basin.lakes.append(LakeBasin.describe(lake, sand))
		lake_nodes.append(lake)
		if sand != null:
			sands.append(sand)
	for index in lake_nodes.size():
		basin.build(index)
		_lake_holes.append(LakeBasin.hole_rect(basin.lakes[index]))
		# the water: a hair wider than the shore line, so the bank hides its edge
		var lake := lake_nodes[index]
		lake.material_override = water
		lake.scale = Vector3(lake.scale.x * 1.03, lake.scale.y, lake.scale.z * 1.03)
		lake.global_position.y = LakeBasin.water_level() - 0.02
	for sand in sands:
		sand.get_parent().remove_child(sand)
		sand.queue_free()
	for lake in TownLayout.LAKES:
		var center: Vector2 = lake.center
		var radius: Vector2 = lake.radius
		var barrier := StaticBody3D.new()
		barrier.name = "ShoreBarrier"
		group.add_child(barrier)
		var segments := 40
		for k in segments:
			var a := Vector2(cos(TAU * k / segments), sin(TAU * k / segments)) * radius + center
			var b := Vector2(cos(TAU * (k + 1) / segments), sin(TAU * (k + 1) / segments)) * radius + center
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(a.distance_to(b) + 0.5, 4.0, 2.0)
			shape.shape = box
			shape.transform = Transform3D(Basis(Vector3.UP, _yaw_between(a, b)),
					Vector3((a.x + b.x) / 2.0, 1.0, (a.y + b.y) / 2.0))
			barrier.add_child(shape)


# ---- Sidewalks and vegetation ----------------------------------------------------------

func _build_scenery() -> void:
	var scenery := TownScenery.new()
	scenery.name = "Scenery"
	scenery.occupied = _occupied
	scenery.view_distance = view_distance
	scenery.blockers = _collect_blockers()
	add_child(scenery)
	scenery.build()
	print("TownBuilder: scenery ", scenery.get_counts())


## Street lamps, utility poles with cables and road markings (StreetFurniture).
func _build_street_furniture() -> void:
	var furniture := StreetFurniture.new()
	furniture.name = "StreetFurniture"
	furniture.occupied = _occupied
	furniture.view_distance = view_distance
	furniture.blockers = _collect_blockers()
	add_child(furniture)
	furniture.build()
	print("TownBuilder: street furniture ", furniture.get_counts())


## Things already standing that the scatter and the street furniture must not grow through:
## hand-placed props and the hand-placed trees.
func _collect_blockers() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for node_name in ["Props", "Trees"]:
		var holder := _town.get_node_or_null(node_name)
		if holder != null:
			for child in holder.get_children():
				if child is Node3D:
					points.append(Vector2((child as Node3D).position.x, (child as Node3D).position.z))
	return points


# ---- Scenery beyond the border -----------------------------------------------------

func _build_landscape() -> void:
	var landscape := Landscape.new()
	landscape.name = "Landscape"
	landscape.inner = TownLayout.BOUNDS
	add_child(landscape)
	var forest := HillForest.new()
	forest.name = "HillForest"
	forest.landscape = landscape
	add_child(forest)
	forest.build()
	print("TownBuilder: hill trees ", forest.get_count())


# ---- Invisible border ---------------------------------------------------------------

func _build_border() -> void:
	var group := _group("WorldBorder")
	var bounds := TownLayout.BOUNDS
	var body := StaticBody3D.new()
	body.name = "InvisibleWalls"
	group.add_child(body)
	var thickness := 4.0
	var height := 30.0
	var walls := [
		[Vector3(bounds.get_center().x, height / 2.0, bounds.position.y - thickness / 2.0), Vector3(bounds.size.x + 2 * thickness, height, thickness)],
		[Vector3(bounds.get_center().x, height / 2.0, bounds.end.y + thickness / 2.0), Vector3(bounds.size.x + 2 * thickness, height, thickness)],
		[Vector3(bounds.position.x - thickness / 2.0, height / 2.0, bounds.get_center().y), Vector3(thickness, height, bounds.size.y)],
		[Vector3(bounds.end.x + thickness / 2.0, height / 2.0, bounds.get_center().y), Vector3(thickness, height, bounds.size.y)],
	]
	# (a tunnel leaves the map through a gap in the wall)
	var gaps: Array = [[], [], [], []]   # north, south, west, east
	for tunnel in TownLayout.TUNNELS:
		var spot: Vector2 = tunnel.spot
		var dir: Vector2 = tunnel.dir
		if absf(dir.y) > absf(dir.x):
			gaps[0 if dir.y < 0.0 else 1].append(Vector2(spot.x - 7.0, spot.x + 7.0))
		else:
			gaps[2 if dir.x < 0.0 else 3].append(Vector2(spot.y - 7.0, spot.y + 7.0))
	for k in walls.size():
		_wall(body, walls[k][0], walls[k][1], gaps[k])


## One border wall (a box centred at `center`), in pieces round the gaps (each gap is a range
## along the wall's long side: world x for walls along x, world z for walls along z).
func _wall(body: StaticBody3D, center: Vector3, size: Vector3, gaps: Array) -> void:
	var along_x := size.x > size.z
	var start := center.x - size.x / 2.0 if along_x else center.z - size.z / 2.0
	var end := start + (size.x if along_x else size.z)
	gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var pieces: Array[Vector2] = []
	var cursor := start
	for gap: Vector2 in gaps:
		if gap.x > cursor:
			pieces.append(Vector2(cursor, gap.x))
		cursor = maxf(cursor, gap.y)
	if cursor < end:
		pieces.append(Vector2(cursor, end))
	for piece in pieces:
		var length := piece.y - piece.x
		var middle := (piece.x + piece.y) / 2.0
		var box := BoxShape3D.new()
		var shape := CollisionShape3D.new()
		if along_x:
			box.size = Vector3(length, size.y, size.z)
			shape.position = Vector3(middle, center.y, center.z)
		else:
			box.size = Vector3(size.x, size.y, length)
			shape.position = Vector3(center.x, center.y, middle)
		shape.shape = box
		body.add_child(shape)
