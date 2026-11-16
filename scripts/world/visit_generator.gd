class_name VisitGenerator
extends Node
## Every time the warehouse interior is created (each clock-in), this decides what is
## on the storeroom shelves: a random product on most shelves, random stock levels,
## a few shelves nearly or completely empty, and where the co-workers stand.
## Nothing persists between visits: the crew "restocks" the shelves between shifts.
## So the stock is finite: send out everything and you must clock out and back in.
##
## It must be placed after the storage regions in the scene, so their shelves exist.

## Chance a storeroom shelf holds anything at all.
@export var stocked_chance: float = 0.65
## Of the stocked shelves, the chance they are completely sold out.
@export var sold_out_chance: float = 0.12
## Of the rest, the chance they are nearly empty (1-3 items).
@export var low_chance: float = 0.2
## Co-workers walking about the work floor.
@export var worker_scene: PackedScene = preload("res://scenes/npc/walking_npc.tscn")
@export var worker_count: int = 3

# Loops the co-workers walk (see WarehouseLayout.WORK_LOOPS).
const WORK_LOOPS: Array = WarehouseLayout.WORK_LOOPS


var _items: Array[ItemData] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	get_parent().add_to_group("interior_root")  # dropped things are parented to the interior
	_items = _load_items()
	if _items.is_empty():
		return
	_rng.randomize()
	var queue := get_parent().get_node_or_null("LoadQueue") as LoadQueue
	if queue == null:
		_plan_stocking(null)
	else:
		# Queued AFTER all the shelf-creating tasks, so the shelves exist when it runs.
		queue.enqueue(_plan_stocking.bind(queue))


## Decides what goes on every shelf. With a queue, each shelf is stocked by its own
## small task (a few per frame), so the shelves fill up over a second or two while
## the player is still walking to them.
func _plan_stocking(queue: LoadQueue) -> void:
	for region in get_tree().get_nodes_in_group("storage_regions"):
		for shelf in (region as StorageRegion).shelves.values():
			if _rng.randf() > stocked_chance:
				continue
			var item: ItemData = _items[_rng.randi() % _items.size()]
			var stock: int
			var roll := _rng.randf()
			if roll < sold_out_chance:
				stock = 0
			elif roll < sold_out_chance + low_chance:
				stock = _rng.randi_range(1, 3)
			else:
				stock = _rng.randi_range(4, mini((shelf as Shelf).max_stock, 12))
			if queue != null:
				queue.enqueue(_stock_shelf.bind(shelf, item, stock, queue))
			else:
				(shelf as Shelf).configure(item, stock)
	_spawn_workers(_rng, queue)


## Co-workers start at random places on random loops every visit.
func _spawn_workers(rng: RandomNumberGenerator, queue: LoadQueue) -> void:
	var names: Array[String] = []
	for employee in Career.employees:
		names.append(employee.name)
	names.shuffle()
	for i in worker_count:
		var loop: Array = WORK_LOOPS[rng.randi() % WORK_LOOPS.size()]
		var worker := worker_scene.instantiate() as WalkingNPC
		worker.employee_name = names[i % names.size()] if not names.is_empty() else "Worker"
		worker.route = PackedVector3Array(loop)
		worker._target_index = rng.randi() % loop.size()
		worker.position = loop[rng.randi() % loop.size()]  # the interior sits at the origin
		if queue != null:
			queue.enqueue(_add_worker.bind(worker))  # one co-worker per task
		else:
			get_parent().add_child.call_deferred(worker)  # the parent is still setting up its children


## Stocks one shelf: queues the small tasks that create its items.
func _stock_shelf(shelf: Shelf, item: ItemData, stock: int, queue: LoadQueue) -> void:
	if is_instance_valid(shelf) and is_instance_valid(queue):
		shelf.configure_sliced(item, stock, queue)


func _add_worker(worker: WalkingNPC) -> void:
	if is_instance_valid(worker) and is_inside_tree():
		get_parent().add_child(worker)
	elif is_instance_valid(worker):
		worker.free()


func _load_items() -> Array[ItemData]:
	return ItemCatalog.get_all()
