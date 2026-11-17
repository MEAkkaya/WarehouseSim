class_name WalkingNPC
extends Node3D
## A co-worker walking a loop around the work floor. Purely atmosphere for now (the
## ranking numbers are simulated separately in Career). The visible model is the shared
## employee model (CharacterModel), with a shirt colour that depends on the name.

@export var employee_name: String = "Worker"
@export var walk_speed: float = 1.4

var route: PackedVector3Array = PackedVector3Array()
var _target_index: int = 0
var _pause_left: float = 0.0

## Shirt colours the co-workers wear (picked by name, so a person keeps their shirt).
const SHIRTS: Array[Color] = [Color(0.2, 0.4, 0.75), Color(0.25, 0.55, 0.35), Color(0.8, 0.5, 0.15),
		Color(0.6, 0.3, 0.55), Color(0.3, 0.6, 0.65), Color(0.7, 0.65, 0.3)]

@onready var _label: PaperLabel = $Label
@onready var _model: CharacterModel = $Model


func _ready() -> void:
	_label.set_paper_text(employee_name)
	_model.shirt_color = SHIRTS[absi(employee_name.hash()) % SHIRTS.size()]


func _process(delta: float) -> void:
	if route.is_empty():
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		return
	var target := route[_target_index]
	var to := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var distance := to.length()
	if distance < 0.3:
		_target_index = (_target_index + 1) % route.size()
		_pause_left = randf_range(0.0, 2.5)  # stop and "work" for a moment
		return
	global_position += to.normalized() * minf(walk_speed * delta, distance)
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(6.0 * delta, 0.0, 1.0))
