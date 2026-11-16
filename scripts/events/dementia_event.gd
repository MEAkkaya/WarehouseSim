extends WarehouseEvent
## Dementia: the boss has forgotten where everything goes. All storeroom shelves are
## shuffled - the water bottle that is normally at XA 01 may be at ZA 03 today. When
## the event ends, everything goes back to its standard place.

# [shelf, original item, original stock]
var _original: Array = []


func _start() -> void:
	var shelves: Array[Shelf] = []
	for region in ground_regions():
		for shelf in region.shelves.values():
			if (shelf as Shelf).item != null:
				shelves.append(shelf)
	var contents: Array = []
	for shelf in shelves:
		_original.append([shelf, shelf.item, shelf.stock])
		contents.append([shelf.item, shelf.stock])
	contents.shuffle()
	for i in shelves.size():
		run_later(shelves[i].configure.bind(contents[i][0], contents[i][1]))


func _stop() -> void:
	if not is_inside_tree() or interior == null or interior.has_meta(&"unloading"):
		return  # the whole warehouse is being deleted anyway
	for entry in _original:
		var shelf := entry[0] as Shelf
		if is_instance_valid(shelf):
			run_later(shelf.configure.bind(entry[1], entry[2]))
	_original.clear()
