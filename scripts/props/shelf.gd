class_name Shelf
extends Interactable
## One layer of the boltless shelving unit (boltlessshelf.glb). It holds one kind of
## product, as INDIVIDUAL items (WorldItem): you aim at one item and take that one.
## The shelf itself is only a place to stand on or climb - you cannot interact with it.
##
## Layers are stacked by placing several shelves above each other, `LEVEL_HEIGHT`
## apart (the storeroom generator does this). Items lie in a grid on the deck
## (`slot_columns` x `slot_rows`); big items (size 3-4) take two grid cells.
##
## The shelf's origin is the CENTRE of its deck; its front faces +Z.

## Fired when an item was taken off (or knocked off) the shelf.
signal stock_changed(new_stock: int)

# Size of the placed model (the .glb at scale 0.5), in metres: how wide the shelf
# is, how deep, the height of one layer, and how high the lowest deck sits above
# the floor. The storeroom generator lays shelves out with these.
const LENGTH := 1.4716
const DEPTH := 1.0
const LEVEL_HEIGHT := 0.512
const FIRST_LEVEL_Y := 0.0351
# Top of the deck above the shelf origin: items stand on this.
const DECK_TOP := 0.026

## Short location code printed on the shelf and on orders, e.g. "A1".
@export var shelf_id: String = "A1"
## The product this shelf holds. Set per shelf instance in the Inspector, or by the
## visit generator.
@export var item: ItemData
## How many items are put on the shelf when it is created.
@export var initial_stock: int = 12
## Item grid on the deck: columns along the shelf, rows front to back, and the
## distance between neighbouring cells in metres.
@export var slot_columns: int = 6
@export var slot_rows: int = 3
@export var slot_spacing: Vector2 = Vector2(0.24, 0.28)

var _slots: Array[Marker3D] = []
var _items: Array[WorldItem] = []

# Shared by every shelf: the lattice material is fixed up once (see _fix_lattice_material).
static var _lattice_fixed: bool = false

@onready var _label: PaperLabel = $Label


## How many items lie on the shelf right now.
var stock: int:
	get:
		return _items.size()

## Most items this shelf can hold of its current product (big items take 2 cells).
var max_stock: int:
	get:
		var cells := slot_columns * slot_rows
		return cells / _cell_cost() if item != null else cells


func _ready() -> void:
	add_to_group("shelves")  # lets the order desk find every shelf
	_fix_lattice_material()
	if item != null:
		_fill(initial_stock)
	_refresh_label()


## Gives the shelf a (new) product and stock at run time. The storeroom's visit
## generator uses this every time the warehouse is entered.
func configure(new_item: ItemData, count: int) -> void:
	_clear_items()
	item = new_item
	_fill(count)
	_refresh_label()
	stock_changed.emit(stock)


## Like configure(), but the items are made by small tasks of the `queue` (one item per
## task), so stocking a whole warehouse never costs a frame more than a fraction of a
## millisecond per piece.
func configure_sliced(new_item: ItemData, count: int, queue: LoadQueue) -> void:
	_clear_items()
	item = new_item
	var cost := _cell_cost()
	# Everything below is a separate small task: the grid markers and the label first
	# (creating them for 600 shelves at once cost 60 ms), then one task per item.
	queue.enqueue(_prepare_for_items)
	for i in clampi(count, 0, slot_rows * slot_columns / cost):
		queue.enqueue(_spawn_item.bind(i, cost))
	queue.enqueue(func() -> void: stock_changed.emit(stock))


func _prepare_for_items() -> void:
	_ensure_slots()
	_refresh_label()


## A shelf is only a platform: nothing to click.
func can_interact(_who: Node) -> bool:
	return false


## An item left the shelf (taken, knocked off, collapsed).
func item_removed(world_item: WorldItem) -> void:
	_items.erase(world_item)
	stock_changed.emit(stock)


## All items currently lying on the shelf.
func get_items() -> Array[WorldItem]:
	return _items


## Big items (size 3-4) take two grid cells, small ones one.
func _cell_cost() -> int:
	return 1 if item.size <= 2 else 2


func _clear_items() -> void:
	for world_item in _items:
		if is_instance_valid(world_item):
			world_item.queue_free()
	_items.clear()


## Creates the grid markers once (they are the same for every product).
func _ensure_slots() -> void:
	if _slots.is_empty():
		var slots_root := Node3D.new()
		slots_root.name = "Slots"
		add_child(slots_root)
		for row in slot_rows:
			for column in slot_columns:
				var marker := Marker3D.new()
				marker.position = Vector3(
						(column - (slot_columns - 1) * 0.5) * slot_spacing.x,
						DECK_TOP,
						(row - (slot_rows - 1) * 0.5) * slot_spacing.y)
				slots_root.add_child(marker)
				_slots.append(marker)


## Creates `count` item bodies on the grid.
func _fill(count: int) -> void:
	if item == null:
		return
	_ensure_slots()
	var cost := _cell_cost()
	count = clampi(count, 0, _slots.size() / cost)
	for i in count:
		_spawn_item(i, cost)


## Puts item number `i` on the grid (each takes `cost` cells).
func _spawn_item(i: int, cost: int) -> void:
	var marker := _slots[i * cost]
	var world_item := WorldItem.new()
	world_item.setup(item, self)
	world_item.position = marker.position
	if cost == 2:  # centre it between its two cells
		world_item.position = (marker.position + _slots[i * cost + 1].position) / 2.0
	world_item.rotation.y = randf_range(-0.12, 0.12)
	add_child(world_item)
	_items.append(world_item)


## The deck texture has see-through holes. Imported as a plain transparent
## material it would sort badly and cast no holey shadows, so switch it to a
## hard cutout ("alpha scissor") once - the mesh is shared by all shelves.
func _fix_lattice_material() -> void:
	if _lattice_fixed:
		return
	for node in $Model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null and material.albedo_texture != null:
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold = 0.5
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_lattice_fixed = true


func _refresh_label() -> void:
	if item != null:
		_label.set_paper_text("%s - %s" % [shelf_id, item.display_name])
	else:
		_label.set_paper_text(shelf_id)
