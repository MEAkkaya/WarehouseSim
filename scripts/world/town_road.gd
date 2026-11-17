@tool
class_name TownRoad
extends Path3D
## A road or a railway you can see and edit in the editor: a Path3D (drag its points in the
## 3D view, add points with Ctrl+click) that draws a flat strip along the line, `width`
## metres wide. Only the x/z of the points count (the strip lies on the ground: put the node
## at the ground's height, y = 0.09, with the points at y = 0).
##
## The game reads these nodes at start (TownLayout.scan): the neighbourhood's houses keep
## off them, the sidewalks are laid along them, the map draws them.
##
## A `@tool` script, so the strip also shows in the editor. Keep it free of anything that
## needs the game (autoloads and so on).

enum Kind { ROAD, RAIL }

@export var kind: Kind = Kind.ROAD:
	set(value):
		kind = value
		_refresh()
## Width of the strip in metres (the ballast bed for a railway).
@export var width: float = 7.0:
	set(value):
		width = value
		_refresh()
## How far the road's top lies above the ground (so crossing roads do not flicker).
@export var lift: float = 0.012:
	set(value):
		lift = value
		_refresh()

## What the game adds along this road (StreetFurniture; they show only in the game).
## Street lamps, alternating sides.
@export var street_lamps: bool = true
## Utility poles with cables between them (one side of the road).
@export var utility_poles: bool = false
## A dashed line down the middle.
@export var center_line: bool = true
## Painted parking bays at the edge of the road (left / right when walking along the road
## from its first point to its last).
@export_enum("None", "Left", "Right", "Both") var parking: int = 0

const ROAD_COLOR := Color(0.27, 0.27, 0.3)
const BALLAST_COLOR := Color(0.42, 0.4, 0.38)
const STEEL_COLOR := Color(0.12, 0.12, 0.14)

static var _unit_box: BoxMesh = null
static var _materials: Dictionary = {}

var _pieces: Node3D = null


func _ready() -> void:
	curve_changed.connect(_refresh)
	_refresh()


## The line in world x/z (the points of the Path3D).
func get_line() -> PackedVector2Array:
	var line := PackedVector2Array()
	if curve == null:
		return line
	for i in curve.point_count:
		var p := global_transform * curve.get_point_position(i)
		line.append(Vector2(p.x, p.z))
	return line


func _refresh() -> void:
	if not is_node_ready():
		return
	if _pieces != null:
		remove_child(_pieces)
		_pieces.queue_free()
	_pieces = Node3D.new()
	_pieces.name = "Strip"
	add_child(_pieces, false, Node.INTERNAL_MODE_BACK)   # not owned: never saved in the scene
	if curve == null or curve.point_count < 2:
		return
	for i in curve.point_count - 1:
		var a := curve.get_point_position(i)
		var b := curve.get_point_position(i + 1)
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var yaw := atan2(-(b2.y - a2.y), b2.x - a2.x)
		var middle := (a2 + b2) / 2.0
		var length := a2.distance_to(b2)
		if kind == Kind.ROAD:
			# (a piece sticks out half a width at both ends, so bends and ends are closed)
			_piece(Vector3(middle.x, lift - 0.1, middle.y), Vector3(length + width, 0.2, width), yaw, ROAD_COLOR)
		else:
			var bed := length + 3.0
			_piece(Vector3(middle.x, 0.05, middle.y), Vector3(bed, 0.3, width), yaw, BALLAST_COLOR)
			for side: float in [-0.72, 0.72]:
				var offset := Vector2(-sin(yaw), -cos(yaw)) * side
				_piece(Vector3(middle.x + offset.x, 0.28, middle.y + offset.y), Vector3(bed, 0.14, 0.14), yaw, STEEL_COLOR)


func _piece(at: Vector3, size: Vector3, yaw: float, color: Color) -> void:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
		_unit_box.size = Vector3.ONE
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		_materials[color] = material
	var piece := MeshInstance3D.new()
	piece.mesh = _unit_box
	piece.material_override = _materials[color]
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.scale = size
	piece.position = at
	piece.rotation.y = yaw
	_pieces.add_child(piece)
