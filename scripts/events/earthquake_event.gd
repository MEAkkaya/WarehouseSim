extends WarehouseEvent
## Earthquake Aftershock: sections of shelving collapse. The items that were on them
## fall into new piles on the floor - dig in them for the item you need, or use the
## piles as stepping stones. Aftershocks keep coming every minute or two.

@export var stacks_per_quake: int = 7

var _timer: Timer = null


func _start() -> void:
	_quake()
	_timer = Timer.new()
	_timer.wait_time = 75.0
	_timer.timeout.connect(_quake)
	add_child(_timer)
	_timer.start()


## Shakes the camera and brings a few stacks of shelves down.
func _quake() -> void:
	player.add_shake(2.2)
	GameState.notice.emit("AFTERSHOCK! Shelves are collapsing!")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var regions := ground_regions()
	for k in stacks_per_quake:
		var region := regions[rng.randi() % regions.size()]
		var corridor := rng.randi() % region.corridor_count
		var column := rng.randi_range(1, region.columns_per_side * 2)
		_collapse(region, corridor, column)
	# A few more tremors over the next seconds.
	for k in 4:
		await get_tree().create_timer(1.2).timeout
		if is_instance_valid(player):
			player.add_shake(1.2)


## Removes every layer of one stack and drops its items onto the floor.
func _collapse(region: StorageRegion, corridor: int, column: int) -> void:
	for level in range(1, region.levels + 1):
		var id := region.make_shelf_id(corridor, column, level)
		var shelf := region.get_shelf(id)
		if shelf == null:
			continue
		for world_item in shelf.get_items().duplicate():
			var item := world_item as WorldItem
			var at := item.global_position
			item.reparent(interior)
			item.release()
			item.global_position = at
			item.apply_central_impulse(Vector3(randf_range(-1, 1), randf_range(0.5, 2), randf_range(-1, 1)) * item.mass)
		region.shelves.erase(id)
		shelf.queue_free()
