class_name ApartmentKit
extends RefCounted
## Grey-box building blocks for the apartment buildings (walls with door gaps, floors
## with holes, stairs, signs, lights). Everything is built from boxes in code, so a
## real model can later replace a whole building by deleting its script.
##
## All positions are LOCAL to the `parent` node you pass in (the building).

static var _materials: Dictionary = {}


static func material(color: Color, emissive: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%s" % [color.to_html(), emissive]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = emissive
		_materials[key] = m
	return _materials[key]


## A box (a solid StaticBody3D, or just a mesh when `collide` is false).
static func box(parent: Node3D, center: Vector3, size: Vector3, color: Color,
		collide: bool = true, emissive: float = 0.0) -> Node3D:
	var holder: Node3D
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		holder = body
	else:
		holder = Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material(color, emissive)
	mesh_instance.mesh = mesh
	holder.add_child(mesh_instance)
	holder.position = center
	parent.add_child(holder)
	return holder


## Gives an Interactable (any StaticBody3D) a visible, solid box. Its feet are at the
## body's origin.
static func body_box(body: StaticBody3D, size: Vector3, color: Color, emissive: float = 0.0) -> void:
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = Vector3(0, size.y / 2.0, 0)
	body.add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material(color, emissive)
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0, size.y / 2.0, 0)
	body.add_child(mesh_instance)


static func label(parent: Node3D, text: String, at: Vector3, pixel_size: float = 0.012,
		color: Color = Color.WHITE, billboard: bool = false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = pixel_size
	l.font_size = 56
	l.outline_size = 12
	l.modulate = color
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = at
	parent.add_child(l)
	return l


static func light(parent: Node3D, at: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.position = at
	parent.add_child(l)
	return l


## A wall along X (constant z) from x0 to x1, with gaps: each gap is [xa, xb, top_y]
## (a doorway from the wall's bottom up to top_y).
static func wall_x(parent: Node3D, z: float, x0: float, x1: float, y0: float, y1: float,
		thickness: float, color: Color, gaps: Array = []) -> void:
	_wall(parent, false, z, x0, x1, y0, y1, thickness, color, gaps)


## A wall along Z (constant x) from z0 to z1.
static func wall_z(parent: Node3D, x: float, z0: float, z1: float, y0: float, y1: float,
		thickness: float, color: Color, gaps: Array = []) -> void:
	_wall(parent, true, x, z0, z1, y0, y1, thickness, color, gaps)


static func _wall(parent: Node3D, along_z: bool, fixed: float, t0: float, t1: float,
		y0: float, y1: float, thickness: float, color: Color, gaps: Array) -> void:
	var sorted := gaps.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var cursor := t0
	for gap: Array in sorted:
		_wall_piece(parent, along_z, fixed, cursor, gap[0], y0, y1, thickness, color)
		if gap[2] < y1:  # the header above the doorway
			_wall_piece(parent, along_z, fixed, gap[0], gap[1], gap[2], y1, thickness, color)
		cursor = gap[1]
	_wall_piece(parent, along_z, fixed, cursor, t1, y0, y1, thickness, color)


static func _wall_piece(parent: Node3D, along_z: bool, fixed: float, t0: float, t1: float,
		y0: float, y1: float, thickness: float, color: Color) -> void:
	if t1 - t0 < 0.01 or y1 - y0 < 0.01:
		return
	var mid := (t0 + t1) / 2.0
	var length := t1 - t0
	if along_z:
		box(parent, Vector3(fixed, (y0 + y1) / 2.0, mid), Vector3(thickness, y1 - y0, length), color)
	else:
		box(parent, Vector3(mid, (y0 + y1) / 2.0, fixed), Vector3(length, y1 - y0, thickness), color)


## A floor slab whose top is at `y_top`, covering x0..x1 and z0..z1 except `hole`
## (a Rect2 in x/z; leave it empty for no hole).
static func slab(parent: Node3D, y_top: float, thickness: float, x0: float, x1: float,
		z0: float, z1: float, color: Color, hole: Rect2 = Rect2()) -> void:
	var y := y_top - thickness / 2.0
	if hole.size == Vector2.ZERO:
		box(parent, Vector3((x0 + x1) / 2.0, y, (z0 + z1) / 2.0), Vector3(x1 - x0, thickness, z1 - z0), color)
		return
	var pieces: Array[Rect2] = [
		Rect2(x0, z0, hole.position.x - x0, z1 - z0),                                   # west of the hole
		Rect2(hole.end.x, z0, x1 - hole.end.x, z1 - z0),                                # east of it
		Rect2(hole.position.x, z0, hole.size.x, hole.position.y - z0),                  # north of it
		Rect2(hole.position.x, hole.end.y, hole.size.x, z1 - hole.end.y),               # south of it
	]
	for piece in pieces:
		if piece.size.x > 0.01 and piece.size.y > 0.01:
			box(parent, Vector3(piece.get_center().x, y, piece.get_center().y),
					Vector3(piece.size.x, thickness, piece.size.y), color)


## A straight staircase between two points (a = one end, b = the other; either can be
## the higher one). The walking surface is a solid wedge, the steps are only drawn.
static func stairs(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var lo := a if a.y < b.y else b
	var hi := b if a.y < b.y else a
	var rise := hi.y - lo.y
	var flat := Vector3(hi.x - lo.x, 0.0, hi.z - lo.z)
	var run := flat.length()
	var dir := flat / run
	var side := dir.cross(Vector3.UP) * (width / 2.0)
	# Solid wedge: the triangle (lo, hi, below hi), widened by `side` both ways.
	var below_hi := Vector3(hi.x, lo.y, hi.z)
	var points := PackedVector3Array()
	for corner in [lo, hi, below_hi]:
		points.append(corner + side)
		points.append(corner - side)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = points
	shape.shape = wedge
	body.add_child(shape)
	parent.add_child(body)
	# The visible steps.
	var count := ceili(rise / 0.2)
	for k in count:
		var top := lo.y + rise * (k + 0.5) / count
		var along := run * (k + 0.5) / count
		var center_xz := Vector3(lo.x, 0.0, lo.z) + dir * along
		var step := box(parent, Vector3(center_xz.x, (lo.y + top) / 2.0, center_xz.z),
				Vector3(width, top - lo.y, run / count), color, false)
		step.basis = Basis.looking_at(dir, Vector3.UP)
