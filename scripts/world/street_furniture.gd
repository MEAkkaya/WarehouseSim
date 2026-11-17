class_name StreetFurniture
extends Node3D
## City furniture along the roads, made from simple shapes (no models; see StreetFixtures):
##   - street lamps, alternating sides, with a lit panel and a pool of light at night,
##   - utility poles with cables hanging between them (only on roads that ask for it),
##   - road markings: a dashed centre line and painted parking bays (per road).
## It reads the roads from TownLayout (the TownRoad nodes of the scene, where each road has
## the switches `street_lamps`, `utility_poles`, `parking`, `center_line`) and keeps off
## crossing streets, the railway, lakes, buildings and props. TownBuilder creates it after
## the scenery. Everything is MultiMesh chunks (cheap), no collision except thin poles.

const G := TownLayout.GROUND_TOP
const CHUNK := 60.0
const LAMP_SPACING := 26.0
const POLE_SPACING := 34.0
## Distance from the edge of the road to the lamp / pole (the curb is 0.5 m wide).
const LAMP_SET_BACK := 0.95
const POLE_SET_BACK := 1.9
const DASH_LENGTH := 2.4
const DASH_PERIOD := 6.0
const BAY_LENGTH := 6.0
const BAY_DEPTH := 2.2
const MARK_THICKNESS := 0.012

## Set by TownBuilder before `build()`.
var occupied: Array[Rect2] = []
var blockers: Array[Vector2] = []
var view_distance: float = 330.0

var _counts := {"lamp": 0, "pole": 0, "cable": 0, "dash": 0, "bay": 0}
var _pool_nodes: Array[GeometryInstance3D] = []
var _poles: Array[Vector2] = []
var _night: float = -1.0
var _timer: float = 0.0
var _unit_box: BoxMesh = null


## Build time statistics, for the tests.
func get_counts() -> Dictionary:
	return _counts


func build() -> void:
	_poles.clear()
	for road in TownLayout.ROADS:
		if road.poles:
			_build_poles(road)
	var lamps: Array[Transform3D] = []
	for road in TownLayout.ROADS:
		if road.lamps:
			_collect_lamps(road, lamps)
	_counts.lamp = lamps.size()
	_multimesh("Lamps", StreetFixtures.lamp_mesh(), lamps, view_distance * 0.8, true)
	_pool_nodes.append_array(_multimesh("LampLight", StreetFixtures.pool_mesh(), lamps, 140.0, false))
	_build_markings()
	_update_night(true)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.25
		_update_night(false)


## Lamps shine and the ground is lit between dusk and dawn.
func _update_night(force: bool) -> void:
	var night := 1.0 - smoothstep(-0.1, 0.35, GameState.get_sun_height())
	if not force and absf(night - _night) < 0.01:
		return
	_night = night
	StreetFixtures.set_night(night)
	for node in _pool_nodes:
		node.visible = night > 0.01


# ---- Places --------------------------------------------------------------------------

## Points every `spacing` metres along the line: {p, dir, normal} (normal = right-hand side).
func _along(points: PackedVector2Array, spacing: float, start: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var next := start
	var travelled := 0.0
	for e in points.size() - 1:
		var a := points[e]
		var length := a.distance_to(points[e + 1])
		if length < 0.001:
			continue
		var dir := (points[e + 1] - a) / length
		while next <= travelled + length:
			result.append({"p": a + dir * (next - travelled), "dir": dir, "normal": Vector2(-dir.y, dir.x)})
			next += spacing
		travelled += length
	return result


## Is `p` a place where something may stand next to `own` (not on the railway, a lake, in
## the warehouse yard, in another street's way...)? `clearance` = metres to keep from the
## edge of the other streets.
func _clear_of_world(p: Vector2, own: Dictionary, clearance: float) -> bool:
	if not TownLayout.BOUNDS.grow(-3.0).has_point(p):
		return false
	for index in [0, 1, 2]:
		if TownLayout.KEEP_OUT[index].has_point(p):
			return false
	if TownLayout.distance_to_polyline(p, TownLayout.RAIL) < TownLayout.RAIL_HALF_WIDTH + 1.5:
		return false
	for lake in TownLayout.LAKES:
		if TownLayout.ellipse_value(p, lake.center, lake.radius) < 1.12:
			return false
	for road in TownLayout.ROADS:
		if road != own and TownLayout.distance_to_polyline(p, road.points) < road.width / 2.0 + clearance:
			return false
	return true


## Like `_clear_of_world`, and also not inside a building or on a prop.
func _clear_of_things(p: Vector2, own: Dictionary, clearance: float) -> bool:
	if not _clear_of_world(p, own, clearance):
		return false
	for rect in occupied:
		if rect.grow(0.4).has_point(p):
			return false
	for blocker in blockers:
		if p.distance_to(blocker) < 1.5:
			return false
	return true


## The transform of something standing at `p` whose local +X points along `toward` (x, z).
func _stand(p: Vector2, toward: Vector2) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, atan2(-toward.y, toward.x)), Vector3(p.x, G, p.y))


