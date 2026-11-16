class_name Landscape
extends MeshInstance3D
## The scenery OUTSIDE the playable area: mountain ranges that rise beyond the town border
## in some directions (open, low rolling land in the others), so the world does not feel
## flat. It is one small generated mesh, built to be cheap:
##   - it only reaches as far as the mountains are worth seeing (`reach`); the far side of
##     a range is never drawn - the land just sinks below the ground behind the crest,
##   - cells that would be flat are skipped (the town's ground slab is already there),
##   - no collision (the invisible border walls keep you inside), and no shadows.
## Distance fog melts the far peaks into the sky. Green near the town, darker green on the
## slopes, bare rock higher up, snow on the peaks.
##
## Replace it with a real model whenever you have one: delete the "Landscape" node
## (TownBuilder creates it) or tune the exports below.

## The playable area it surrounds (set by TownBuilder).
var inner: Rect2 = Rect2(-60, -95, 420, 395)
## How far the scenery reaches beyond the border, in metres (the crest of the ranges is
## about `ramp_distance` out; the rest is the short back slope that sinks out of sight).
@export var reach: float = 390.0
## Size of one grid cell. Smaller = smoother but more triangles.
@export var cell: float = 32.0
## Height of the tallest peaks, in metres.
@export var max_height: float = 120.0
## Height of the low rolling hills where there are no mountains.
@export var valley_height: float = 12.0
## Distance beyond the border over which the land climbs from flat to full height.
@export var ramp_distance: float = 250.0
## Over the last metres of `reach` the land sinks below the ground (the hidden back side).
@export var back_slope: float = 110.0
@export var noise_seed: int = 11

var _noise := FastNoiseLite.new()
var _base_y: float = TownLayout.GROUND_TOP - 0.05  # a hair under the town's ground, so no flicker


func _ready() -> void:
	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	_noise.frequency = 0.0035
	mesh = _build_mesh()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Distance from `p` to the playable rectangle (0 inside it).
func _distance_outside(p: Vector2) -> float:
	var dx := maxf(maxf(inner.position.x - p.x, p.x - inner.end.x), 0.0)
	var dy := maxf(maxf(inner.position.y - p.y, p.y - inner.end.y), 0.0)
	return Vector2(dx, dy).length()


## 0..1: is there a mountain range in this direction (seen from the middle of the town)?
func mountain_amount(x: float, z: float) -> float:
	var angle := atan2(z - inner.get_center().y, x - inner.get_center().x)
	var m := _noise.get_noise_2d(cos(angle) * 140.0 + 1000.0, sin(angle) * 140.0)
	return smoothstep(-0.12, 0.3, m)


## Terrain height above the town's ground at world (x, z). Negative = hidden below it.
func height_at(x: float, z: float) -> float:
	var d := _distance_outside(Vector2(x, z))
	var ramp := smoothstep(6.0, ramp_distance, d)
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5            # 0..1
	var ridges := 1.0 - absf(_noise.get_noise_2d(x * 1.7 + 300.0, z * 1.7))  # sharp crests
	var peak := lerpf(valley_height, max_height, mountain_amount(x, z))
	var h := ramp * ramp * peak * (0.25 + 0.55 * n * n + 0.35 * ridges * n) + ramp * n * 5.0
	# The back slope: past the crest the land sinks into the ground and is never drawn.
	var sink := smoothstep(reach - back_slope, reach, d)
	return h * (1.0 - sink) - sink * 4.0


func _color_at(height: float, slope: float) -> Color:
	var grass := Color(0.34, 0.52, 0.27)
	var forest := Color(0.22, 0.4, 0.23)
	var rock := Color(0.46, 0.44, 0.42)
	var snow := Color(0.93, 0.94, 0.96)
	var color := grass.lerp(forest, smoothstep(2.0, 30.0, height))
	color = color.lerp(rock, smoothstep(50.0, 80.0, height) + smoothstep(0.55, 0.85, slope) * 0.6)
	return color.lerp(snow, smoothstep(105.0, 130.0, height))


func _build_mesh() -> ArrayMesh:
	var outer := inner.grow(reach)
	var columns := int(outer.size.x / cell)
	var rows := int(outer.size.y / cell)
	var heights := PackedFloat32Array()
	heights.resize((columns + 1) * (rows + 1))
	for j in rows + 1:
		for i in columns + 1:
			heights[j * (columns + 1) + i] = height_at(outer.position.x + i * cell, outer.position.y + j * cell)
	# Only the vertices of cells that are actually drawn become part of the mesh.
	var used := {}   # grid index -> index in the vertex arrays
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for j in rows:
		for i in columns:
			var a := j * (columns + 1) + i
			var corners := [a, a + 1, a + columns + 1, a + columns + 2]
			var rect := Rect2(outer.position.x + i * cell, outer.position.y + j * cell, cell, cell)
			if inner.encloses(rect):
				continue  # under the town: its ground slab is already there
			var highest := -INF
			for corner: int in corners:
				highest = maxf(highest, heights[corner])
			if highest < 0.4:
				continue  # flat or sunk: nothing to see
			for corner: int in corners:
				if not used.has(corner):
					used[corner] = vertices.size()
					var x := outer.position.x + (corner % (columns + 1)) * cell
					var z := outer.position.y + (corner / (columns + 1)) * cell
					var step := cell * 0.5
					var normal := Vector3(height_at(x - step, z) - height_at(x + step, z), 2.0 * step,
							height_at(x, z - step) - height_at(x, z + step)).normalized()
					vertices.append(Vector3(x, _base_y + heights[corner], z))
					normals.append(normal)
					colors.append(_color_at(heights[corner], 1.0 - normal.y))
			indices.append_array([used[corners[0]], used[corners[2]], used[corners[1]],
					used[corners[1]], used[corners[2]], used[corners[3]]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var array_mesh := ArrayMesh.new()
	if not vertices.is_empty():
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh
