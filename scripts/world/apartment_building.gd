class_name ApartmentBuilding
extends Node3D
## Base of the two hand-made apartment buildings (the one with the gambling room, the
## one with the night club). It builds the shared 3-storey shell: walls, a roof, window
## bands and a light per floor. Origin = the middle of the footprint at ground level;
## +Z is the front (the street side). Subclasses add the rooms in `_build()`.
##
## Inner measures (used by the subclasses): x from -4.2 to 4.2, z from -3.7 to 3.7.

const WIDTH := 9.0
const DEPTH := 8.0
const FLOOR_HEIGHT := 3.3
const FLOORS := 3
const WALL := 0.3
const DOOR_HEIGHT := 2.5

@export var wall_color: Color = Color(0.7, 0.62, 0.55)
## Doorways of the shell: [x_from, x_to] on the front wall (z = +4) and on the back wall.
@export var front_door: Vector2 = Vector2(-0.8, 0.8)
@export var back_door: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_shell()
	_build()


## Overridden by the buildings.
func _build() -> void:
	pass


func _build_shell() -> void:
	var height := FLOOR_HEIGHT * FLOORS
	var front_gaps: Array = [[front_door.x, front_door.y, DOOR_HEIGHT]]
	var back_gaps: Array = []
	if back_door != Vector2.ZERO:
		back_gaps.append([back_door.x, back_door.y, DOOR_HEIGHT])
	var half_w := WIDTH / 2.0
	var half_d := DEPTH / 2.0
	ApartmentKit.wall_x(self, half_d - WALL / 2.0, -half_w, half_w, 0.0, height, WALL, wall_color, front_gaps)
	ApartmentKit.wall_x(self, -half_d + WALL / 2.0, -half_w, half_w, 0.0, height, WALL, wall_color, back_gaps)
	ApartmentKit.wall_z(self, -half_w + WALL / 2.0, -half_d + WALL, half_d - WALL, 0.0, height, WALL, wall_color)
	ApartmentKit.wall_z(self, half_w - WALL / 2.0, -half_d + WALL, half_d - WALL, 0.0, height, WALL, wall_color)
	# Flat roof with a low edge.
	ApartmentKit.box(self, Vector3(0, height + 0.15, 0), Vector3(WIDTH + 0.2, 0.3, DEPTH + 0.2), wall_color.darkened(0.35))
	# Window bands on every floor (only drawn: the glass is part of the model-to-come).
	var glass := Color(0.25, 0.35, 0.5)
	for floor_index in FLOORS:
		var y := floor_index * FLOOR_HEIGHT + 1.9
		if floor_index > 0:
			ApartmentKit.box(self, Vector3(0, y, half_d + 0.02), Vector3(WIDTH - 1.4, 1.1, 0.04), glass, false)
		if floor_index > 0 or back_door == Vector2.ZERO:  # (not across the back door)
			ApartmentKit.box(self, Vector3(0, y, -half_d - 0.02), Vector3(WIDTH - 1.4, 1.1, 0.04), glass, false)
		ApartmentKit.box(self, Vector3(-half_w - 0.02, y, 0), Vector3(0.04, 1.1, DEPTH - 1.4), glass, false)
		ApartmentKit.box(self, Vector3(half_w + 0.02, y, 0), Vector3(0.04, 1.1, DEPTH - 1.4), glass, false)
	# Warm shop window on the ground floor, either side of the door.
	var shop_glow := Color(1.0, 0.85, 0.5)
	var left_width := front_door.x - (-half_w + 0.7)
	var right_width := (half_w - 0.7) - front_door.y
	if left_width > 0.5:
		ApartmentKit.box(self, Vector3((-half_w + 0.7 + front_door.x) / 2.0, 1.4, half_d + 0.02),
				Vector3(left_width - 0.3, 1.5, 0.04), shop_glow, false, 0.6)
	if right_width > 0.5:
		ApartmentKit.box(self, Vector3((half_w - 0.7 + front_door.y) / 2.0, 1.4, half_d + 0.02),
				Vector3(right_width - 0.3, 1.5, 0.04), shop_glow, false, 0.6)
	# A warm light per floor, so the rooms are not pitch black at night.
	for floor_index in FLOORS:
		ApartmentKit.light(self, Vector3(0, floor_index * FLOOR_HEIGHT + 2.7, 0), Color(1.0, 0.9, 0.7), 0.9, 8.0)
