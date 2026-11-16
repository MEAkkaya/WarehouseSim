class_name OrderGenerator
extends RefCounted
## Makes random orders from what the shelves actually hold, so an order can
## always be fulfilled. Static: call `OrderGenerator.generate(...)`, no node needed.

static var _counter: int = 0


## `shelves` - candidate shelves (only ones with an item and stock are used).
## `space_budget` - the packing spaces the whole order may take (an item takes
## `item.size` spaces; a medium box has 8), so the order fits one box.
static func generate(shelves: Array, min_lines: int, max_lines: int,
		max_per_line: int, space_budget: int) -> Order:
	var candidates: Array[Shelf] = []
	for s in shelves:
		var shelf := s as Shelf
		if shelf != null and shelf.item != null and shelf.stock > 0:
			candidates.append(shelf)
	candidates.shuffle()
	# One line per product, even if several shelves hold it (the HUD counts by item).
	var seen: Array[ItemData] = []
	var unique: Array[Shelf] = []
	for shelf in candidates:
		if not seen.has(shelf.item):
			seen.append(shelf.item)
			unique.append(shelf)
	candidates = unique

	var order := Order.new()
	_counter += 1
	order.number = _counter
	var line_count := mini(randi_range(min_lines, max_lines), candidates.size())
	for i in line_count:
		var shelf := candidates[i]
		var room := space_budget - order.total_space()
		var quantity := mini(randi_range(1, max_per_line), mini(shelf.stock, room / shelf.item.size))
		if quantity <= 0:
			break
		order.lines.append(Order.Line.new(shelf.item, quantity, shelf.shelf_id))
	order.sort_lines()
	return order
