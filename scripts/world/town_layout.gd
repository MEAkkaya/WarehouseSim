class_name TownLayout
extends RefCounted
## The DATA of the town layout - roads, railway, lakes, fields, zones. Everything
## is in metres: x = east, z = south, origin = the middle of the warehouse. Change
## numbers here to reshape the map; TownBuilder turns them into geometry.
##
## The layout follows an aerial photo: an industrial terrain in the north-west
## (with our warehouse), a dense neighbourhood below it, a railway and a main road
## curving between them, three lakes in the south-east and farmland to the east.

## Top surface of the ground.
const GROUND_TOP := 0.09
## The playable area. Invisible walls close it; fog hides what lies beyond.
const BOUNDS := Rect2(-60, -95, 420, 395)

## Roads as polylines (x, z points) with a width in metres.
static var ROADS: Array[Dictionary] = [
	{"name": "Entrance street", "width": 7.0,
		"points": PackedVector2Array([Vector2(0, 14), Vector2(0, 40), Vector2(0, 130), Vector2(0, 207)])},
	{"name": "Industrial road", "width": 8.0,
		"points": PackedVector2Array([Vector2(-55, 40), Vector2(0, 40), Vector2(70, 40), Vector2(160, 40)])},
	{"name": "Main road", "width": 10.0,
		"points": PackedVector2Array([Vector2(185, -95), Vector2(165, 22), Vector2(134, 112),
				Vector2(118, 166), Vector2(56, 240), Vector2(-9, 277), Vector2(-60, 298)])},
	{"name": "Industrial ring west", "width": 7.0,
		"points": PackedVector2Array([Vector2(-50, -90), Vector2(-50, 40)])},
	{"name": "Industrial ring east", "width": 7.0,
		"points": PackedVector2Array([Vector2(72, -90), Vector2(72, 40)])},
	{"name": "Industrial north", "width": 7.0,
		"points": PackedVector2Array([Vector2(-50, -50), Vector2(72, -50)])},
	{"name": "Lake road", "width": 5.0,
		"points": PackedVector2Array([Vector2(134, 112), Vector2(165, 122), Vector2(190, 128)])},
]

## The railway (a polyline). The station sits on the segment between points 5 and 6.
static var RAIL: PackedVector2Array = PackedVector2Array([
	Vector2(-60, -100), Vector2(-40, -86), Vector2(32, -58), Vector2(90, -9), Vector2(144, 45),
	Vector2(126, 90), Vector2(117, 126), Vector2(77, 203), Vector2(-9, 275), Vector2(-60, 298)])
const RAIL_HALF_WIDTH := 3.0

## Lakes: ellipses. `beach` adds a sand shore.
const LAKES: Array[Dictionary] = [
	{"name": "Beach lake", "center": Vector2(191, 132), "radius": Vector2(36, 26), "beach": true},
	{"name": "West lake", "center": Vector2(157, 205), "radius": Vector2(50, 40), "beach": false},
	{"name": "South lake", "center": Vector2(236, 232), "radius": Vector2(47, 54), "beach": false},
]

## Farmland patches (flat coloured rectangles).
const FIELDS: Array[Dictionary] = [
	{"rect": Rect2(200, -30, 100, 70), "color": Color(0.33, 0.55, 0.25)},
	{"rect": Rect2(200, 45, 90, 45), "color": Color(0.42, 0.6, 0.28)},
	{"rect": Rect2(300, -30, 55, 120), "color": Color(0.3, 0.5, 0.24)},
	{"rect": Rect2(295, 100, 60, 80), "color": Color(0.5, 0.58, 0.3)},
	{"rect": Rect2(200, -92, 150, 55), "color": Color(0.38, 0.57, 0.27)},
	{"rect": Rect2(-58, 218, 52, 70), "color": Color(0.36, 0.54, 0.26)},
]

## Zones the builders fill.
const INDUSTRIAL := Rect2(-58, -92, 135, 150)
const NEIGHBOURHOOD := Rect2(-32, 88, 135, 125)
## Woods (random trees): between the neighbourhood and the lakes and north of them.
const WOODS: Array[Rect2] = [Rect2(104, 118, 40, 110), Rect2(150, 70, 70, 36), Rect2(100, 230, 60, 55)]

## The two special apartment buildings (centre of the footprint, front faces south).
## The club's back door is on its north side, in a yard where no house stands.
const GAMBLING_SPOT := Vector2(42, 130)
const CLUB_SPOT := Vector2(60, 130)


## Holes in the town's ground slab (x, z): the stair shaft down to the night club.
static func ground_holes() -> Array[Rect2]:
	return [Rect2(CLUB_SPOT.x + 2.5, CLUB_SPOT.y - 2.6, 1.7, 5.8)]


## Places nothing else may be built on: the warehouse building with its apron, the
## truck yard, the station, the shopping street.
const KEEP_OUT: Array[Rect2] = [
	Rect2(-30, -30, 100, 66),   # the warehouse complex, its plaza, parking and loading yard
	Rect2(70, -30, 6, 50),      # a buffer east of the extra stock room
	Rect2(86, 86, 44, 44),
	Rect2(-17, 88, 34, 46),
	Rect2(18, 90, 16, 14),
]

# Sample points along roads/rail for fast "is this rectangle on a road?" checks.
static var _road_samples: Array = []


## Shortest distance from `p` to a polyline.
static func distance_to_polyline(p: Vector2, points: PackedVector2Array) -> float:
	var best := INF
	for i in points.size() - 1:
		var a := points[i]
		var ab := points[i + 1] - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
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
