class_name TownLayout
extends RefCounted
## The town's layout as DATA the game's scripts read (sidewalk placing, house placing, the
## map). Since the world is ONE scene (scenes/levels/world.tscn), the roads, the railway,
## the lakes, the fields, the ground and the buildings are ordinary nodes under `Town` that
## you move in the editor; `scan()` reads them into the lists below when the game starts.
## What is still a number here: the playable area, and the two zones the generator fills
## (neighbourhood, woods). Everything is in metres: x = east, z = south, origin = the
## middle of the warehouse.

## Top surface of the ground.
const GROUND_TOP := 0.09
## The playable area. Invisible walls close it; fog hides what lies beyond.
const BOUNDS := Rect2(-60, -95, 420, 395)

## The zone the generator fills with houses and apartment blocks (on a lattice, skipping
## everything that is in the way: roads, lakes, your buildings).
const NEIGHBOURHOOD := Rect2(-32, 88, 135, 125)
## Woods (random trees): between the neighbourhood and the lakes and north of them.
const WOODS: Array[Rect2] = [Rect2(104, 118, 40, 110), Rect2(150, 70, 70, 36), Rect2(100, 230, 60, 55)]

## The two special apartment buildings (centre of the footprint, front faces south).
## The club's back door is on its north side, in a yard where no house stands.
## (Read from the nodes Town/Buildings/GamblingApartment and ClubApartment.)
static var GAMBLING_SPOT := Vector2(42, 130)
static var CLUB_SPOT := Vector2(60, 130)
## Where the train waits (the node Town/Buildings/Station).
static var STATION_SPOT := Vector2(121.5, 108)

## ---- Filled by scan() from the nodes of the scene ----------------------------------
## Roads: {name, width, points (PackedVector2Array), lift, lamps, poles, parking, center_line} (TownRoad nodes of kind ROAD).
static var ROADS: Array[Dictionary] = []
## The tunnel portals (the nodes under Town/Tunnels): {spot (x, z of the portal), dir (x, z, the way
## the tunnel runs, away from the town)}.
static var TUNNELS: Array[Dictionary] = []
## The railway line (the TownRoad of kind RAIL).
static var RAIL: PackedVector2Array = PackedVector2Array()
const RAIL_HALF_WIDTH := 3.0
## Lakes (TownLake nodes): {name, center, radius, beach}.
static var LAKES: Array[Dictionary] = []
## Farmland patches (the boxes under Town/Fields): {rect, color}.
static var FIELDS: Array[Dictionary] = []
## The paved industrial area (the node Town/IndustrialPaving).
static var INDUSTRIAL := Rect2(-58, -92, 135, 150)

## Places nothing else may be built on: the warehouse building with its apron, the
## truck yard, the station, the shopping street.
const KEEP_OUT: Array[Rect2] = [
	Rect2(-30, -40, 112, 76),   # the warehouse complex, its plaza, parking and loading yard
	Rect2(76, -40, 6, 60),      # a buffer east of the extra stock room
	Rect2(86, 86, 44, 44),
	Rect2(-17, 88, 34, 46),
	Rect2(18, 90, 16, 14),
]

# Sample points along roads/rail for fast "is this rectangle on a road?" checks.
static var _road_samples: Array = []


