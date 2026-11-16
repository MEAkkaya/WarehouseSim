class_name TownScenery
extends Node3D
## Fills the town with vegetation and puts a sidewalk (curb) along both sides of every
## street. TownBuilder creates it after the buildings, so it knows what is already
## standing. Everything is placed with MultiMesh (one draw call per 60 m chunk, hidden
## when far away), from your models in assets/models:
##   sidewalk.glb / sidewalk_corner.glb  curb pieces along the roads (corners at bends and ends)
##   tree2.glb, bush1.glb, grass.glb     scattered over the open ground, thick in the woods,
##                                       a belt of trees along the world border
## Random but seeded: the same town every run. Change the numbers in the "Density"
## section to make it fuller or emptier.

const G := TownLayout.GROUND_TOP
const CHUNK := 60.0
## Size of the cells of the "is this spot free?" grid, in metres.
const CELL := 2.0

const SIDEWALK := "res://assets/models/sidewalk.glb"
const SIDEWALK_CORNER := "res://assets/models/sidewalk_corner.glb"
const TREE := "res://assets/models/tree2.glb"
const BUSH := "res://assets/models/bush1.glb"
const GRASS := "res://assets/models/grass.glb"

## Why a curb piece may or may not stand somewhere (see `_curb_state`).
enum CurbState { OK, AT_STREET, BLOCKED }

## Length of one sidewalk piece (the model's long side) and the curb's width, in metres.
const PIECE_LENGTH := 1.346
const CURB_WIDTH := 0.464
const CURB_HEIGHT := 0.41

# ---- Density: one thing per this many square metres of FREE ground (smaller = fuller) --
# (Streets, buildings, lakes, the railway, farm fields and the industrial estate are not
# free ground.)
const WOODS_TREE := 34.0
const WOODS_BUSH := 28.0
const WOODS_GRASS := 5.0
const YARD_TREE := 150.0
const YARD_BUSH := 40.0
const YARD_GRASS := 6.0
const OPEN_TREE := 120.0
const OPEN_BUSH := 45.0
const OPEN_GRASS := 5.5
## The three tree sizes (also the three trunk collider sizes).
const TREE_SIZES: Array[float] = [0.8, 1.1, 1.4]
## Trees along the inside of the world border: one every this many metres, in two rows.
const BORDER_TREE_SPACING := 7.0

## Set by TownBuilder before `build()`.
var random_seed: int = 21
var occupied: Array[Rect2] = []              ## rectangles of the buildings already standing
var blockers: Array[Vector2] = []            ## points with something on them (props, hand-placed trees)
var lattice_origin: Vector2 = Vector2.ZERO   ## the neighbourhood's own streets
var lattice_pitch: Vector2 = Vector2(9, 8)
var street_every: int = 6
var street_ok: Callable                      ## TownBuilder._is_street_ok(Vector2) -> bool
var view_distance: float = 330.0

var _rng := RandomNumberGenerator.new()
var _streets: Array[Dictionary] = []         ## {points, half, lattice}
var _blocked := PackedByteArray()
var _taken := PackedByteArray()
var _cols: int = 0
var _rows: int = 0
var _origin: Vector2 = Vector2.ZERO
var _counts := {"sidewalk": 0, "corner": 0, "tree": 0, "bush": 0, "grass": 0}


## Build time statistics, for the tests.
func get_counts() -> Dictionary:
	return _counts


func build() -> void:
	_rng.seed = random_seed
	_origin = TownLayout.BOUNDS.position
	_cols = ceili(TownLayout.BOUNDS.size.x / CELL)
	_rows = ceili(TownLayout.BOUNDS.size.y / CELL)
	_blocked.resize(_cols * _rows)
	_taken.resize(_cols * _rows)
	_collect_streets()
	_build_sidewalks()
	_mark_blocked()
	_build_vegetation()


# ---- The streets -----------------------------------------------------------------------

