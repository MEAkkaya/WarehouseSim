class_name BoxDispenser
extends Interactable
## A pallet with a pile of flat-packed boxes: click with free hands to take one.
## Each box taken shrinks the pile; a timer refills it (a refill animation will
## replace the instant reset later). The pile size is the number of slab meshes
## under the "Stacks" node.

## Fired when the pile is back to full (hook for the refill animation later).
signal refilled

## The box scene to hand out (box.tscn, box_small.tscn or box_big.tscn).
@export var box_scene: PackedScene = preload("res://scenes/props/box.tscn")
## Sign text and the colour of the cardboard stack, so the piles look different.
@export var title: String = "MEDIUM BOXES"
@export var tint: Color = Color(0.72, 0.55, 0.33)
@export var prompt: String = "Take a medium box"
## Seconds after the first box is taken until the pile is full again.
@export var refill_interval: float = 20.0

## Boxes left on the pallet.
var stock: int = 0
## Pile size when full = number of slabs.
var max_stock: int = 0

var _slabs: Array[MeshInstance3D] = []
var _time_left: float = 0.0

@onready var _stock_label: PaperLabel = $StockLabel


func _ready() -> void:
	$Label.text = title
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	for child in $Stacks.get_children():
		if child is MeshInstance3D:
			child.material_override = material
			_slabs.append(child)
	max_stock = _slabs.size()
	stock = max_stock
	_time_left = refill_interval
	_refresh()


func _process(delta: float) -> void:
	if stock >= max_stock:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		refill()
	else:
		_refresh_label()


## Puts the pile back to full.
func refill() -> void:
	stock = max_stock
	_time_left = refill_interval
	_refresh()
	refilled.emit()


func can_interact(who: Node) -> bool:
	return (who as Player).hands_empty()


func get_prompt(_who: Node) -> String:
	if stock <= 0:
		return "Out of boxes - refilling in %d s" % ceili(_time_left)
	return "%s (%d left)" % [prompt, stock]


func interact(who: Node) -> void:
	if stock <= 0:
		return
	var box := box_scene.instantiate() as Box
	box.start_flat = true  # if the model has a `form` animation, it forms in your hands
	# The box must be in the tree before it is picked up (it reparents itself to
	# the player's hand and remembers this parent as its "home" for dropping).
	get_parent().add_child(box)
	box.global_position = global_position
	if stock == max_stock:
		_time_left = refill_interval  # the refill countdown starts with the first box taken
	stock -= 1
	_refresh()
	(who as Player).pick_up(box)
	box.play_form()
	super(who)


## Shows one slab per box left.
func _refresh() -> void:
	for i in _slabs.size():
		_slabs[i].visible = i < stock
	_refresh_label()


func _refresh_label() -> void:
	if stock >= max_stock:
		_stock_label.set_paper_text("%d / %d" % [stock, max_stock])
	else:
		_stock_label.set_paper_text("%d / %d  - refill in %d s" % [stock, max_stock, ceili(_time_left)])
