extends WarehouseEvent
## Low Gravity: you jump about three times as high, and dropped items float down
## slowly. (The parkour to the second floor becomes easy; the shelves too.)


func _start() -> void:
	player.gravity_factor = 0.3
	_set_item_gravity(0.12)


func _stop() -> void:
	if player != null:
		player.gravity_factor = 1.0
	_set_item_gravity(1.0)


func _set_item_gravity(scale: float) -> void:
	GameState.gravity_scale = scale  # items created from now on
	# When you leave the warehouse the whole interior is deleted and this node has
	# already left the tree, so `get_tree()` would be null here - ask the engine instead.
	var tree := Engine.get_main_loop() as SceneTree
	for node in tree.get_nodes_in_group("world_items"):
		(node as WorldItem).gravity_scale = scale
		(node as WorldItem).sleeping = false
