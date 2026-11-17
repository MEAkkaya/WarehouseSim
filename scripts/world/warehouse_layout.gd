class_name WarehouseLayout
extends RefCounted
## The numbers that describe where things are in the warehouse (metres; x = east, z =
## south, the origin is the middle of the main entrance). The walls themselves are
## CSG boxes in the scenes (scenes/levels/world.tscn: the outer shell, the hall and the
## office; scenes/levels/warehouse.tscn: the walls between the rooms) - you can move them
## in the editor. When you do, check the routes below: supervisors and co-workers walk
## fixed paths, and some events place things on the "work floor".
##
##   z = -31.7 .. -20.9  Y room (north), shelves; a second floor over its two ends
##   z = -20.9 ..   2    Z room (west part) | utility block | X room (east part)
##   z =   2 ..   10     the corridor (reception, boxes, conveyor belt); at its west end
##                       the hall (x -10..10) with the main door and the office behind it
##   x =  59.5 .. 75.5   the extra stock room (restocking crates), reached from the Y room
##                       through a short passage
##
## Outside, south of the corridor: the loading yard (belt end, robot arm, pallet, trucks),
## in front of the hall: the plaza and the parking lot.

## Height of the ceiling (the roof's underside) and of the outer walls.
const CEILING := 6.5
## Top of the second floor (its underside is 20 cm lower).
const SECOND_FLOOR_TOP := 3.4

## The rooms that get ceiling lights (x, z): the hall and office, the corridor, the Z, X and Y
## rooms and the extra stock room.
const LIGHT_ROOMS: Array[Rect2] = [
	Rect2(-10.0, -14.0, 20.0, 24.0), Rect2(10.0, 2.0, 43.5, 8.0), Rect2(10.0, -20.9, 18.5, 22.9),
	Rect2(35.0, -20.9, 18.5, 22.9), Rect2(10.0, -31.7, 43.5, 10.8), Rect2(59.5, -29.0, 16.0, 29.0),
]

## The corridor: the "work floor" where boxes are packed (x, z).
const WORK_FLOOR := Rect2(11.0, 2.6, 41.0, 7.0)

## The conveyor belt: from the packing area west along the corridor, then south through
## a small opening in the corridor's south wall into the loading yard.
const BELT_PATH: Array[Vector3] = [Vector3(30.0, 0.0, 8.6), Vector3(15.0, 0.0, 8.6), Vector3(15.0, 0.0, 12.0)]

## The loading yard outside (the robot arm, the pallet, the truck bay).
const ROBOT_BASE := Vector3(15.0, 0.0, 14.0)
const PALLET_SPOT := Vector3(15.0, 0.0, 16.4)
const TRUCK_BAY := Vector3(24.0, 0.0, 16.4)      ## middle of the cargo area of the truck at the bay (rear to the west)
const TRUCK_QUEUE := Vector3(36.0, 0.0, 21.4)    ## a second truck parked for show

## Rectangles of the work floor that are already used (x, z): the order desk, the belt,
## the box dispensers, the doors to the Z and X rooms.
const WORK_FLOOR_BLOCKED: Array[Rect2] = [
	Rect2(28.4, 4.0, 3.2, 2.4),     # the order desk
	Rect2(13.8, 8.0, 17.6, 1.4),    # the belt along the south wall
	Rect2(14.0, 8.0, 2.4, 2.4),     # where the belt turns south
	Rect2(47.0, 3.4, 5.5, 6.4),     # box dispensers and spare boxes
	Rect2(14.0, 1.8, 6.0, 3.0),     # in front of the door to the Z room
	Rect2(43.0, 1.8, 6.0, 3.0),     # in front of the door to the X room
	Rect2(10.0, 4.0, 2.4, 6.0),     # in front of the warehouse door
]

## The supervisors' patrol loop (a closed path, see SupervisorManager): the corridor, the
## Z room's aisles, the Y room, the X room's aisles and back. They never go to the extra
## stock room (that is where the blind spots are).
const SUPERVISOR_ROUTE: Array[Vector3] = [
	Vector3(12.0, 0.1, 6.8), Vector3(16.75, 0.1, 6.6), Vector3(16.75, 0.1, 0.5), Vector3(11.2, 0.1, 0.5),
	Vector3(11.2, 0.1, -19.9), Vector3(15.25, 0.1, -19.9), Vector3(15.25, 0.1, -21.9),
	Vector3(51.0, 0.1, -21.9), Vector3(51.0, 0.1, -19.9), Vector3(52.0, 0.1, -19.9),
	Vector3(52.0, 0.1, 0.5), Vector3(45.75, 0.1, 0.5), Vector3(45.75, 0.1, 6.6), Vector3(24.0, 0.1, 6.8),
]

## Loops the co-workers walk (clear of the belt, the desk and the dispensers).
const WORK_LOOPS: Array = [
	[Vector3(20.0, 0.1, 5.2), Vector3(27.0, 0.1, 5.2), Vector3(27.0, 0.1, 7.0), Vector3(20.0, 0.1, 7.0)],
	[Vector3(35.0, 0.1, 5.6), Vector3(45.0, 0.1, 5.6), Vector3(45.0, 0.1, 7.6), Vector3(35.0, 0.1, 7.6)],
	[Vector3(21.0, 0.1, -21.9), Vector3(45.0, 0.1, -21.9)],
]
