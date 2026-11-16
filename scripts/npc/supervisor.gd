class_name Supervisor
extends Node3D
## A supervisor: walks a patrol route through the warehouse and watches the player.
## He only sees you inside a view cone, within `view_distance`, with nothing in the
## way (shelves and walls block his sight - that is what makes blind spots).
##
## What he does:
##   - If you break a rule (phone, smoking, gambling, snacking) in his sight for a
##     moment, he reports it: you are caught.
##   - When the heat is high (big multiplier) and he sees you, he walks up and gives
##     you a lecture that freezes you for a few seconds.
## The visible model is a placeholder capsule; swap in a character later.

enum State { PATROL, APPROACH, LECTURE }

## He saw a core rule broken for long enough.
signal caught_core_violation(kind: StringName)
## He starts / finishes lecturing the player.
signal lecture_started
signal lecture_finished

@export var walk_speed: float = 1.8
@export var chase_speed: float = 3.2
@export var view_distance: float = 14.0
@export var fov_degrees: float = 110.0
@export var eye_height: float = 1.6
## Seconds a core violation must be in sight before he reacts.
@export var core_seconds: float = 1.3
@export var lecture_seconds: float = 3.0

const LECTURES: Array[String] = [
	"You need to rest. Resting is mandatory. Productivity is also mandatory.",
	"Slow down, employee. We cannot afford your enthusiasm.",
	"That multiplier is suspicious. Smile, and carry on.",
	"Hydrate. Then work harder. Both are company policy.",
]

var route: PackedVector3Array = PackedVector3Array()
var player: Player = null
## 0 = calm, 1 = warnings, 2 = lots of attention (set by the manager).
var heat_tier: int = 0
var state: State = State.PATROL

var _target_index: int = 0
var _seen: Dictionary = {}  # violation key -> seconds seen (negative = cooling down)
var _lecture_left: float = 0.0
var _lecture_cooldown: float = 10.0
var _lost_player_time: float = 0.0


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not GameState.on_shift:
		return
	var sees := can_see_player()
	_watch_violations(sees, delta)
	_lecture_cooldown = maxf(0.0, _lecture_cooldown - delta)
	match state:
		State.PATROL:
			_patrol(delta)
			if sees and heat_tier >= 1 and _lecture_cooldown <= 0.0 and not player.frozen:
				state = State.APPROACH
				_lost_player_time = 0.0
		State.APPROACH:
			_approach(delta, sees)
		State.LECTURE:
			_lecture(delta)


## True when the player is inside the view cone, close enough and not hidden by
## anything solid.
func can_see_player() -> bool:
	var eyes := global_position + Vector3.UP * eye_height
	var target := player.global_position + Vector3.UP * 1.2
	var to_player := target - eyes
	if to_player.length() > view_distance:
		return false
	var forward := -global_transform.basis.z
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	if flat.length() > 0.5 and rad_to_deg(forward.angle_to(flat.normalized())) > fov_degrees / 2.0:
		return false
	var query := PhysicsRayQueryParameters3D.create(eyes, target, 1)  # layer 1 = the world
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# ---- Watching ---------------------------------------------------------------------

func _watch_violations(sees: bool, delta: float) -> void:
	var core := player.get_core_violations()
	for kind: StringName in [&"phone", &"smoking", &"gambling", &"eating"]:
		var key := "core_" + String(kind)
		if kind in core and sees:
			_seen[key] = _seen.get(key, 0.0) + delta
			if _seen[key] >= core_seconds:
				_seen[key] = 0.0
				caught_core_violation.emit(kind)
		else:
			_seen[key] = maxf(0.0, _seen.get(key, 0.0) - delta * 2.0)


# ---- Moving -----------------------------------------------------------------------

func _patrol(delta: float) -> void:
	if route.is_empty():
		return
	var target := route[_target_index]
	if _step_towards(target, walk_speed, delta) < 0.4:
		_target_index = (_target_index + 1) % route.size()


func _approach(delta: float, sees: bool) -> void:
	_lost_player_time = 0.0 if sees else _lost_player_time + delta
	if _lost_player_time > 3.0:
		state = State.PATROL
		_lecture_cooldown = 15.0
		return
	var distance := _step_towards(player.global_position, chase_speed, delta, 2.0)
	if distance <= 2.2:
		state = State.LECTURE
		_lecture_left = lecture_seconds
		player.frozen = true
		player.hud.phone.close()
		GameState.notice.emit("Supervisor: " + LECTURES[randi() % LECTURES.size()])
		lecture_started.emit()


func _lecture(delta: float) -> void:
	_face(player.global_position, delta)
	_lecture_left -= delta
	if _lecture_left <= 0.0:
		finish_lecture()


## An alarm went off: come and have a word with the player.
func alert() -> void:
	if state == State.PATROL:
		state = State.APPROACH
		_lost_player_time = 0.0
	_lecture_cooldown = 0.0


## Ends a lecture (also called if the player is carried away meanwhile).
func finish_lecture() -> void:
	if state != State.LECTURE:
		return
	state = State.PATROL
	_lecture_cooldown = 45.0 if heat_tier <= 1 else 30.0
	if is_instance_valid(player):
		player.frozen = false
	lecture_finished.emit()


## Walks towards `target` (flat) and returns the remaining distance. `stop_at`
## keeps some distance (for walking up to the player).
func _step_towards(target: Vector3, speed: float, delta: float, stop_at: float = 0.0) -> float:
	var to := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var distance := to.length()
	if distance > stop_at + 0.01:
		var step := minf(speed * delta, distance - stop_at)
		global_position += to.normalized() * step
	_face(target, delta)
	return distance


func _face(target: Vector3, delta: float) -> void:
	var to := target - global_position
	if Vector2(to.x, to.z).length() < 0.05:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(8.0 * delta, 0.0, 1.0))