# ---- Lamps -----------------------------------------------------------------------------

func _collect_lamps(road: Dictionary, lamps: Array[Transform3D]) -> void:
	var side := 1.0
	for spot in _along(road.points, LAMP_SPACING, LAMP_SPACING * 0.5):
		var normal: Vector2 = spot.normal
		var p: Vector2 = spot.p + normal * side * (road.width / 2.0 + LAMP_SET_BACK)
		if _clear_of_things(p, road, 2.5) and _far_from_poles(p):
			lamps.append(_stand(p, -normal * side))
		side = -side


func _far_from_poles(p: Vector2) -> bool:
	for pole in _poles:
		if pole.distance_to(p) < 3.0:
			return false
	return true


# ---- Utility poles and cables ------------------------------------------------------------

func _build_poles(road: Dictionary) -> void:
	var spots := _along(road.points, POLE_SPACING, POLE_SPACING * 0.5)
	# One side of the road for the whole line (the one with more room).
	var best_side := 1.0
	var best_count := -1
	for side: float in [1.0, -1.0]:
		var count := 0
		for spot in spots:
			var normal: Vector2 = spot.normal
			if _clear_of_things(spot.p + normal * side * (road.width / 2.0 + POLE_SET_BACK), road, 3.0):
				count += 1
		if count > best_count:
			best_count = count
			best_side = side
	var transforms: Array[Transform3D] = []
	var chain: Array[Transform3D] = []      # the poles of the current unbroken run
	var cables := PackedVector3Array()      # pairs of points (start, end), world space
	for spot in spots:
		var normal: Vector2 = spot.normal
		var p: Vector2 = spot.p + normal * best_side * (road.width / 2.0 + POLE_SET_BACK)
		if _clear_of_things(p, road, 3.0):
			var pole := _stand(p, normal)
			transforms.append(pole)
			_poles.append(p)
			if not chain.is_empty():
				for attach in StreetFixtures.POLE_ATTACH:
					cables.append(chain[-1] * attach)
					cables.append(pole * attach)
			chain.append(pole)
		else:
			chain.clear()
	if transforms.is_empty():
		return
	_counts.pole += transforms.size()
	_multimesh("Poles_%s" % road.name, StreetFixtures.pole_mesh(), transforms, view_distance * 0.8, true)
	_add_pole_colliders(transforms)
	_counts.cable += cables.size() / 2
	_add_cables(road.name, cables)


## A thin solid pole each (shared shape), in one body per chunk.
func _add_pole_colliders(poles: Array[Transform3D]) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = 0.18
	shape.height = 4.0
	var bodies := {}
	for pole in poles:
		var key := Vector2i(floori(pole.origin.x / CHUNK), floori(pole.origin.z / CHUNK))
		if not bodies.has(key):
			var body := StaticBody3D.new()
			body.name = "PoleColliders_%d_%d" % [key.x, key.y]
			add_child(body)
			bodies[key] = body
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = pole.origin + Vector3(0, 2.0, 0)
		(bodies[key] as StaticBody3D).add_child(collision)


## Cables hang between the attach points (pairs in `ends`): a thin ribbon with some sag.
func _add_cables(road_name: String, ends: PackedVector3Array) -> void:
	if ends.is_empty():
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var half := 0.018
	for i in range(0, ends.size(), 2):
		var a := ends[i]
		var b := ends[i + 1]
		var sag := a.distance_to(b) * 0.03
		var steps := 8
		var previous := a
		for s in range(1, steps + 1):
			var t := float(s) / steps
			var point := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
			var along := (point - previous).normalized()
			var flat := along.cross(Vector3.UP).normalized() * half
			_quad(tool, previous - flat, previous + flat, point + flat, point - flat)
			_quad(tool, previous - Vector3.UP * half, previous + Vector3.UP * half,
					point + Vector3.UP * half, point - Vector3.UP * half)
			previous = point
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05, 0.05, 0.06)
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.name = "Cables_%s" % road_name
	instance.mesh = tool.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = view_distance * 0.8
	add_child(instance)


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for corner in [a, b, c, a, c, d]:
		tool.add_vertex(corner)


