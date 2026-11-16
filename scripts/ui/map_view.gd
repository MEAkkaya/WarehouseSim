class_name MapView
extends Control
## The navigation app's map: draws the whole town from the data in TownLayout
## (roads, railway, lakes, fields, zones, the warehouse) and the player's position
## and heading on top. North is up. It redraws every frame while it is visible.

## Whose position to show.
var player: Node3D = null

const GROUND_COLOR := Color(0.36, 0.52, 0.32)
const ROAD_COLOR := Color(0.86, 0.86, 0.88)
const LABEL_COLOR := Color.WHITE


func _ready() -> void:
	custom_minimum_size = Vector2(222, 214)
	clip_contents = true


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


# World (x, z) metres -> pixel in this control; the map keeps its proportions.
func _scale() -> float:
	var bounds := TownLayout.BOUNDS
	return minf(size.x / bounds.size.x, size.y / bounds.size.y)


func _to_map(p: Vector2) -> Vector2:
	var bounds := TownLayout.BOUNDS
	var s := _scale()
	return (size - bounds.size * s) / 2.0 + (p - bounds.position) * s


func _rect_to_map(rect: Rect2) -> Rect2:
	return Rect2(_to_map(rect.position), rect.size * _scale())


func _polyline_to_map(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(_to_map(p))
	return out


func _ellipse_to_map(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 36:
		var angle := TAU * k / 36.0
		out.append(_to_map(center + Vector2(cos(angle), sin(angle)) * radius))
	return out


func _draw() -> void:
	var s := _scale()
	# Ground and zones
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.3, 0.2))
	draw_rect(_rect_to_map(TownLayout.BOUNDS), GROUND_COLOR)
	for field in TownLayout.FIELDS:
		draw_rect(_rect_to_map(field.rect), field.color)
	draw_rect(_rect_to_map(TownLayout.INDUSTRIAL), Color(0.52, 0.52, 0.55))
	draw_rect(_rect_to_map(TownLayout.NEIGHBOURHOOD), Color(0.78, 0.7, 0.58, 0.8))
	# Lakes (the beach lake gets a sand rim)
	for lake in TownLayout.LAKES:
		if lake.beach:
			draw_colored_polygon(_ellipse_to_map(lake.center - Vector2(0, 6), lake.radius + Vector2(9, 9)), Color(0.83, 0.77, 0.57))
		draw_colored_polygon(_ellipse_to_map(lake.center, lake.radius), Color(0.2, 0.36, 0.62))
	# Roads and the railway
	for road in TownLayout.ROADS:
		draw_polyline(_polyline_to_map(road.points), ROAD_COLOR, maxf(road.width * s, 1.6), true)
	draw_polyline(_polyline_to_map(TownLayout.RAIL), Color(0.12, 0.12, 0.14), 2.2, true)
	draw_polyline(_polyline_to_map(TownLayout.RAIL), Color(0.9, 0.9, 0.9), 0.8, true)
	# Places
	draw_rect(_rect_to_map(Rect2(-10, -21, 60, 31)), Color(0.15, 0.3, 0.75))
	draw_rect(_rect_to_map(Rect2(46, -19, 20, 23)), Color(0.15, 0.3, 0.75))
	draw_circle(_to_map(Vector2(0, 12)), 3.0, Color(1.0, 0.85, 0.2))
	_label("Warehouse", Vector2(0, -34))
	# The two shady venues (opening hours: see the Places app).
	draw_circle(_to_map(TownLayout.GAMBLING_SPOT), 2.6, Color(1.0, 0.25, 0.3))
	draw_circle(_to_map(TownLayout.CLUB_SPOT), 2.6, Color(1.0, 0.3, 0.9))
	_label("Industrial", Vector2(30, -80))
	_label("Neighbourhood", Vector2(36, 150))
	var rail := TownLayout.RAIL
	_label("Station", (rail[5] + rail[6]) / 2.0 + Vector2(-12, -6))
	_label("Lakes", Vector2(195, 175))
	_label("Farmland", Vector2(250, 20))
	# North marker
	_text("N", Vector2(size.x - 14, 14), Color.WHITE)
	# You
	if player != null:
		_draw_player()


func _draw_player() -> void:
	var at := _to_map(Vector2(player.global_position.x, player.global_position.z))
	var yaw := player.global_rotation.y
	# Facing -Z (north) at yaw 0.
	var direction := Vector2(-sin(yaw), -cos(yaw))
	var tip := at + direction * 8.0
	var left := at + direction.rotated(2.5) * 6.0
	var right := at + direction.rotated(-2.5) * 6.0
	draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(0.95, 0.15, 0.15))
	draw_polyline(PackedVector2Array([tip, left, right, tip]), Color.WHITE, 1.2, true)


func _label(text: String, world: Vector2) -> void:
	var at := _to_map(world)
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	_text(text, at - Vector2(width / 2.0, 0), LABEL_COLOR)


func _text(text: String, at: Vector2, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