func _collect_streets() -> void:
	for road in TownLayout.ROADS:
		_streets.append({"points": road.points, "half": road.width / 2.0, "lattice": false})
	# The neighbourhood's own streets: straight lines at every `street_every`-th lattice line.
	# (They run to the edge of the map; `street_ok` says where there really is a street.)
	var bounds := TownLayout.BOUNDS
	for i in range(0, 16, street_every):
		var x := lattice_origin.x + i * lattice_pitch.x
		_streets.append({"points": PackedVector2Array([Vector2(x, bounds.position.y), Vector2(x, bounds.end.y)]),
				"half": 2.6, "lattice": true})
	for j in range(0, 16, street_every):
		var z := lattice_origin.y + j * lattice_pitch.y
		_streets.append({"points": PackedVector2Array([Vector2(bounds.position.x, z), Vector2(bounds.end.x, z)]),
				"half": 2.6, "lattice": true})


# ---- Sidewalks -------------------------------------------------------------------------

func _build_sidewalks() -> void:
	var pieces: Array[Transform3D] = []
	var corners: Array[Transform3D] = []
	for street in _streets:
		var points: PackedVector2Array = street.points
		var offset: float = street.half + CURB_WIDTH / 2.0 + 0.05
		for side: float in [-1.0, 1.0]:
			for e in points.size() - 1:
				_sidewalk_edge(street, points, e, side, offset, pieces, corners)
			# A corner block at every bend of the street.
			for v in range(1, points.size() - 1):
				var n1 := _normal(points[v - 1], points[v])
				var n2 := _normal(points[v], points[v + 1])
				var p := points[v] + (n1 + n2).normalized() * offset * side
				if _curb_state(p, p, street) == CurbState.OK:
					corners.append(_transform_at(p, _yaw_of((points[v] - points[v - 1]).normalized()), 1.0))
	_batch(SIDEWALK, pieces, view_distance, true)
	_batch(SIDEWALK_CORNER, corners, view_distance, true)
	_counts.sidewalk = pieces.size()
	_counts.corner = corners.size()
	_add_curb_colliders(pieces)


func _normal(a: Vector2, b: Vector2) -> Vector2:
	var dir := (b - a).normalized()
	return Vector2(-dir.y, dir.x)


## Rotation about Y that turns the models' long axis (local Z) along `dir` (x, z).
func _yaw_of(dir: Vector2) -> float:
	return atan2(dir.x, dir.y)


func _transform_at(p: Vector2, yaw: float, z_scale: float) -> Transform3D:
	var basis := Basis(Vector3.UP, yaw).scaled_local(Vector3(1.0, 1.0, z_scale))
	return Transform3D(basis, Vector3(p.x, G, p.y))


func _sidewalk_edge(street: Dictionary, points: PackedVector2Array, e: int, side: float,
		offset: float, pieces: Array[Transform3D], corners: Array[Transform3D]) -> void:
	var a := points[e]
	var b := points[e + 1]
	var length := a.distance_to(b)
	var dir := (b - a) / length
	var normal := Vector2(-dir.y, dir.x)
	var count := maxi(1, roundi(length / PIECE_LENGTH))
	var step := length / count
	var yaw := _yaw_of(dir)
	# Straight curb is always the plain sidewalk model. The corner model is only used at
	# real corners: where the street bends (above) and where the curb turns the corner into
	# a street that crosses or joins this one (the run ends AT a street).
	var previous := CurbState.BLOCKED
	for k in count:
		var centre := a + dir * ((k + 0.5) * step)
		var p := centre + normal * offset * side
		var state := _curb_state(p, centre, street)
		if state == CurbState.OK:
			pieces.append(_transform_at(p, yaw, step / PIECE_LENGTH))
			if previous == CurbState.AT_STREET:  # a run starts right after a crossing street
				corners.append(_transform_at(p - dir * (step / 2.0 + CURB_WIDTH / 2.0 - 0.02), yaw, 1.0))
		elif state == CurbState.AT_STREET and previous == CurbState.OK:  # a run ends at a crossing street
			corners.append(_transform_at(p - dir * (step / 2.0 - CURB_WIDTH / 2.0 + 0.02), yaw, 1.0))
		previous = state