# ---- Road markings -----------------------------------------------------------------------

func _build_markings() -> void:
	var dashes: Array[Transform3D] = []
	var bays: Array[Transform3D] = []
	for road in TownLayout.ROADS:
		var y: float = G + road.lift + MARK_THICKNESS * 0.5 + 0.012
		var half: float = road.width / 2.0
		if road.center_line:
			for spot in _along(road.points, DASH_PERIOD, DASH_PERIOD * 0.5):
				var p: Vector2 = spot.p
				if _clear_of_world(p, road, 1.0):
					dashes.append(_strip(p, spot.dir, DASH_LENGTH, 0.14, y))
		if road.parking != 0:
			var sides: Array[float] = []
			if road.parking == 1 or road.parking == 3:
				sides.append(-1.0)
			if road.parking == 2 or road.parking == 3:
				sides.append(1.0)
			for spot in _along(road.points, BAY_LENGTH, BAY_LENGTH * 0.5):
				for side in sides:
					_bay(road, spot, side, half, y, bays)
	_counts.dash = dashes.size()
	_counts.bay = bays.size()
	_strips("CenterLine", dashes, Color(0.92, 0.9, 0.8))
	_strips("ParkingBays", bays, Color(0.95, 0.95, 0.95))


## One parking bay mark: the line that separates two bays, and the line along the road.
func _bay(road: Dictionary, spot: Dictionary, side: float, half: float, y: float, bays: Array[Transform3D]) -> void:
	var normal: Vector2 = spot.normal
	var dir: Vector2 = spot.dir
	var middle: Vector2 = spot.p
	# (no bays near the streets that cross, and none where the line itself is not clear)
	if not _clear_of_world(middle + normal * side * (half - BAY_DEPTH * 0.5), road, 3.5):
		return
	bays.append(_strip(middle + normal * side * (half - BAY_DEPTH * 0.5), normal, BAY_DEPTH, 0.12, y))
	bays.append(_strip(middle + normal * side * (half - BAY_DEPTH) + dir * (BAY_LENGTH * 0.5), dir, BAY_LENGTH - 0.15, 0.12, y))


## A flat box of `length` (along `dir`) x `width`, centred at `p`.
func _strip(p: Vector2, dir: Vector2, length: float, width: float, y: float) -> Transform3D:
	var basis := Basis(Vector3.UP, atan2(-dir.y, dir.x)).scaled_local(Vector3(length, MARK_THICKNESS, width))
	return Transform3D(basis, Vector3(p.x, y, p.y))


func _strips(group_name: String, transforms: Array[Transform3D], color: Color) -> void:
	if transforms.is_empty():
		return
	if _unit_box == null:
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	var mesh := _unit_box.duplicate() as BoxMesh
	mesh.material = material
	_multimesh(group_name, mesh, transforms, 160.0, false)


# ---- MultiMesh chunks -----------------------------------------------------------------------

## Draws `transforms` copies of `mesh`, as MultiMesh chunks hidden when far away.
func _multimesh(group_name: String, mesh: Mesh, transforms: Array[Transform3D], visible_range: float,
		shadows: bool) -> Array[GeometryInstance3D]:
	var made: Array[GeometryInstance3D] = []
	if transforms.is_empty():
		return made
	var chunks := {}
	for t in transforms:
		var key := Vector2i(floori(t.origin.x / CHUNK), floori(t.origin.z / CHUNK))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(t)
	var group := Node3D.new()
	group.name = group_name
	add_child(group)
	for key in chunks:
		var list: Array = chunks[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = list.size()
		for i in list.size():
			multimesh.set_instance_transform(i, list[i])
		var holder := MultiMeshInstance3D.new()
		holder.name = "Chunk_%d_%d" % [key.x, key.y]
		holder.multimesh = multimesh
		holder.visibility_range_end = visible_range
		holder.visibility_range_end_margin = 15.0
		holder.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if not shadows:
			holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(holder)
		made.append(holder)
	return made
