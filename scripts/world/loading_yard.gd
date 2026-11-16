class_name LoadingYard
extends Node3D
## The loading line: the conveyor belt (it starts in the corridor and ends in the yard
## outside), a robot arm that lifts each box from the end of the belt onto a pallet, and the
## trucks. When the pallet is full it slides to the truck at the bay, the truck takes it and
## drives off, the next truck backs in, and a new empty pallet is waiting. The truck is the model
## assets/models/truck.glb: its animations "Open" / "Close" move the rear door.
##
## Everything is built in code from the numbers in WarehouseLayout (placeholders: swap in
## models later). It lives in the world scene (not in the warehouse interior), so the yard
## and the trucks are there even when the warehouse is not loaded.

## Boxes on a full pallet: two layers of four.
const PALLET_CAPACITY := 8
const SLOTS: Array[Vector2] = [Vector2(-0.215, -0.215), Vector2(-0.215, 0.215), Vector2(0.215, -0.215), Vector2(0.215, 0.215)]

var belt: ConveyorBelt = null
var robot: RobotArm = null
var pallet: Node3D = null
## The boxes on the pallet now (the robot stacks them; they leave with the truck).
var pallet_boxes: Array[Box] = []
## Height of the top of the stack in each slot (so boxes of any height can be stacked).
var _slot_tops: Array[float] = []
## The truck at the bay (null while one is driving off / in) and a parked one for show.
var bay_truck: Node3D = null
var parked_truck: Node3D = null
## How many trucks have been loaded so far (for the stats).
var trucks_loaded: int = 0

var _busy: bool = false          ## the robot or the truck is working
var _arrived: Array[Box] = []    ## boxes at the end of the belt, waiting for the robot
var _truck_count: int = 0


func _ready() -> void:
	add_to_group("loading_yard")
	belt = ConveyorBelt.new()
	belt.name = "ConveyorBelt"
	add_child(belt)
	belt.box_arrived.connect(_on_box_arrived)
	robot = RobotArm.new()
	robot.name = "RobotArm"
	robot.position = Vector3(WarehouseLayout.ROBOT_BASE.x, TownLayout.GROUND_TOP, WarehouseLayout.ROBOT_BASE.z)
	add_child(robot)
	_new_pallet()
	bay_truck = _make_truck(WarehouseLayout.TRUCK_BAY)
	parked_truck = _make_truck(WarehouseLayout.TRUCK_QUEUE)
	# A sign over the end of the belt.
	var sign_label := ApartmentKit.label(self, "LOADING LINE", Vector3(WarehouseLayout.PALLET_SPOT.x, 3.4, WarehouseLayout.PALLET_SPOT.z + 3.0), 0.012, Color(1.0, 0.8, 0.3), true)
	sign_label.outline_size = 12


# ---- The pallet --------------------------------------------------------------------------------