## May a curb piece stand at `p` (`centre` = the street's centre line point next to it)?
## OK, AT_STREET (another street crosses or joins here: the curb turns a corner), or
## BLOCKED (a railway, a lake, the border... the curb just stops).
func _curb_state(p: Vector2, centre: Vector2, street: Dictionary) -> CurbState:
	if not TownLayout.BOUNDS.grow(-1.0).has_point(p):
		return CurbState.BLOCKED
	# Not in front of the warehouse, in the truck yard or at the station.
	for index in [0, 1, 2]:
		if TownLayout.KEEP_OUT[index].has_point(p):
			return CurbState.BLOCKED
	if street.lattice and not street_ok.call(centre):
		return CurbState.BLOCKED  # the neighbourhood's street stops here (railway, lake)
	if TownLayout.distance_to_polyline(p, TownLayout.RAIL) < TownLayout.RAIL_HALF_WIDTH + 1.2:
		return CurbState.BLOCKED
	for lake in TownLayout.LAKES:
		if TownLayout.ellipse_value(p, lake.center, lake.radius) < 1.05:
			return CurbState.BLOCKED
	# Not across another street (leave the crossing open).
	for other in _streets:
		if other != street and TownLayout.distance_to_polyline(p, other.points) < other.half + 1.0:
			return CurbState.AT_STREET
	return CurbState.OK


## Invisible ramps over the curbs (about 34 degrees), so walking across a street is not
## stopped by a 41 cm step. Visually it is still the curb model.
func _add_curb_colliders(pieces: Array[Transform3D]) -> void:
	var ramp := 0.6
	var top := CURB_WIDTH / 2.0
	var half_length := PIECE_LENGTH / 2.0
	var points := PackedVector3Array()
	for z in [-half_length, half_length]:
		points.append_array([Vector3(-top - ramp, 0.0, z), Vector3(-top, CURB_HEIGHT, z),
				Vector3(top, CURB_HEIGHT, z), Vector3(top + ramp, 0.0, z)])
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var bodies := {}
	for piece in pieces:
		var key := Vector2i(floori(piece.origin.x / CHUNK), floori(piece.origin.z / CHUNK))
		if not bodies.has(key):
			var body := StaticBody3D.new()
			body.name = "SidewalkColliders_%d_%d" % [key.x, key.y]
			add_child(body)
			bodies[key] = body
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = Transform3D(piece.basis.orthonormalized(), piece.origin)
		(bodies[key] as StaticBody3D).add_child(collision)


# ---- The "free spot" grid --------------------------------------------------------------

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - _origin.x) / CELL), floori((p.y - _origin.y) / CELL))


func _index(cell: Vector2i) -> int:
	return cell.y * _cols + cell.x


func _in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _cols and cell.y < _rows


func _mark_circle(grid: PackedByteArray, centre: Vector2, radius: float) -> void:
	var low := _cell_of(centre - Vector2(radius, radius))
	var high := _cell_of(centre + Vector2(radius, radius))
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var cell := Vector2i(x, y)
			if _in_grid(cell):
				var cell_centre := _origin + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
				if cell_centre.distance_to(centre) <= radius + CELL * 0.5:
					grid[_index(cell)] = 1


func _mark_rect(grid: PackedByteArray, rect: Rect2) -> void:
	var low := _cell_of(rect.position)
	var high := _cell_of(rect.end)
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var cell := Vector2i(x, y)
			if _in_grid(cell):
				grid[_index(cell)] = 1


