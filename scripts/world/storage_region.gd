class_name StorageRegion
extends Node3D
## One region of the storeroom (X, Y or Z): rows of free-standing boltless
## shelves forming parallel corridors, generated when the scene starts.
##
## LAYOUT (this node's origin = the south end of the first shelf row, on the
## floor; corridors run away from it along -Z, i.e. "north"):
##
##   [row] corridor A [row][row] corridor B [row][row] corridor C [row]
##
## Between two corridors the shelves stand back to back, so every corridor has a
## shelf row on each side. Walking north into a corridor, the LEFT side holds the
## odd columns and the RIGHT side the even columns; columns grow as you walk
## further in:
##
##        north end
##    05 [ corridor ] 06
##    03 [  walk n  ] 04
##    01 [          ] 02
##       left    right
##        south (entrance)
##
## Every column is a stack of shelf layers. SHELF ID = region + corridor letter +
## column + level (level 1 = bottom), e.g. "XC 04 03" = region X, corridor C,
## 4th column (right side), 3rd layer from the bottom.
## The shelves are created empty; later the game assigns an item per ID.

## Region letter used in shelf IDs ("X", "Y" or "Z").
@export var region_letter: String = "X"
## How many corridors (lettered A, B, C ...). 5-10 is the intended range.
@export_range(1, 10) var corridor_count: int = 5
## Letter the corridors from the last one (the far end of the row of corridors) back to the
## first: the Y room is entered from the east, so its corridor A is the east one.
@export var reverse_letters: bool = false
## Shelf columns on EACH side of a corridor (so a corridor has twice this many).
@export var columns_per_side: int = 5
## Shelf layers stacked above each other (the maximum when `random_levels` is on).
@export var levels: int = 4
## Give every stack a random height between `min_levels` and `levels`, new every
## visit. This makes the storeroom a parkour course.
@export var random_levels: bool = false
@export var min_levels: int = 1
## Stack rows that are guaranteed to form a climbable staircase (1 layer, then up
## by at most one layer per column, to 4), new every visit: (corridor, side) pairs
## where side 0 = left row and 1 = right row. They lead up to the second floor.
@export var staircase_rows: Array[Vector2i] = []
## Free walking width between the two shelf rows of a corridor, in metres.
@export var aisle_width: float = 1.6
@export var shelf_scene: PackedScene = preload("res://scenes/props/shelf.tscn")

## Every shelf of this region by ID ("XC 04 03"), for assigning items later.
var shelves: Dictionary = {}

# Number of layers of every stack: Vector3i(corridor, side, depth) -> layers.
var _heights: Dictionary = {}

## Distance between the backs of the two shelf rows around one corridor.
var pitch: float:
	get:
		return aisle_width + 2.0 * Shelf.DEPTH
## Length of every corridor.
var corridor_length: float:
	get:
		return columns_per_side * Shelf.LENGTH
## Total width of the region.
var region_width: float:
	get:
		return corridor_count * pitch
## Height of the top of the shelf stacks.
var stack_top: float:
	get:
		return Shelf.FIRST_LEVEL_Y + levels * Shelf.LEVEL_HEIGHT


## True once every shelf of this region exists (they are created over several frames).
var is_built: bool = false
signal built

var _queue: LoadQueue = null


func _ready() -> void:
	add_to_group("storage_regions")  # the visit generator finds regions through this group
	# The warehouse interior has a LoadQueue; without one (a lone region in a test
	# scene) everything is built at once.
	_queue = get_parent().get_node_or_null("LoadQueue") as LoadQueue
	_plan_heights()
	for corridor in corridor_count:
		_build_corridor(corridor)
	var sign_label := _make_label("SHELVES %s" % region_letter, 0.012, 72)
	sign_label.position = Vector3(region_width / 2.0, stack_top + 1.2, 0.0)
	add_child(sign_label)
	_queue_task(_mark_built)


func _mark_built() -> void:
	is_built = true
	built.emit()


## Runs now, or later through the load queue.
func _queue_task(task: Callable) -> void:
	if _queue != null:
		_queue.enqueue(task)
	else:
		task.call()


## "XC 04 03"
func make_shelf_id(corridor: int, column: int, level: int) -> String:
	return "%s%s %02d %02d" % [region_letter, corridor_letter(corridor), column, level]


## The letter of corridor number `corridor` (0 = the first one in the region's own X direction).
func corridor_letter(corridor: int) -> String:
	return char(65 + (corridor_count - 1 - corridor if reverse_letters else corridor))


func get_shelf(id: String) -> Shelf:
	return shelves.get(id) as Shelf


## Decides how many layers every stack has. Every visit is different; the rows in
## `staircase_rows` always contain a way up (1, then +1 at most per column).
func _plan_heights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for corridor in corridor_count:
		for side in 2:
			for depth in columns_per_side:
				var count := levels
				if random_levels:
					count = rng.randi_range(min_levels, levels)
				_heights[Vector3i(corridor, side, depth)] = count
	for row in staircase_rows:
		var steps: Array[int] = []
		var h := 1
		for depth in columns_per_side:
			steps.append(h)
			h = clampi(h + [-1, 0, 1, 1][rng.randi() % 4], 1, levels)
		if steps.max() < levels:  # the random walk never got high enough: use a plain staircase
			for depth in columns_per_side:
				steps[depth] = mini(depth + 1, levels)
		if rng.randf() < 0.5:
			steps.reverse()  # start from the other end of the corridor
		for depth in columns_per_side:
			_heights[Vector3i(row.x, row.y, depth)] = steps[depth]


func _build_corridor(corridor: int) -> void:
	# Sign over the entrance: "XC".
	var sign_label := _make_label("%s%s" % [region_letter, corridor_letter(corridor)], 0.008, 64)
	sign_label.position = Vector3(corridor * pitch + pitch / 2.0, stack_top + 0.4, 0.3)
	add_child(sign_label)

	# The left row's back is at the corridor's left edge, the right row's back at
	# its right edge; shelf origins are at their centres.
	var left_x := corridor * pitch + Shelf.DEPTH / 2.0
	var right_x := (corridor + 1) * pitch - Shelf.DEPTH / 2.0
	for depth in columns_per_side:
		var z := -(depth + 0.5) * Shelf.LENGTH
		for level in range(1, int(_heights[Vector3i(corridor, 0, depth)]) + 1):
			var y := Shelf.FIRST_LEVEL_Y + Shelf.LEVEL_HEIGHT * (level - 1)
			# Left side = odd columns. A shelf's front is +Z, so turning it +90
			# degrees about Y makes it face +X, into the aisle.
			_queue_task(_add_shelf.bind(make_shelf_id(corridor, 2 * depth + 1, level), Vector3(left_x, y, z), 90.0))
		for level in range(1, int(_heights[Vector3i(corridor, 1, depth)]) + 1):
			var y := Shelf.FIRST_LEVEL_Y + Shelf.LEVEL_HEIGHT * (level - 1)
			# Right side = even columns, facing -X.
			_queue_task(_add_shelf.bind(make_shelf_id(corridor, 2 * depth + 2, level), Vector3(right_x, y, z), -90.0))


func _add_shelf(id: String, at: Vector3, yaw_degrees: float) -> void:
	var shelf := shelf_scene.instantiate() as Shelf
	shelf.name = id.replace(" ", "_")
	shelf.shelf_id = id
	shelf.initial_stock = 0  # empty for now; the visit generator stocks them
	shelf.position = at
	shelf.rotation_degrees.y = yaw_degrees
	add_child(shelf)
	shelves[id] = shelf


func _make_label(text: String, pixel_size: float, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = pixel_size
	label.font_size = font_size
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return label