func _new_pallet() -> void:
	pallet = Node3D.new()
	pallet.name = "Pallet"
	pallet.position = Vector3(WarehouseLayout.PALLET_SPOT.x, TownLayout.GROUND_TOP, WarehouseLayout.PALLET_SPOT.z)
	add_child(pallet)
	var model := (load("res://assets/models/pallet.glb") as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * 0.27
	model.position.y = 0.1744
	pallet.add_child(model)
	pallet_boxes.clear()
	_slot_tops.clear()


## Where the next box goes on the pallet (world position of the box's bottom centre): the
## first four on the pallet, the next four on top of them.
func _slot_position(index: int) -> Vector3:
	var slot := SLOTS[index % SLOTS.size()]
	var y := 0.187 if index < SLOTS.size() else _slot_tops[index - SLOTS.size()]
	return pallet.global_position + Vector3(slot.x, y, slot.y)


# ---- Boxes arriving, the robot ---------------------------------------------------------------

func _on_box_arrived(box: Box) -> void:
	_arrived.append(box)
	_work()


## The robot works through the boxes that have reached the end of the belt, one by one.
func _work() -> void:
	if _busy:
		return
	_busy = true
	while not _arrived.is_empty():
		var box: Box = _arrived.pop_front()
		await _stack(box)
		belt.release_end()
		if pallet_boxes.size() >= PALLET_CAPACITY:
			await _send_pallet_off()
	_busy = false


## Lifts `box` from the end of the belt onto the next slot of the pallet.
func _stack(box: Box) -> void:
	var end := belt.point_at(INF)
	var hold := Vector3(0.0, box.stack_height + 0.05, 0.0)
	var above := Vector3(0.0, 1.1, 0.0)
	# 1. over the box, 2. down to it
	await robot.reach_to(Vector3(end.x, belt.belt_top, end.z) + hold + above, 0.7)
	await robot.reach_to(Vector3(end.x, belt.belt_top, end.z) + hold, 0.4)
	# 3. grab it (it hangs from the gripper) and lift
	box.reparent(robot.gripper, true)
	box.position = Vector3(0.0, -box.stack_height - 0.05, 0.0)
	box.rotation = Vector3.ZERO
	await robot.reach_to(Vector3(end.x, belt.belt_top, end.z) + hold + above, 0.4)
	# 4. over the pallet, down, let go
	var slot := _slot_position(pallet_boxes.size())
	await robot.reach_to(slot + hold + above, 0.9)
	await robot.reach_to(slot + hold, 0.4)
	box.reparent(pallet, true)
	box.global_position = slot
	box.rotation = Vector3.ZERO
	pallet_boxes.append(box)
	_slot_tops.append(slot.y - pallet.global_position.y + box.stack_height)
	await robot.reach_to(slot + hold + above, 0.35)


# ---- Trucks ------------------------------------------------------------------------------------

## The truck model (assets/models/truck.glb) is 14 m long and 6 m tall at its own scale: this
## makes it a normal lorry. Its origin is the middle of the cargo area at the model's own
## ground level minus 0.37 (the wheels); its rear door is at local +Z, the cab at -Z.
const TRUCK_SCALE := 0.7
const TRUCK_WHEELS_BELOW := 0.367     ## model units: how far the wheels reach below the origin
const TRUCK_REAR := 5.08              ## model units: the rear end of the cargo area (local +Z)
const TRUCK_BED := 1.9                ## model units: the cargo floor above the ground
## The truck faces east (cab at the east end): its rear (local +Z) points west, to the pallet.
const TRUCK_YAW := -PI / 2.0


## A truck standing at `at` (x, z), cab to the east, door closed. `decor` = a parked truck
## that never moves (it has no door animation use).
func _make_truck(at: Vector3) -> Node3D:
	var truck := StaticBody3D.new()
	truck.name = "Truck%d" % _truck_count
	_truck_count += 1
	truck.position = Vector3(at.x, TownLayout.GROUND_TOP + TRUCK_WHEELS_BELOW * TRUCK_SCALE, at.z)
	truck.rotation.y = TRUCK_YAW
	add_child(truck)
	var model := (load("res://assets/models/truck.glb") as PackedScene).instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3.ONE * TRUCK_SCALE
	truck.add_child(model)
	# Solid (cargo area + chassis, and the cab); the rear stays open for the pallet, which is
	# not a physical body.
	var s := TRUCK_SCALE
	_truck_shape(truck, Vector3(3.2, 6.17, 10.0) * s, Vector3(0.0, 2.72, 0.0) * s)
	_truck_shape(truck, Vector3(3.0, 4.7, 3.9) * s, Vector3(0.0, 1.98, -6.9) * s)
	return truck


func _truck_shape(truck: Node3D, size: Vector3, centre: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	truck.add_child(shape)


## Plays the truck's "Open" / "Close" animation for the rear door and waits until it is done.
func _door(truck: Node3D, open: bool) -> void:
	var player := truck.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return
	player.play("Open" if open else "Close")
	await player.animation_finished


## The full pallet goes to the truck, the truck leaves, the next one backs in.
func _send_pallet_off() -> void:
	var full := pallet
	var truck := bay_truck
	# The pallet is lifted to the height of the cargo floor and slid to the rear of the truck.
	var rear_x := truck.global_position.x - TRUCK_REAR * TRUCK_SCALE
	var bed_y := TownLayout.GROUND_TOP + TRUCK_BED * TRUCK_SCALE
	await _door(truck, true)
	var slide := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	slide.tween_property(full, "global_position", Vector3(rear_x - 1.2, TownLayout.GROUND_TOP, truck.global_position.z), 2.0)
	slide.tween_property(full, "global_position:y", bed_y, 0.8)
	await slide.finished
	# ...and goes in, along the cargo floor.
	var into := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	into.tween_property(full, "global_position:x", rear_x + 3.2, 1.6)
	await into.finished
	_new_pallet()  # the next pallet waits at the robot while the truck gets ready
	await _door(truck, false)
	full.queue_free()
	trucks_loaded += 1
	Stats.add(&"trucks_loaded")
	# The truck pulls out to the east; the next one backs in from the east.
	bay_truck = null
	var drive := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drive.tween_property(truck, "global_position:x", truck.global_position.x + 90.0, 4.5)
	await drive.finished
	truck.queue_free()
	var next := _make_truck(WarehouseLayout.TRUCK_BAY)
	next.global_position.x += 90.0
	bay_truck = next
	var arrive := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arrive.tween_property(next, "global_position:x", WarehouseLayout.TRUCK_BAY.x, 6.0)
	await arrive.finished