## Everything that is NOT free ground: streets with their curbs, buildings, props, lakes,
## the railway, paved and farmed areas.
func _mark_blocked() -> void:
	for street in _streets:
		var points: PackedVector2Array = street.points
		for e in points.size() - 1:
			var a := points[e]
			var b := points[e + 1]
			var steps := maxi(1, int(a.distance_to(b) / 1.5))
			for s in steps + 1:
				var spot := a.lerp(b, float(s) / steps)
				if street.lattice and not street_ok.call(spot):
					continue  # no street here
				_mark_circle(_blocked, spot, street.half + CURB_WIDTH + 0.9)
	for rect in occupied:
		_mark_rect(_blocked, rect.grow(0.8))
	for rect in TownLayout.KEEP_OUT:
		_mark_rect(_blocked, rect)
	_mark_rect(_blocked, TownLayout.INDUSTRIAL)
	for field in TownLayout.FIELDS:
		_mark_rect(_blocked, field.rect)
	for point in blockers:
		_mark_circle(_blocked, point, 2.5)
	# The railway.
	var rail := TownLayout.RAIL
	for e in rail.size() - 1:
		var steps := maxi(1, int(rail[e].distance_to(rail[e + 1]) / 2.0))
		for s in steps + 1:
			_mark_circle(_blocked, rail[e].lerp(rail[e + 1], float(s) / steps), TownLayout.RAIL_HALF_WIDTH + 2.5)
	# Lakes (and the beach round the first one).
	for lake in TownLayout.LAKES:
		var low := _cell_of(lake.center - lake.radius * 1.4)
		var high := _cell_of(lake.center + lake.radius * 1.4)
		var limit := 1.4 if lake.beach else 1.08
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var cell := Vector2i(x, y)
				if _in_grid(cell):
					var cell_centre := _origin + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL
					if TownLayout.ellipse_value(cell_centre, lake.center, lake.radius) < limit:
						_blocked[_index(cell)] = 1


## Is the spot free, with `reach` extra cells around it (bigger things need more room)?
func _is_free(p: Vector2, reach: int) -> bool:
	if not TownLayout.BOUNDS.grow(-1.0).has_point(p):
		return false
	var centre := _cell_of(p)
	for y in range(centre.y - reach, centre.y + reach + 1):
		for x in range(centre.x - reach, centre.x + reach + 1):
			var cell := Vector2i(x, y)
			if not _in_grid(cell):
				return false
			var i := _index(cell)
			if _blocked[i] != 0 or _taken[i] != 0:
				return false
	return true


func _take(p: Vector2, reach: int) -> void:
	var centre := _cell_of(p)
	for y in range(centre.y - reach, centre.y + reach + 1):
		for x in range(centre.x - reach, centre.x + reach + 1):
			var cell := Vector2i(x, y)
			if _in_grid(cell):
				_taken[_index(cell)] = 1


# ---- Vegetation ------------------------------------------------------------------------

func _build_vegetation() -> void:
	var trees: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	var tree_points: Array[Vector3] = []   # x, z, size class (for the trunk colliders)
	# The woods: thick.
	for rect in TownLayout.WOODS:
		_scatter(rect, WOODS_TREE, WOODS_BUSH, WOODS_GRASS, trees, bushes, grass, tree_points)
	# The neighbourhood's yards, and then all the other open ground.
	_scatter(TownLayout.NEIGHBOURHOOD, YARD_TREE, YARD_BUSH, YARD_GRASS, trees, bushes, grass, tree_points)
	_scatter(TownLayout.BOUNDS, OPEN_TREE, OPEN_BUSH, OPEN_GRASS, trees, bushes, grass, tree_points)
	_border_belt(trees, bushes, tree_points)
	_lake_shores(bushes, grass)
	_batch(TREE, trees, view_distance, true)
	_batch(BUSH, bushes, view_distance * 0.7, false)
	_batch(GRASS, grass, view_distance * 0.4, false, _wind_material())
	_counts.tree = trees.size()
	_counts.bush = bushes.size()
	_counts.grass = grass.size()
	_add_trunk_colliders(tree_points)


