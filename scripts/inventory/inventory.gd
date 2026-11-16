class_name Inventory
extends RefCounted
## A small hotbar: a fixed number of slots, one of which is selected.
## Small items and bills live here; boxes are too big and are carried in the
## hands instead (see Player.carried).

## Emitted whenever slots or the selection change (the HUD redraws on this).
signal changed

var slots: Array[InventoryEntry] = []
var selected: int = 0


func _init(size: int = 5) -> void:
	slots.resize(size)  # all null = all empty


func size() -> int:
	return slots.size()


func has_room() -> bool:
	return _first_free() != -1


func _first_free() -> int:
	for i in slots.size():
		if slots[i] == null:
			return i
	return -1


## Stores `entry` in the first free slot. Returns false if the hotbar is full.
func add(entry: InventoryEntry) -> bool:
	var index := _first_free()
	if index == -1:
		return false
	slots[index] = entry
	changed.emit()
	return true


## Empties every slot.
func clear() -> void:
	for i in slots.size():
		slots[i] = null
	changed.emit()


## The entry in the selected slot (null if empty).
func get_selected() -> InventoryEntry:
	return slots[selected]


## Empties the selected slot and returns what was in it.
func remove_selected() -> InventoryEntry:
	var entry := slots[selected]
	slots[selected] = null
	changed.emit()
	return entry


func select(index: int) -> void:
	index = clampi(index, 0, slots.size() - 1)
	if index != selected:
		selected = index
		changed.emit()


## Mouse wheel: step the selection, wrapping around.
func cycle(direction: int) -> void:
	select_wrapped(selected + direction)


func select_wrapped(index: int) -> void:
	selected = posmod(index, slots.size())
	changed.emit()