## Reads the roads, rail, lakes, fields... from the nodes under `town` (the `Town` node of
## world.tscn). Call it once at game start, before anything is built.
static func scan(town: Node) -> void:
	_road_samples.clear()
	ROADS.clear()
	RAIL = PackedVector2Array()
	LAKES.clear()
	FIELDS.clear()
	TUNNELS.clear()
	var tunnels := town.get_node_or_null("Tunnels")
	if tunnels != null:
		for node in tunnels.get_children():
			var tunnel := node as Node3D
			if tunnel != null:
				var forward := -tunnel.global_transform.basis.z   # a tunnel runs along its local -Z
				TUNNELS.append({"spot": Vector2(tunnel.global_position.x, tunnel.global_position.z),
						"dir": Vector2(forward.x, forward.z).normalized()})
	var roads := town.get_node_or_null("Roads")
	if roads != null:
		for node in roads.get_children():
			var road := node as TownRoad
			if road == null:
				continue
			var line := road.get_line()
			if line.size() < 2:
				continue
			if road.kind == TownRoad.Kind.RAIL:
				if RAIL.is_empty():
					RAIL = line
			else:
				ROADS.append({"name": String(road.name), "width": road.width, "points": line, "lift": road.lift,
						"lamps": road.street_lamps, "poles": road.utility_poles, "parking": road.parking,
						"center_line": road.center_line})
	var lakes := town.get_node_or_null("Lakes")
	if lakes != null:
		for node in lakes.get_children():
			var lake := node as TownLake
			if lake != null:
				LAKES.append({"name": String(lake.name), "center": lake.get_center(),
						"radius": lake.get_radius(), "beach": lake.beach})
	var fields := town.get_node_or_null("Fields")
	if fields != null:
		for node in fields.get_children():
			var field := node as MeshInstance3D
			if field != null and field.mesh != null:
				var color := Color(0.4, 0.55, 0.3)
				if field.mesh.material is StandardMaterial3D:
					color = (field.mesh.material as StandardMaterial3D).albedo_color
				FIELDS.append({"rect": footprint(field), "color": color})
	var paving := town.get_node_or_null("IndustrialPaving") as MeshInstance3D
	if paving != null and paving.mesh != null:
		INDUSTRIAL = footprint(paving)
	var gambling := town.get_node_or_null("Buildings/GamblingApartment") as Node3D
	if gambling != null:
		GAMBLING_SPOT = Vector2(gambling.global_position.x, gambling.global_position.z)
	var club := town.get_node_or_null("Buildings/ClubApartment") as Node3D
	if club != null:
		CLUB_SPOT = Vector2(club.global_position.x, club.global_position.z)
	var station := town.get_node_or_null("Buildings/Station") as Node3D
	if station != null:
		STATION_SPOT = Vector2(station.global_position.x, station.global_position.z)


## The ground rectangle (x, z) a mesh node covers (axis-aligned, rotation included).
static func footprint(node: MeshInstance3D) -> Rect2:
	var box := node.global_transform * node.get_aabb()
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)


## Holes in the town's ground slab (x, z): the stair shaft down to the night club.
static func ground_holes() -> Array[Rect2]:
	return [Rect2(CLUB_SPOT.x + 2.5, CLUB_SPOT.y - 2.6, 1.7, 5.8)]


## Shortest distance from `p` to a polyline.
static func distance_to_polyline(p: Vector2, points: PackedVector2Array) -> float:
	var best := INF
	for i in points.size() - 1:
		var a := points[i]
		var ab := points[i + 1] - a
		var length_squared := ab.length_squared()
		if length_squared < 0.000001:
			best = minf(best, p.distance_to(a))
			continue
		var t := clampf((p - a).dot(ab) / length_squared, 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## < 1 inside the ellipse, 1 on its edge, > 1 outside.
static func ellipse_value(p: Vector2, center: Vector2, radius: Vector2) -> float:
	return ((p - center) / radius).length()


## Is `rect` free of roads, the railway, lakes and keep-out areas (all with a margin)?
static func rect_is_clear(rect: Rect2, margin: float) -> bool:
	if not BOUNDS.grow(-margin).encloses(rect):
		return false
	for keep in KEEP_OUT:
		if keep.grow(margin).intersects(rect):
			return false
	for sample in _get_road_samples():
		if rect.grow(sample.half + margin).has_point(sample.point):
			return false
	var corners: Array[Vector2] = [rect.position, rect.position + Vector2(rect.size.x, 0),
			rect.position + Vector2(0, rect.size.y), rect.end, rect.get_center()]
	for lake in LAKES:
		var radius: Vector2 = lake.radius
		var limit := 1.0 + margin / minf(radius.x, radius.y)
		for corner in corners:
			if ellipse_value(corner, lake.center, radius) < limit:
				return false
	return true


static func _get_road_samples() -> Array:
	if not _road_samples.is_empty():
		return _road_samples
	for road in ROADS:
		_sample_polyline(road.points, road.width / 2.0)
	_sample_polyline(RAIL, RAIL_HALF_WIDTH)
	return _road_samples


static func _sample_polyline(points: PackedVector2Array, half_width: float) -> void:
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var steps := maxi(1, int(a.distance_to(b) / 3.0))
		for s in steps + 1:
			_road_samples.append({"point": a.lerp(b, float(s) / steps), "half": half_width})