## Tries to place `area / density` things of each kind at random spots inside `rect`.
func _scatter(rect: Rect2, tree_area: float, bush_area: float, grass_area: float,
		trees: Array[Transform3D], bushes: Array[Transform3D], grass: Array[Transform3D],
		tree_points: Array[Vector3]) -> void:
	# Bushes and trees first (they need room), then grass in what is left.
	var free := _free_area(rect)
	_fill(int(free / tree_area), func(p: Vector2) -> bool: return _try_tree(p, trees, tree_points), rect)
	_fill(int(free / bush_area), func(p: Vector2) -> bool: return _try_bush(p, bushes), rect)
	_fill(int(free / grass_area), func(p: Vector2) -> bool: return _try_grass(p, grass), rect)


## Square metres of `rect` that are still free ground.
func _free_area(rect: Rect2) -> float:
	var count := 0
	var low := _cell_of(rect.position)
	var high := _cell_of(rect.end)
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var cell := Vector2i(x, y)
			if _in_grid(cell) and _blocked[_index(cell)] == 0 and _taken[_index(cell)] == 0:
				count += 1
	return count * CELL * CELL


## Calls `place` at random spots of `rect` until it has worked `wanted` times (or too many tries).
func _fill(wanted: int, place: Callable, rect: Rect2) -> void:
	var placed := 0
	var tries := 0
	while placed < wanted and tries < wanted * 12:
		tries += 1
		if place.call(_random_point(rect)):
			placed += 1


func _random_point(rect: Rect2) -> Vector2:
	return Vector2(_rng.randf_range(rect.position.x, rect.end.x), _rng.randf_range(rect.position.y, rect.end.y))


func _try_tree(p: Vector2, trees: Array[Transform3D], tree_points: Array[Vector3]) -> bool:
	if not _is_free(p, 1):
		return false
	_take(p, 1)
	var size_class := _rng.randi() % 3
	var size_scale: float = TREE_SIZES[size_class] * _rng.randf_range(0.93, 1.07)
	# tree2's trunk is centred on its origin (it reaches 1 m below it), so it is lifted.
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3.ONE * size_scale)
	trees.append(Transform3D(basis, Vector3(p.x, G + size_scale, p.y)))
	tree_points.append(Vector3(p.x, p.y, size_class))
	return true


func _try_bush(p: Vector2, bushes: Array[Transform3D]) -> bool:
	if not _is_free(p, 0):
		return false
	_take(p, 0)  # (a bush only claims its own cell: they may overlap a little, like real ones)
	var size_scale := _rng.randf_range(0.5, 1.0)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(size_scale, size_scale * _rng.randf_range(0.8, 1.2), size_scale))
	bushes.append(Transform3D(basis, Vector3(p.x, G, p.y)))
	return true


func _try_grass(p: Vector2, grass: Array[Transform3D]) -> bool:
	if not _is_free(p, 0):
		return false
	_take(p, 0)
	var size_scale := _rng.randf_range(0.28, 0.6)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled_local(Vector3(size_scale, size_scale * _rng.randf_range(0.7, 1.1), size_scale))
	grass.append(Transform3D(basis, Vector3(p.x, G, p.y)))
	return true


## Two rows of trees (and bushes between them) just inside the invisible walls, so the
## edge of the map looks like a tree line.
func _border_belt(trees: Array[Transform3D], bushes: Array[Transform3D], tree_points: Array[Vector3]) -> void:
	var bounds := TownLayout.BOUNDS
	var sides := [
		[Vector2(bounds.position.x, bounds.position.y), Vector2(bounds.end.x, bounds.position.y), Vector2(0, 1)],
		[Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.end.y), Vector2(0, -1)],
		[Vector2(bounds.position.x, bounds.position.y), Vector2(bounds.position.x, bounds.end.y), Vector2(1, 0)],
		[Vector2(bounds.end.x, bounds.position.y), Vector2(bounds.end.x, bounds.end.y), Vector2(-1, 0)],
	]
	for side in sides:
		var a: Vector2 = side[0]
		var b: Vector2 = side[1]
		var inward: Vector2 = side[2]
		var count := int(a.distance_to(b) / BORDER_TREE_SPACING)
		for i in count:
			var along := a.lerp(b, (i + _rng.randf()) / count)
			for row in 2:
				var p := along + inward * (4.0 + row * 7.0 + _rng.randf_range(0.0, 3.0))
				_try_tree(p, trees, tree_points)
			_try_bush(along + inward * _rng.randf_range(8.0, 12.0), bushes)


