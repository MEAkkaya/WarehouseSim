class_name ClubApartment
extends ApartmentBuilding
## An apartment block with a record shop on the ground floor and, round the back, a
## plain door. Behind the door a stairwell leads DOWN into an underground dance club.
## The door is unlocked only from Friday to Sunday evenings (see CLUB_HOURS).
##
## The stair shaft is a hole in the town's ground (TownLayout.ground_holes()); the club
## itself is a room built below the ground, with its own ceiling.

## Friday, Saturday and Sunday nights, from 20:00 until 06:00 the next morning.
const OPEN_DAYS: Array[int] = [4, 5, 6]
const OPEN_FROM := 20.0
const OPEN_TO := 6.0

## Level of the club's floor (below the town's ground).
const CLUB_FLOOR := -3.6
const ROOM_X0 := -8.0
const ROOM_X1 := 4.35
const ROOM_Z0 := 3.2
const ROOM_Z1 := 16.0

var _disco_lights: Array[OmniLight3D] = []
## Every light of the club (stairs, door, club room): on only while the club is open.
var _club_lights: Array[OmniLight3D] = []
var _dance_floor: DanceFloor = null
var _hours: OpeningHours = null
var _lit: bool = true
var _check_left: float = 0.0
var _time: float = 0.0


func _init() -> void:
	front_door = Vector2(-1.6, -0.2)
	back_door = Vector2(2.7, 3.9)
	wall_color = Color(0.55, 0.5, 0.58)


func _build() -> void:
	# --- the ground floor: a shop, and the back stairwell closed off from it
	ApartmentKit.wall_z(self, 2.35, -3.7, 3.7, 0.0, FLOOR_HEIGHT, 0.2, Color(0.4, 0.38, 0.42))
	var counter := PurchaseCounter.new()
	counter.title = "RECORD SHOP"
	counter.product = "coffee"
	counter.price = 6
	counter.energy = 10.0
	counter.stat_key = &"snacks"
	counter.size = Vector3(0.9, 1.1, 3.0)
	counter.position = Vector3(-3.5, 0.0, -1.0)
	add_child(counter)
	for x in [-2.6, -0.9]:
		ApartmentKit.box(self, Vector3(x, 0.55, -3.3), Vector3(1.4, 1.1, 0.6), Color(0.3, 0.25, 0.35))
	ApartmentKit.label(self, "RECORD SHOP", Vector3(-0.9, 3.0, DEPTH / 2.0 + 0.1), 0.012, Color(0.8, 0.9, 1.0))
	# --- the back door (the only way to the club)
	var door := TimedDoor.new()
	door.venue_name = "Underground Club"
	door.open_days = OPEN_DAYS
	door.open_from = OPEN_FROM
	door.open_to = OPEN_TO
	door.door_size = Vector3(1.2, DOOR_HEIGHT, 0.15)
	door.inside_direction = Vector3(0, 0, 1)
	door.position = Vector3(3.3, 0.0, -DEPTH / 2.0 + WALL / 2.0)
	add_child(door)
	_club_lights.append(ApartmentKit.light(self, Vector3(3.3, 3.0, -DEPTH / 2.0 - 0.6), Color(1.0, 0.2, 0.6), 1.6, 6.0))
	# Bins and a crate in the yard behind the building.
	ApartmentKit.box(self, Vector3(0.5, 0.6, -5.6), Vector3(1.6, 1.2, 0.9), Color(0.2, 0.35, 0.25))
	ApartmentKit.box(self, Vector3(-1.6, 0.4, -6.2), Vector3(1.0, 0.8, 1.0), Color(0.45, 0.35, 0.2))
	# --- the stairs down
	ApartmentKit.stairs(self, Vector3(3.35, 0.0, -2.6), Vector3(3.35, CLUB_FLOOR, 3.2), 1.7, Color(0.3, 0.3, 0.34))
	_club_lights.append(ApartmentKit.light(self, Vector3(3.35, -1.0, 0.0), Color(0.9, 0.2, 0.8), 1.2, 6.0))
	_build_club()
	# The lights follow the opening hours (they start off, `_process` switches them on).
	_hours = OpeningHours.make(OPEN_DAYS, OPEN_FROM, OPEN_TO)
	_set_lit(false)


