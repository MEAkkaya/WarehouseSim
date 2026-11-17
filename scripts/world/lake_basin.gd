class_name LakeBasin
extends Node3D
## Digs the lakes: for every TownLake of the scene it builds the lake bed (a bowl with sloping
## banks, as one mesh with a collider) into a rectangular hole in the ground slab, and puts the
## water (assets/shaders/lake_water.gdshader) at its level below the ground. The bank next to a
## beach lake is sand (the `BeachSand` disc of the scene marks where). The TownLake node itself
## stays the handle you move and scale in the editor.
##
## Everything is derived from `lakes` (see `describe`), and where two lakes' rectangles
## overlap the lower bed wins, so a lake is never covered by the flat ground of its neighbour.

const G := TownLayout.GROUND_TOP
## Size of the grid cells of the lake bed mesh, in metres.
const CELL := 1.5
## How far the water surface lies below the ground.
const EDGE_DEPTH := 0.7
## How much deeper than the surface the bed is in the middle of the lake.
const MAX_DEPTH := 3.0
## The bank slopes up from the water's edge over this many metres.
const BANK := 2.6
## The sand patch lies a hair above the ground (as the sand disc did).
const SAND_LIFT := 0.02

const GRASS := Color(0.36, 0.52, 0.32)
const SAND := Color(0.83, 0.77, 0.57)
const WET_SAND := Color(0.62, 0.55, 0.38)
const MUD := Color(0.36, 0.3, 0.2)
const BED_SHALLOW := Color(0.5, 0.45, 0.33)
const BED_DEEP := Color(0.07, 0.1, 0.12)

## One entry per lake: {center, radius, rmin, has_sand, sand_center, sand_radius}.
var lakes: Array[Dictionary] = []

var _material: StandardMaterial3D = null


## The numbers of one lake. `sand` = the disc that marks the sand patch (or null).
static func describe(lake: TownLake, sand: MeshInstance3D) -> Dictionary:
	var info := {"name": String(lake.name), "center": lake.get_center(), "radius": lake.get_radius(),
			"has_sand": sand != null, "sand_center": Vector2.ZERO, "sand_radius": Vector2.ONE}
	var radius: Vector2 = info.radius
	info["rmin"] = minf(radius.x, radius.y)
	if sand != null:
		info["sand_center"] = Vector2(sand.global_position.x, sand.global_position.z)
		info["sand_radius"] = Vector2(sand.global_transform.basis.x.length(), sand.global_transform.basis.z.length())
	return info


## The surface of the water.
static func water_level() -> float:
	return G - EDGE_DEPTH


## The rectangle cut out of the ground for this lake (lake with its bank, and its sand).
static func hole_rect(info: Dictionary) -> Rect2:
	var radius: Vector2 = info.radius
	var reach := radius * (1.0 + BANK / float(info.rmin)) + Vector2(CELL, CELL)
	var center: Vector2 = info.center
	var rect := Rect2(center - reach, reach * 2.0)
	if info.has_sand:
		var sand_center: Vector2 = info.sand_center
		var sand_radius: Vector2 = info.sand_radius
		rect = rect.merge(Rect2(sand_center - sand_radius, sand_radius * 2.0))
	# whole cells, so the mesh fills the hole exactly
	var cells := Vector2(ceilf(rect.size.x / CELL), ceilf(rect.size.y / CELL))
	return Rect2(rect.position, cells * CELL)


## Builds the bed of lake `index` (mesh + collider) as children of this node.
func build(index: int) -> void:
	var info := lakes[index]
	var rect := hole_rect(info)
	var nx := roundi(rect.size.x / CELL)
	var nz := roundi(rect.size.y / CELL)
	var stride := nx + 1
	var heights := PackedFloat32Array()
	heights.resize(stride * (nz + 1))
	for j in nz + 1:
		for i in nx + 1:
			heights[j * stride + i] = _height(rect.position + Vector2(i, j) * CELL)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for j in nz + 1:
		for i in nx + 1:
			var p := rect.position + Vector2(i, j) * CELL
			var h := heights[j * stride + i]
			vertices.append(Vector3(p.x, h, p.y))
			var h_west := heights[j * stride + maxi(i - 1, 0)]
			var h_east := heights[j * stride + mini(i + 1, nx)]
			var h_north := heights[maxi(j - 1, 0) * stride + i]
			var h_south := heights[mini(j + 1, nz) * stride + i]
			var dx := (h_east - h_west) / (CELL * float(mini(i + 1, nx) - maxi(i - 1, 0)))
			var dz := (h_south - h_north) / (CELL * float(mini(j + 1, nz) - maxi(j - 1, 0)))
			normals.append(Vector3(-dx, 1.0, -dz).normalized())
			colors.append(_color(p, h))
	var indices := PackedInt32Array()
	for j in nz:
		for i in nx:
			var a := j * stride + i
			var b := a + 1
			var c := a + stride
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _get_material())
	var body := StaticBody3D.new()
	body.name = "Bed_%s" % info.name
	add_child(body)
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	body.add_child(instance)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)


func _get_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 1.0
	return _material


func _in_sand(p: Vector2) -> bool:
	for info in lakes:
		if info.has_sand and TownLayout.ellipse_value(p, info.sand_center, info.sand_radius) <= 1.0:
			return true
	return false


## The height of the lake bed / bank / ground at `p`.
func _height(p: Vector2) -> float:
	var level := water_level()
	var flat := G + (SAND_LIFT if _in_sand(p) else 0.0)
	var lowest := INF
	for info in lakes:
		var e := TownLayout.ellipse_value(p, info.center, info.radius)
		var h := INF
		if e <= 1.0:
			h = level - MAX_DEPTH * (1.0 - e * e)
		else:
			var d := (e - 1.0) * float(info.rmin)
			if d < BANK:
				h = lerpf(level, flat, smoothstep(0.0, 1.0, d / BANK))
		lowest = minf(lowest, h)
	return flat if lowest == INF else lowest


func _color(p: Vector2, h: float) -> Color:
	var level := water_level()
	var sandy := _in_sand(p)
	if h >= level:
		var wet := WET_SAND if sandy else MUD
		var top := SAND if sandy else GRASS
		return wet.lerp(top, smoothstep(level, level + 0.45, h))
	var t := smoothstep(0.0, 1.0, (level - h) / MAX_DEPTH * 2.0)
	return BED_SHALLOW.lerp(BED_DEEP, t)