## Reeds and bushes round the lakes that have no beach.
func _lake_shores(bushes: Array[Transform3D], grass: Array[Transform3D]) -> void:
	for lake in TownLayout.LAKES:
		if lake.beach:
			continue
		for k in 160:
			var angle := TAU * k / 160.0
			var edge: Vector2 = lake.center + Vector2(cos(angle), sin(angle)) * lake.radius * _rng.randf_range(1.12, 1.3)
			if k % 5 == 0:
				_try_bush(edge, bushes)
			_try_grass(edge, grass)


## Solid trunks for the trees (three sizes, so three shared shapes).
func _add_trunk_colliders(tree_points: Array[Vector3]) -> void:
	var shapes: Array[CylinderShape3D] = []
	for size_scale: float in TREE_SIZES:
		var shape := CylinderShape3D.new()
		shape.radius = 0.9 * size_scale
		shape.height = 3.0 * size_scale
		shapes.append(shape)
	var bodies := {}
	for tp in tree_points:
		var key := Vector2i(floori(tp.x / CHUNK), floori(tp.y / CHUNK))
		if not bodies.has(key):
			var body := StaticBody3D.new()
			body.name = "TrunkColliders_%d_%d" % [key.x, key.y]
			add_child(body)
			bodies[key] = body
		var collision := CollisionShape3D.new()
		collision.shape = shapes[int(tp.z)]
		collision.position = Vector3(tp.x, G + 1.5 * TREE_SIZES[int(tp.z)], tp.y)
		(bodies[key] as StaticBody3D).add_child(collision)


## The grass is drawn with a wind shader (assets/shaders/grass_wind.gdshader): the tufts
## lean with a slow gust wave and the wind direction drifts. Purely visual.
func _wind_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/grass_wind.gdshader")
	return material


# ---- MultiMesh batches of a .glb model ---------------------------------------------------

## Draws `transforms` copies of every mesh of the model, as MultiMesh chunks.
func _batch(model_path: String, transforms: Array[Transform3D], visible_range: float,
		shadows: bool, material: Material = null) -> void:
	if transforms.is_empty():
		return
	var root := (load(model_path) as PackedScene).instantiate() as Node3D
	var parts: Array[Dictionary] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		# The mesh's place inside the model (the .glb nodes can be moved and scaled).
		var local := Transform3D.IDENTITY
		var walker: Node = mesh_instance
		while walker != root:
			local = (walker as Node3D).transform * local
			walker = walker.get_parent()
		parts.append({"mesh": mesh_instance.mesh, "local": local})
	root.free()
	var chunks := {}
	for t in transforms:
		var key := Vector2i(floori(t.origin.x / CHUNK), floori(t.origin.z / CHUNK))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(t)
	var group := Node3D.new()
	group.name = model_path.get_file().get_basename().capitalize().replace(" ", "")
	add_child(group)
	for part in parts:
		for key in chunks:
			var list: Array = chunks[key]
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = part.mesh
			multimesh.instance_count = list.size()
			for i in list.size():
				multimesh.set_instance_transform(i, (list[i] as Transform3D) * (part.local as Transform3D))
			var holder := MultiMeshInstance3D.new()
			holder.name = "Chunk_%d_%d" % [key.x, key.y]
			holder.multimesh = multimesh
			if material != null:
				holder.material_override = material
			holder.visibility_range_end = visible_range
			holder.visibility_range_end_margin = 20.0
			holder.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			if not shadows:
				holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			group.add_child(holder)
