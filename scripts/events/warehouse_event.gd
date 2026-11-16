class_name WarehouseEvent
extends Node
## Base class of every daily event. An EventRunner creates one of these inside the
## warehouse interior when the event starts (and frees it when the event ends or the
## player leaves). Override `_start()` to change the world and `_stop()` to put
## everything back. Anything you create with `add_to_interior()` is deleted for you
## when the event stops.

## The interior this event happens in (set by the runner).
var interior: Node3D = null
var player: Player = null
var data: EventData = null

var _owned: Array[Node] = []


## Called by the runner once `interior`, `player` and `data` are set.
func start() -> void:
	_start()


func stop() -> void:
	_stop()
	for node in _owned:
		if is_instance_valid(node):
			node.queue_free()
	_owned.clear()
	queue_free()


func _start() -> void:
	pass


func _stop() -> void:
	pass


## Adds a node to the interior (deleted automatically when the event ends).
func add_to_interior(node: Node) -> void:
	interior.add_child(node)
	_owned.append(node)


## Runs a heavy task now, or spread over the next frames through the warehouse's load
## queue (so big events never freeze the game).
func run_later(task: Callable) -> void:
	var queue := interior.get_node_or_null("LoadQueue") as LoadQueue if interior != null else null
	if queue != null and queue.is_inside_tree():
		queue.enqueue(task)
	else:
		task.call()


## Regions of the ground floor (X, Y, Z - not the upstairs ones).
func ground_regions() -> Array[StorageRegion]:
	var result: Array[StorageRegion] = []
	for node in get_tree().get_nodes_in_group("storage_regions"):
		if (node as StorageRegion).global_position.y < 1.0:
			result.append(node)
	return result


## A random free spot on the work floor (the corridor, see WarehouseLayout).
func random_work_floor_point(rng: RandomNumberGenerator) -> Vector3:
	var floor_rect := WarehouseLayout.WORK_FLOOR
	for attempt in 40:
		var point := Vector2(rng.randf_range(floor_rect.position.x, floor_rect.end.x),
				rng.randf_range(floor_rect.position.y, floor_rect.end.y))
		var blocked := false
		for rect in WarehouseLayout.WORK_FLOOR_BLOCKED:
			if rect.has_point(point):
				blocked = true
		if not blocked:
			return Vector3(point.x, 0.1, point.y)
	return Vector3(40.0, 0.1, 7.0)


## A random spot in the aisle of a random corridor of a random ground region.
func random_aisle_point(rng: RandomNumberGenerator) -> Vector3:
	var regions := ground_regions()
	var region := regions[rng.randi() % regions.size()]
	var corridor := rng.randi() % region.corridor_count
	var local := Vector3(corridor * region.pitch + region.pitch / 2.0, 0.0,
			-rng.randf_range(0.5, region.corridor_length - 0.5))
	return region.to_global(local)  # (the regions can be turned)
