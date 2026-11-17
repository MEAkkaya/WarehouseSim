class_name Landscape
extends MeshInstance3D
## The scenery OUTSIDE the playable area: a sheer cliff wall round the whole town with a forested
## plateau on top (HillForest plants the trees), and mountain ranges further out in some
## directions (open, low rolling land in the others). The cliff is the town's sharp border: it
## starts a metre or two behind the invisible walls and rises about 30-50 m within a few metres,
## with a meandering lip and rock strata painted on the face. The tunnels are cut into it.
##
## It is one generated mesh, built to be cheap:
##   - a RING of vertices round the border: closely spaced rows where the cliff is (so the face
##     is really steep), further and further apart out to the mountains (`reach`),
##   - quads that would be flat are skipped (the town's ground slab is already there),
##   - no collision (the invisible border walls keep you inside), and no shadows.
## Distance fog melts the far peaks into the sky. Green near the town, dark green on the
## plateau, bare rock on the cliff face and high up, snow on the peaks.
##
## Replace it with a real model whenever you have one: delete the "Landscape" node
## (TownBuilder creates it) or tune the exports below.

## The terrain's zero height: a hair under the town's ground, so no flicker.
const BASE_Y := TownLayout.GROUND_TOP - 0.05
## Distances (metres beyond the border) of the rings of vertices: close together at the cliff.
const ROW_DISTANCES: Array[float] = [0.0, 0.75, 1.5, 2.25, 3.0, 3.75, 4.5, 5.25, 6.0, 6.75, 7.5, 8.25, 9.0, 10.0, 11.0,
		12.0, 14.0, 16.0, 18.0, 21.0, 24.0, 28.0, 32.0, 37.0, 43.0, 50.0, 58.0, 67.0, 77.0, 88.0, 100.0, 113.0, 127.0,
		142.0, 158.0, 175.0, 193.0, 212.0, 232.0, 253.0, 275.0, 298.0, 322.0, 347.0, 372.0]

## The playable area it surrounds (set by TownBuilder).
var inner: Rect2 = Rect2(-60, -95, 420, 395)
## How far the scenery reaches beyond the border, in metres (the crest of the ranges is
## about `ramp_distance` out; the rest is the short back slope that sinks out of sight).
@export var reach: float = 390.0
## Distance between the vertices along the border, in metres.
@export var edge_spacing: float = 4.0
## Height of the tallest peaks, in metres.
@export var max_height: float = 170.0
## Height of the low rolling hills where there are no mountains.
@export var valley_height: float = 12.0
## Distance beyond the border over which the land climbs from flat to full height.
@export var ramp_distance: float = 250.0
## Over the last metres of `reach` the land sinks below the ground (the hidden back side).
@export var back_slope: float = 110.0
@export var noise_seed: int = 11
@export_group("Cliff")
## Height of the plateau on top of the cliff (varies from 70% to 100% of this), in metres.
@export var cliff_height: float = 46.0
## Where the cliff face starts, metres beyond the border (it meanders by `cliff_jitter`)...
@export var cliff_start: float = 1.5
@export var cliff_jitter: float = 2.5
## ...and over how many metres it rises (smaller = steeper).
@export var cliff_width: float = 5.0
## The plateau falls away gently from this far behind the cliff to `plateau_end`.
@export var plateau_end: float = 170.0

var _noise := FastNoiseLite.new()
var _cliff_noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	_noise.frequency = 0.0035
	_cliff_noise.seed = noise_seed + 5
	_cliff_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_cliff_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_cliff_noise.fractal_octaves = 3
	_cliff_noise.frequency = 0.012
	mesh = _build_mesh()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Distance from `p` to the playable rectangle (0 inside it).
func distance_outside(p: Vector2) -> float:
	var dx := maxf(maxf(inner.position.x - p.x, p.x - inner.end.x), 0.0)
	var dy := maxf(maxf(inner.position.y - p.y, p.y - inner.end.y), 0.0)
	return Vector2(dx, dy).length()


## 0..1: is there a mountain range in this direction (seen from the middle of the town)?
func mountain_amount(x: float, z: float) -> float:
	var angle := atan2(z - inner.get_center().y, x - inner.get_center().x)
	var m := _noise.get_noise_2d(cos(angle) * 140.0 + 1000.0, sin(angle) * 140.0)
	return smoothstep(-0.3, 0.12, m)


## Terrain height above the town's ground at world (x, z). Negative = hidden below it.
func height_at(x: float, z: float) -> float:
	var d := distance_outside(Vector2(x, z))
	var ramp := smoothstep(6.0, ramp_distance, d)
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5            # 0..1
	var ridges := 1.0 - absf(_noise.get_noise_2d(x * 1.7 + 300.0, z * 1.7))  # sharp crests
	var peak := lerpf(valley_height, max_height, mountain_amount(x, z))
	var h := ramp * ramp * peak * (0.25 + 0.55 * n * n + 0.35 * ridges * n) + ramp * n * 5.0
	h = maxf(h, _cliff(x, z, d))
	# The back slope: past the crest the land sinks into the ground and is never drawn.
	var sink := smoothstep(reach - back_slope, reach, d)
	return h * (1.0 - sink) - sink * 4.0


