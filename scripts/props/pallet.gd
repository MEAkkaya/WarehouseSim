class_name Pallet
extends Interactable
## A pallet that closed boxes are placed on. Finished orders end up here.
##
## Box positions are the Marker3D nodes under "Slots", filled in order. The
## default layout is 4 boxes per layer (2 x 2) and 3 layers = 12 slots: slots
## 0-3 are the bottom layer, 4-7 the middle, 8-11 the top. Move/add/remove
## markers in pallet.tscn to change it (keep `boxes_per_layer` in step). A box
## can only be picked up once the one stacked on it has been taken off.

## Fired when a box is put on / taken off.
signal box_placed(box: Box)
signal box_removed(box: Box)
## Fired when the pallet ships. `correct` boxes matched an open order, `wrong`
## boxes matched none.
signal shipped(correct: int, wrong: int)

## Development timer: every this many seconds the pallet is "shipped" (boxes
## removed and checked against the open orders). Later this will be a truck.
@export var ship_interval: float = 10.0
## How long the result stays on the pallet's sign and at the top of the screen.
@export var result_seconds: float = 6.0

## Markers per layer. Marker `i` is stacked on top of marker `i - boxes_per_layer`.
@export var boxes_per_layer: int = 4

var _slots: Array[Marker3D] = []
## Same length as `_slots`; null where the slot is free.
var _boxes: Array[Box] = []
## Height of the top of the box in each slot (pallet-local), so boxes of any
## height can be stacked on each other.
var _tops: Array[float] = []

## How many boxes fit.
var capacity: int:
	get:
		return _slots.size()


var _time_left: float = 0.0
var _result_time_left: float = 0.0

@onready var _timer_label: Label3D = $TimerLabel
@onready var _result_label: Label3D = $ResultLabel


func _ready() -> void:
	_time_left = ship_interval
	_result_label.visible = false
	for child in $Slots.get_children():
		if child is Marker3D:
			_slots.append(child)
			_boxes.append(null)
			_tops.append(0.0)


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		_ship()
	_timer_label.text = "Shipping in %d s  (%d boxes)" % [ceili(_time_left), get_boxes().size()]
	if _result_label.visible:
		_result_time_left -= delta
		_result_label.visible = _result_time_left > 0.0


## Removes every box from the pallet and checks each one against the bill
## attached to it: correct if the contents are exactly what that order asks for.
## A box with no bill, or the wrong contents, is wrong.
func _ship() -> void:
	_time_left = ship_interval
	var boxes := get_boxes()
	if boxes.is_empty():
		return
	var correct := 0
	var wrong := 0
	var lines: PackedStringArray = []
	for box in boxes:
		var order := box.attached_order
		if order == null:
			wrong += 1
			lines.append("A box with no bill: WRONG")
			GameState.order_shipped(null, false)
		elif order.completed:
			wrong += 1
			lines.append("Order #%d was already shipped: WRONG" % order.number)
			GameState.order_shipped(order, false)
		elif order.matches(box.contents):
			order.completed = true
			order.correct = true
			correct += 1
			GameState.order_shipped(order, true)
			lines.append("Order #%d: CORRECT  (multiplier x%.2f)" % [order.number, GameState.multiplier])
		else:
			order.completed = true
			wrong += 1
			GameState.order_shipped(order, false)
			lines.append("Order #%d: WRONG contents  (multiplier reset)" % order.number)
		# Take it off the pallet and out of the game.
		var index := _boxes.find(box)
		_boxes[index] = null
		box.placed_on = null
		box.queue_free()
		box_removed.emit(box)
	var text := "SHIPPED %d box(es): %d correct, %d wrong\n%s" % [
			boxes.size(), correct, wrong, "\n".join(lines)]
	_show_result(text)
	shipped.emit(correct, wrong)


func _show_result(text: String) -> void:
	_result_label.text = text
	_result_label.visible = true
	_result_time_left = result_seconds
	for p in get_tree().get_nodes_in_group("players"):
		(p as Player).hud.show_message(text, result_seconds)


## All boxes currently on the pallet.
func get_boxes() -> Array[Box]:
	var result: Array[Box] = []
	for box in _boxes:
		if box != null:
			result.append(box)
	return result


func _free_slot() -> int:
	for i in _boxes.size():
		if _boxes[i] == null:
			return i
	return -1


## Why the carried box can't go on (empty string = it can).
func _reject_reason(box: Box) -> String:
	if box == null:
		return "Carry a closed box to place it here"
	if box.is_open:
		return "Close the box first [F]"
	if _free_slot() == -1:
		return "Pallet is full"
	return ""


## Puts `box` (which must be closed) on the next free slot. Returns success.
func place(box: Box) -> bool:
	if _reject_reason(box) != "":
		return false
	var index := _free_slot()
	_boxes[index] = box
	# Bottom layer: sit on the pallet. Upper layers: sit on top of the box below
	# (whatever its height), falling back to the marker's own height.
	var marker_y := _slots[index].position.y
	var y := marker_y
	var below := index - boxes_per_layer
	if below >= 0 and _boxes[below] != null:
		y = _tops[below]
	box.on_placed(_slots[index], self)
	box.position.y = y - marker_y
	_tops[index] = y + box.stack_height
	box_placed.emit(box)
	return true


## True when `box` isn't underneath another box.
func can_release(box: Box) -> bool:
	var index := _boxes.find(box)
	if index == -1:
		return true
	var above := index + boxes_per_layer
	return above >= _boxes.size() or _boxes[above] == null


## Called by the box itself when the player picks it up off the pallet.
func release(box: Box) -> void:
	var index := _boxes.find(box)
	if index != -1:
		_boxes[index] = null
		box_removed.emit(box)


# ---- Interaction ------------------------------------------------------------

func can_interact(who: Node) -> bool:
	return (who as Player).carried != null


func get_prompt(who: Node) -> String:
	var reason := _reject_reason((who as Player).carried)
	if reason != "":
		return reason
	return "Place box on pallet (%d/%d)" % [get_boxes().size() + 1, capacity]


func interact(who: Node) -> void:
	var player := who as Player
	if place(player.carried):
		player.release_held()
		super(who)
