class_name TimedDoor
extends Interactable
## A door that is only unlocked at certain times (see OpeningHours): the shady gambling
## room opens on weekdays, the night club's back door from Friday to Sunday evenings.
## Click it while it is unlocked and it slides up out of the way; it shuts again when you
## walk off, or at closing time. Locked doors always open from the INSIDE, so nobody is
## ever trapped. Every TimedDoor shows up in the phone's Places app.

## The place behind the door, as shown in the Places app.
@export var venue_name: String = "Secret place"
## Weekdays it is open on: 0 = Monday ... 6 = Sunday.
@export var open_days: Array[int] = [0, 1, 2, 3, 4]
@export var open_from: float = 0.0
## Closing hour (smaller than open_from = after midnight; 24 = midnight).
@export var open_to: float = 24.0
## Size of the doorway.
@export var door_size: Vector3 = Vector3(1.2, 2.5, 0.15)
## Local direction that points to the INSIDE of the venue.
@export var inside_direction: Vector3 = Vector3(0, 0, -1)
## How far the door slides when it opens (up, into the wall above).
@export var slide: Vector3 = Vector3(0, 2.6, 0)
## How far away you may be before the door shuts again.
@export var close_distance: float = 4.0

var _hours: OpeningHours
var _is_open: bool = false
var _closed_position: Vector3
var _tween: Tween = null
var _sign: Label3D = null


func get_hours() -> OpeningHours:
	if _hours == null:
		_hours = OpeningHours.make(open_days, open_from, open_to)
	return _hours


func _ready() -> void:
	add_to_group("venues")
	_closed_position = position
	ApartmentKit.body_box(self, door_size, Color(0.35, 0.12, 0.12))
	_sign = ApartmentKit.label(self, venue_name, Vector3(0, door_size.y + 0.35, 0), 0.006,
			Color(1.0, 0.45, 0.45), false)
	# A sign that faces away from the inside, towards whoever stands at the door.
	var outward := -inside_direction
	_sign.rotation.y = atan2(outward.x, outward.z)
	set_process(true)


## Which side of the door is the player on?
func _player_is_inside(who: Node3D) -> bool:
	var local := to_local(who.global_position)
	return local.dot(inside_direction) > 0.0


func can_interact(_who: Node) -> bool:
	return not _is_open


func get_prompt(who: Node) -> String:
	if get_hours().is_open_now() or _player_is_inside(who as Node3D):
		return "Open the door (%s)" % venue_name
	return "Locked - %s opens %s" % [venue_name, get_hours().describe()]


func interact(who: Node) -> void:
	if get_hours().is_open_now() or _player_is_inside(who as Node3D):
		_set_open(true)
	else:
		GameState.notice.emit("Locked. %s: %s." % [venue_name, get_hours().describe()])
	super(who)


func _process(_delta: float) -> void:
	if not _is_open:
		return
	var player := get_tree().get_first_node_in_group("players") as Node3D
	if player == null:
		return
	var far := global_position.distance_to(player.global_position) > close_distance
	if far:
		_set_open(false)


func _set_open(open: bool) -> void:
	if _is_open == open:
		return
	_is_open = open
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", _closed_position + (slide if open else Vector3.ZERO), 0.6)
