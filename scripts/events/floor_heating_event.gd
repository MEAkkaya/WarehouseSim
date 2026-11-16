extends WarehouseEvent
## Emergency Floor Heating: the floor is dangerously hot. You can touch it for only 2
## seconds in a row (a bar fills on the HUD); stand on anything else - a shelf, a
## pallet, a box, a dropped item, a moving platform - to cool your feet. A full bar
## knocks you out. Dropped packages make stepping stones.

var _floors: Array[CSGBox3D] = []
var _old_materials: Array[Material] = []


func _start() -> void:
	# Every floor slab of the warehouse ("FloorMain", "FloorStock"...) gets hot.
	for node in interior.get_children():
		if node is CSGBox3D and node.name.begins_with("Floor"):
			var slab := node as CSGBox3D
			slab.add_to_group("hot_floor")
			_floors.append(slab)
			_old_materials.append(slab.material)
			var hot := StandardMaterial3D.new()
			hot.albedo_color = Color(0.9, 0.25, 0.08)
			hot.emission_enabled = true
			hot.emission = Color(1.0, 0.3, 0.05)
			hot.emission_energy_multiplier = 0.6
			slab.material = hot
	player.set_hot_floor(true)


func _stop() -> void:
	player.set_hot_floor(false)
	for i in _floors.size():
		if is_instance_valid(_floors[i]):
			_floors[i].remove_from_group("hot_floor")
			_floors[i].material = _old_materials[i]
	_floors.clear()
	_old_materials.clear()
