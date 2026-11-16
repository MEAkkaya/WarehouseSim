class_name Order
extends RefCounted
## One customer order: a list of lines, each "N x item, found on shelf X".
## Plain data (no nodes), so it can be generated, shown on the HUD and checked
## against a box's contents without caring where it came from.

## One line of an order.
class Line extends RefCounted:
	var item: ItemData
	var quantity: int
	var shelf_id: String

	func _init(p_item: ItemData, p_quantity: int, p_shelf_id: String) -> void:
		item = p_item
		quantity = p_quantity
		shelf_id = p_shelf_id


## Running number shown on the printout, e.g. "Order #3".
var number: int = 0
var lines: Array[Line] = []


## Puts the lines in walking order: region X, then Y, then Z, and inside a region by
## corridor, column and level - so the bill leads you through the warehouse without going
## back and forth.
func sort_lines() -> void:
	lines.sort_custom(func(a: Line, b: Line) -> bool: return _route_key(a.shelf_id) < _route_key(b.shelf_id))


## Regions whose corridors are walked from the last letter to the first (none now: the X and Y
## rooms are lettered from where you enter, so every region is walked A -> last).
const REVERSED_REGIONS := ""


## "XC 04 03" -> "0X.." : the region letter becomes its place in the route (X, Y, Z); in a
## reversed region the corridor letter is flipped (D sorts before A).
static func _route_key(shelf_id: String) -> String:
	if shelf_id.length() < 2:
		return shelf_id
	var rank := "XYZ".find(shelf_id[0])
	var corridor := shelf_id[1]
	if REVERSED_REGIONS.contains(shelf_id[0]):
		corridor = char(155 - corridor.unicode_at(0))  # A <-> Z
	return "%d%s%s" % [rank if rank >= 0 else 9, corridor, shelf_id.substr(2)]


## Total packing spaces across all lines (an item takes `item.size` spaces).
func total_space() -> int:
	var total := 0
	for line in lines:
		total += line.quantity * line.item.size
	return total


## Total number of items across all lines.
func total_items() -> int:
	var total := 0
	for line in lines:
		total += line.quantity
	return total


## Set once the box carrying this order's bill has been shipped...
var completed: bool = false
## ...and whether that box held exactly what the order asked for.
var correct: bool = false


## True when `packed` holds exactly what this order asks for: every line's
## quantity, and nothing else.
func matches(packed: Array[ItemData]) -> bool:
	if packed.size() != total_items():
		return false
	for line in lines:
		var have := 0
		for item in packed:
			if item == line.item:
				have += 1
		if have != line.quantity:
			return false
	return true
