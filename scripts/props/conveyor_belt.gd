class_name ConveyorBelt
extends Interactable
## The conveyor belt of the loading line. You put a CLOSED, packed box with its bill on it;
## the belt carries it along WarehouseLayout.BELT_PATH (along the corridor, then through
## the wall into the loading yard). At the end of the belt the box is checked against its
## bill (a box with no bill cannot be put on the belt) - correct: pay and a higher multiplier,
## wrong: the multiplier is lost - and the
## robot arm takes it onto the pallet. Once a box is on the belt you cannot take it back,
## so be sure of the box BEFORE you put it on.
##
## The belt itself (models, collision) is built in code from the path; the loading yard
## (robot, pallet, truck) is a LoadingYard node that receives the boxes.

## Metres per second.
@export var speed: float = 2.0
## Minimum distance between two boxes on the belt, in metres.
@export var spacing: float = 1.0
@export var belt_width: float = 0.8
@export var belt_top: float = 0.85

## Boxes reaching the end of the belt: the loading yard takes them from here.
signal box_arrived(box: Box)

var path: Array[Vector3] = WarehouseLayout.BELT_PATH
## The boxes on the belt, in order (the first is the furthest along).
var _riders: Array[Box] = []
## How far along the path each rider is (metres), same order.
var _along: Array[float] = []
var _lengths: Array[float] = []
var _total: float = 0.0
var _result_label: Label3D = null
var _result_left: float = 0.0
## The box waiting at the end of the belt for the robot (nothing moves past it).
var _waiting_at_end: Box = null


func _ready() -> void:
	add_to_group("conveyor_belts")
	prompt_text = "Conveyor belt"
	_build()


# ---- Building ----------------------------------------------------------------------------

func _build() -> void:
	var shader := load("res://assets/shaders/conveyor.gdshader") as Shader
	var frame_color := ApartmentKit.material(Color(0.5, 0.5, 0.55))
	_total = 0.0
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var length := a.distance_to(b)
		_lengths.append(length)
		_total += length
		var centre := (a + b) / 2.0
		var direction := (b - a).normalized()
		var holder := Node3D.new()
		holder.position = Vector3(centre.x, 0.0, centre.z)
		holder.basis = Basis.looking_at(direction, Vector3.UP)  # local -Z = the belt's way
		add_child(holder)
		# The belt surface.
		var surface := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(belt_width, 0.1, length)
		surface.mesh = mesh
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("speed", speed)
		surface.material_override = material
		surface.position.y = belt_top - 0.05
		holder.add_child(surface)
		# Side rails and legs.
		for side in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			var rail_mesh := BoxMesh.new()
			rail_mesh.size = Vector3(0.06, 0.16, length)
			rail_mesh.material = frame_color
			rail.mesh = rail_mesh
			rail.position = Vector3(side * (belt_width / 2.0 + 0.03), belt_top - 0.04, 0.0)
			holder.add_child(rail)
		var legs := int(length / 2.0) + 1
		for k in legs:
			var leg := MeshInstance3D.new()
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(belt_width, belt_top - 0.1, 0.08)
			leg_mesh.material = frame_color
			leg.mesh = leg_mesh
			leg.position = Vector3(0.0, (belt_top - 0.1) / 2.0, -length / 2.0 + (k + 0.5) * length / legs)
			holder.add_child(leg)
		# Solid, so you cannot walk through it (and it can be aimed at).
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(belt_width + 0.12, belt_top, length)
		shape.shape = box
		shape.transform = Transform3D(holder.basis, Vector3(centre.x, belt_top / 2.0, centre.z))
		add_child(shape)
	_result_label = Label3D.new()
	_result_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_result_label.pixel_size = 0.0035
	_result_label.font_size = 40
	_result_label.outline_size = 12
	_result_label.modulate = Color(0.6, 1.0, 0.6)
	_result_label.position = path[path.size() - 1] + Vector3(0.0, 3.2, 0.0)
	_result_label.visible = false
	add_child(_result_label)


## The point of the belt (world) at `distance` metres from its start, and the direction there.
func point_at(distance: float) -> Vector3:
	var remaining := clampf(distance, 0.0, _total)
	for i in _lengths.size():
		if remaining <= _lengths[i] or i == _lengths.size() - 1:
			var t := remaining / maxf(_lengths[i], 0.001)
			return path[i].lerp(path[i + 1], clampf(t, 0.0, 1.0))
		remaining -= _lengths[i]
	return path[path.size() - 1]


func direction_at(distance: float) -> Vector3:
	var remaining := clampf(distance, 0.0, _total)
	for i in _lengths.size():
		if remaining <= _lengths[i] or i == _lengths.size() - 1:
			return (path[i + 1] - path[i]).normalized()
		remaining -= _lengths[i]
	return Vector3.FORWARD