## The club: floor, ceiling, walls, a bar, a DJ booth and the dance floor.
func _build_club() -> void:
	var dark := Color(0.14, 0.12, 0.2)
	var top := -0.2   # the underside of the town's ground
	var height := top - CLUB_FLOOR
	var mid_y := (top + CLUB_FLOOR) / 2.0
	# Floor under the shaft and the room, ceiling over the room.
	ApartmentKit.slab(self, CLUB_FLOOR, 0.3, ROOM_X0, ROOM_X1, -2.7, ROOM_Z1, dark)
	ApartmentKit.slab(self, top - 0.05, 0.25, ROOM_X0, ROOM_X1, ROOM_Z0, ROOM_Z1, dark)
	# Walls of the room (the opening to the shaft stays free on the east side)...
	ApartmentKit.wall_x(self, ROOM_Z0, ROOM_X0, 2.4, CLUB_FLOOR, top, 0.2, dark)
	ApartmentKit.wall_x(self, ROOM_Z1, ROOM_X0, ROOM_X1, CLUB_FLOOR, top, 0.2, dark)
	ApartmentKit.wall_z(self, ROOM_X0, ROOM_Z0, ROOM_Z1, CLUB_FLOOR, top, 0.2, dark)
	ApartmentKit.wall_z(self, ROOM_X1, ROOM_Z0, ROOM_Z1, CLUB_FLOOR, top, 0.2, dark)
	# ...and the walls of the shaft.
	ApartmentKit.wall_z(self, 2.4, -2.7, ROOM_Z0, CLUB_FLOOR, top, 0.2, dark)
	ApartmentKit.wall_z(self, 4.3, -2.7, ROOM_Z0, CLUB_FLOOR, top, 0.2, dark)
	ApartmentKit.wall_x(self, -2.7, 2.4, 4.3, CLUB_FLOOR, top, 0.2, dark)
	# The dance floor.
	var dance := DanceFloor.new()
	dance.position = Vector3(-2.0, CLUB_FLOOR - 0.1, 9.5)
	add_child(dance)
	_dance_floor = dance
	# The bar along the west wall.
	var bar := PurchaseCounter.new()
	bar.title = "BAR"
	bar.product = "drink"
	bar.price = 12
	bar.energy = 25.0
	bar.stat_key = &"drinks"
	bar.size = Vector3(1.0, 1.1, 5.0)
	bar.color = Color(0.35, 0.2, 0.12)
	bar.position = Vector3(-7.2, CLUB_FLOOR, 9.5)
	add_child(bar)
	# The DJ booth and speakers by the south wall.
	ApartmentKit.box(self, Vector3(-2.0, CLUB_FLOOR + 0.6, 15.2), Vector3(3.0, 1.2, 1.0), Color(0.1, 0.1, 0.12))
	ApartmentKit.label(self, "DJ NOBODY", Vector3(-2.0, CLUB_FLOOR + 2.2, 15.2), 0.008, Color(0.4, 1.0, 0.9), true)
	for x in [-6.0, 2.0]:
		ApartmentKit.box(self, Vector3(x, CLUB_FLOOR + 0.95, 15.3), Vector3(1.0, 1.9, 0.8), Color(0.08, 0.08, 0.1))
	ApartmentKit.label(self, "UNDERGROUND", Vector3(-3.0, mid_y + 0.6, ROOM_Z0 + 0.15), 0.02, Color(1.0, 0.3, 0.8))
	# Disco lights.
	for k in 3:
		_disco_lights.append(ApartmentKit.light(self, Vector3(-6.0 + k * 4.0, top - 0.8, 9.5), Color.WHITE, 2.0, 8.0))
	_club_lights.append_array(_disco_lights)
	_club_lights.append(ApartmentKit.light(self, Vector3(0.0, mid_y, 5.0), Color(0.5, 0.4, 0.9), 0.8, 8.0))


## Lights (and the dance floor's glowing tiles) on or off.
func _set_lit(lit: bool) -> void:
	_lit = lit
	for light in _club_lights:
		light.visible = lit
	if _dance_floor != null:
		_dance_floor.lit = lit


func _process(delta: float) -> void:
	_time += delta
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = 0.5
		var open := _hours.is_open_now()
		if open != _lit:
			_set_lit(open)
	for k in _disco_lights.size():
		_disco_lights[k].light_color = Color.from_hsv(fposmod(_time * 0.2 + k * 0.33, 1.0), 0.9, 1.0)