## The cliff and the plateau on top of it: 0 at the border, then a steep face, then a plateau
## that rolls a little and falls away gently far behind the cliff.
func _cliff(x: float, z: float, d: float) -> float:
	var edge := cliff_start + _cliff_noise.get_noise_2d(x * 2.5, z * 2.5) * cliff_jitter   # the lip meanders
	var face := smoothstep(edge, edge + cliff_width, d)
	if face <= 0.0:
		return 0.0
	var n := _cliff_noise.get_noise_2d(x, z) * 0.5 + 0.5
	var top := cliff_height * (0.7 + 0.3 * n)
	var rolling := 1.0 + 0.12 * _noise.get_noise_2d(x * 3.0, z * 3.0)
	var back := 1.0 - smoothstep(plateau_end - 90.0, plateau_end, d)
	return top * rolling * face * back


func _color_at(height: float, slope: float, x: float, z: float) -> Color:
	var grass := Color(0.34, 0.52, 0.27)
	var forest := Color(0.16, 0.32, 0.18)
	var rock := Color(0.4, 0.36, 0.32)
	var snow := Color(0.93, 0.94, 0.96)
	var color := grass.lerp(forest, smoothstep(0.5, 7.0, height))
	var steep := smoothstep(0.45, 0.75, slope)
	# rock: horizontal strata, vertical streaks along the wall, darker at the foot
	var strata := 0.84 + 0.16 * sin(height * 2.1 + _cliff_noise.get_noise_2d(x * 4.0, z * 4.0) * 7.0)
	var streaks := 0.82 + 0.36 * (_cliff_noise.get_noise_2d(x * 1.6 + 70.0, z * 1.6) * 0.5 + 0.5)
	var foot := 0.7 + 0.3 * smoothstep(0.0, 14.0, height)
	var tone := strata * streaks * foot
	color = color.lerp(Color(rock.r * tone, rock.g * tone, rock.b * tone, 1.0), clampf(steep + smoothstep(70.0, 110.0, height), 0.0, 1.0))
	return color.lerp(snow, smoothstep(140.0, 175.0, height))


# ---- The mesh -----------------------------------------------------------------------------

## The columns of the ring: {base (a point on the border), normal (pointing away from the town)}.
func _ring_columns() -> Array[Dictionary]:
	var columns: Array[Dictionary] = []
	var x0 := inner.position.x
	var z0 := inner.position.y
	var x1 := inner.end.x
	var z1 := inner.end.y
	var corner_steps := 8
	# clockwise from the north-west corner: north edge, NE corner, east edge, SE corner...
	var edges := [
		[Vector2(x0, z0), Vector2(x1, z0), Vector2(0, -1)],
		[Vector2(x1, z0), Vector2(x1, z1), Vector2(1, 0)],
		[Vector2(x1, z1), Vector2(x0, z1), Vector2(0, 1)],
		[Vector2(x0, z1), Vector2(x0, z0), Vector2(-1, 0)],
	]
	for k in 4:
		var a: Vector2 = edges[k][0]
		var b: Vector2 = edges[k][1]
		var normal: Vector2 = edges[k][2]
		var count := maxi(1, roundi(a.distance_to(b) / edge_spacing))
		for i in count:
			columns.append({"base": a.lerp(b, float(i) / count), "normal": normal})
		# the corner at `b`: the normal turns to the next edge's normal
		var next_normal: Vector2 = edges[(k + 1) % 4][2]
		var from_angle := normal.angle()
		var to_angle := next_normal.angle()
		var delta := wrapf(to_angle - from_angle, -PI, PI)
		for s in range(0, corner_steps):
			columns.append({"base": b, "normal": Vector2.from_angle(from_angle + delta * float(s) / corner_steps)})
	return columns


func _build_mesh() -> ArrayMesh:
	var columns := _ring_columns()
	var column_count := columns.size()
	var row_count := ROW_DISTANCES.size()
	var heights := PackedFloat32Array()
	heights.resize(column_count * row_count)
	var points: Array[Vector2] = []
	points.resize(column_count * row_count)
	for c in column_count:
		for r in row_count:
			var p: Vector2 = (columns[c].base as Vector2) + (columns[c].normal as Vector2) * ROW_DISTANCES[r]
			points[c * row_count + r] = p
			heights[c * row_count + r] = height_at(p.x, p.y)
	# Only the vertices of quads that are actually drawn become part of the mesh.
	var used := {}
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for c in column_count:
		var next := (c + 1) % column_count
		for r in row_count - 1:
			var corner_ids := [c * row_count + r, next * row_count + r, c * row_count + r + 1, next * row_count + r + 1]
			var highest := -INF
			for id: int in corner_ids:
				highest = maxf(highest, heights[id])
			if highest < 0.3:
				continue  # flat or sunk: nothing to see
			for id: int in corner_ids:
				if not used.has(id):
					used[id] = vertices.size()
					var p := points[id]
					var d := distance_outside(p)
					var step := 1.0 if d < 14.0 else 4.0
					var normal := Vector3(height_at(p.x - step, p.y) - height_at(p.x + step, p.y), 2.0 * step,
							height_at(p.x, p.y - step) - height_at(p.x, p.y + step)).normalized()
					vertices.append(Vector3(p.x, BASE_Y + heights[id], p.y))
					normals.append(normal)
					colors.append(_color_at(heights[id], 1.0 - normal.y, p.x, p.y))
			# (clockwise seen from above: Godot's front side)
			indices.append_array([used[corner_ids[0]], used[corner_ids[2]], used[corner_ids[1]],
					used[corner_ids[1]], used[corner_ids[2]], used[corner_ids[3]]])
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