## Distance along the belt of the point of the belt nearest to `world_point`.
func distance_of(world_point: Vector3) -> float:
	var best := 0.0
	var best_distance := INF
	var walked := 0.0
	for i in _lengths.size():
		var a := path[i]
		var b := path[i + 1]
		var ab := b - a
		var t := clampf((world_point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var nearest := a + ab * t
		var d := Vector2(nearest.x - world_point.x, nearest.z - world_point.z).length()
		if d < best_distance:
			best_distance = d
			best = walked + _lengths[i] * t
		walked += _lengths[i]
	return best


# ---- Putting boxes on --------------------------------------------------------------------

## Why the carried box cannot go on (empty = it can).
func _reject_reason(box: Box, at: float) -> String:
	if box == null:
		return "Carry a closed box to put it on the belt"
	if box.attached_order == null:
		return "Attach a bill first [B]"
	if box.is_open:
		return "Close the box first [F]"
	if at >= _total - spacing:
		return "Too close to the end of the belt"
	for along in _along:
		if absf(along - at) < spacing:
			return "The belt is busy here - put it a bit further back"
	return ""


## Where along the belt the player is aiming (the belt is long: you put the box where you aim).
func _aim_distance(who: Node) -> float:
	var player := who as Player
	if player != null and player.interactor.is_colliding():
		return distance_of(player.interactor.get_collision_point())
	return 0.0


func can_interact(who: Node) -> bool:
	return (who as Player).carried != null


func get_prompt(who: Node) -> String:
	var reason := _reject_reason((who as Player).carried, _aim_distance(who))
	if reason != "":
		return reason
	return "Put the box on the belt - it is checked at the end and you cannot take it back"


func interact(who: Node) -> void:
	var player := who as Player
	var at := _aim_distance(who)
	var box := player.carried
	if _reject_reason(box, at) != "":
		return
	player.release_held()
	_put_on(box, at)
	super(who)


func _put_on(box: Box, at: float) -> void:
	box.collision_layer = 0  # it rides on its own now: nobody can pick it up
	box.reparent(self, false)
	var index := 0
	while index < _along.size() and _along[index] > at:
		index += 1  # keep the list ordered: furthest along first
	_riders.insert(index, box)
	_along.insert(index, at)
	_place(box, at)


# ---- Moving ---------------------------------------------------------------------------------

func _place(box: Box, distance: float) -> void:
	var point := point_at(distance)
	var direction := direction_at(distance)
	box.global_position = Vector3(point.x, belt_top, point.z)
	box.global_basis = Basis.looking_at(direction, Vector3.UP)


func _process(delta: float) -> void:
	for i in _riders.size():
		var limit := _total
		if i > 0:
			limit = _along[i - 1] - spacing  # never closer than `spacing` to the box ahead
		_along[i] = minf(_along[i] + speed * delta, limit)
		_place(_riders[i], _along[i])
	# The first box has reached the end: the robot takes it (one at a time).
	if not _riders.is_empty() and _waiting_at_end == null and _along[0] >= _total - 0.01:
		_waiting_at_end = _riders[0]
		_riders.remove_at(0)
		_along.remove_at(0)
		_check(_waiting_at_end)
		box_arrived.emit(_waiting_at_end)
	if _result_left > 0.0:
		_result_left -= delta
		_result_label.visible = _result_left > 0.0


## The robot has taken the box away from the end of the belt.
func release_end() -> void:
	_waiting_at_end = null


## Checks the box against the bill attached to it, like the old shipping pallet did.
func _check(box: Box) -> void:
	var order := box.attached_order
	var text := ""
	if order == null:
		GameState.order_shipped(null, false)
		text = "A box with no bill: WRONG"
	elif order.completed:
		GameState.order_shipped(order, false)
		text = "Order #%d was already shipped: WRONG" % order.number
	elif order.matches(box.contents):
		order.completed = true
		order.correct = true
		GameState.order_shipped(order, true)
		text = "Order #%d: CORRECT  (multiplier x%.2f)" % [order.number, GameState.multiplier]
	else:
		order.completed = true
		GameState.order_shipped(order, false)
		text = "Order #%d: WRONG contents  (multiplier reset)" % order.number
	_result_label.text = text
	_result_label.modulate = Color(0.6, 1.0, 0.6) if text.contains("CORRECT") else Color(1.0, 0.55, 0.5)
	_result_label.visible = true
	_result_left = 6.0
	var good := text.contains("CORRECT")
	var title := "Order #%d" % order.number if order != null else "No bill"
	var detail := "Correct - multiplier x%.2f" % GameState.multiplier if good else ("Wrong - multiplier reset" if order != null else "Box without a bill")
	for p in get_tree().get_nodes_in_group("players"):
		(p as Player).hud.show_achievement(title, detail, good)
