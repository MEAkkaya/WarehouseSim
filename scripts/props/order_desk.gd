class_name OrderDesk
extends Interactable
## The desk/printer that hands out orders as paper bills. Click it to print one;
## the bill goes into your hotbar. The desk remembers every order it has issued.

## Order size. The packing spaces of an order are random between these (a small box
## has 4 spaces, a medium one 8, a big one 16).
@export var min_lines: int = 2
@export var max_lines: int = 3
@export var max_per_line: int = 3
@export var min_space: int = 4
@export var max_space: int = 12

## Every order printed so far (finished ones stay, marked `completed`).
var issued: Array[Order] = []


func _ready() -> void:
	add_to_group("order_desks")  # the pallet finds the desk through this group


## Orders that still wait for a matching box.
func pending_orders() -> Array[Order]:
	var result: Array[Order] = []
	for order in issued:
		if not order.completed:
			result.append(order)
	return result


## True while the warehouse is still being filled (there is nothing to order yet).
func _is_loading() -> bool:
	var queue := get_parent().get_node_or_null("LoadQueue") as LoadQueue
	return queue != null and queue.busy


func can_interact(_who: Node) -> bool:
	return not _is_loading()


func get_prompt(who: Node) -> String:
	if not (who as Player).inventory.has_room():
		return "Hotbar is full"
	return "Print an order (computer)"


func interact(who: Node) -> void:
	var player := who as Player
	if not player.inventory.has_room():
		return
	# Every Shelf adds itself to the "shelves" group (see shelf.gd).
	var shelves := get_tree().get_nodes_in_group("shelves")
	var order := OrderGenerator.generate(shelves, min_lines, max_lines, max_per_line, randi_range(min_space, max_space))
	if order.lines.is_empty():
		GameState.notice.emit("No stock left for new orders. Clock out and back in: the crew restocks the shelves.")
		return
	issued.append(order)
	player.inventory.add(InventoryEntry.make_bill(order))
	super(who)
