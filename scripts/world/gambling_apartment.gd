class_name GamblingApartment
extends ApartmentBuilding
## An apartment block with a corner shop on the ground floor, two floors of flats you
## walk past (locked, nobody answers) and a shady gambling room on the top floor. The
## stairs run up the east side to the second floor and back along the west side to the
## top; the gambling room's door is only unlocked on weekdays.

const OPEN_DAYS: Array[int] = [0, 1, 2, 3, 4]


func _build() -> void:
	var h := FLOOR_HEIGHT
	var slab_color := Color(0.5, 0.46, 0.42)
	var stair_color := Color(0.4, 0.38, 0.36)
	# Second floor: a hole over the first flight, which runs along the east wall...
	ApartmentKit.slab(self, h, 0.25, -4.2, 4.2, -3.7, 3.7, slab_color, Rect2(2.5, -3.0, 1.7, 5.0))
	ApartmentKit.stairs(self, Vector3(3.35, 0.0, 3.2), Vector3(3.35, h, -3.0), 1.7, stair_color)
	# ...third floor: a hole over the second flight, back along the west wall.
	ApartmentKit.slab(self, h * 2.0, 0.25, -4.2, 4.2, -3.7, 3.7, slab_color, Rect2(-4.2, -2.4, 1.7, 4.8))
	ApartmentKit.stairs(self, Vector3(-3.35, h, -3.0), Vector3(-3.35, h * 2.0, 2.2), 1.7, stair_color)
	_build_shop()
	_build_flats()
	_build_gambling_room()
	# The outside sign.
	ApartmentKit.label(self, "LUCKY'S CORNER SHOP", Vector3(0, 3.0, DEPTH / 2.0 + 0.1), 0.012, Color(1.0, 0.9, 0.5))
	ApartmentKit.label(self, "APARTMENTS", Vector3(0, h * 2.0 + 1.9, DEPTH / 2.0 + 0.1), 0.01, Color(0.9, 0.9, 0.95))


func _build_shop() -> void:
	var counter := PurchaseCounter.new()
	counter.title = "CORNER SHOP"
	counter.product = "sandwich"
	counter.price = 8
	counter.energy = 12.0
	counter.stat_key = &"snacks"
	counter.size = Vector3(0.9, 1.1, 3.0)
	counter.position = Vector3(-3.5, 0.0, -1.0)
	add_child(counter)
	# Shelves along the back wall (only drawn).
	for x in [-3.0, -1.2, 0.6]:
		ApartmentKit.box(self, Vector3(x, 0.9, -3.4), Vector3(1.4, 1.8, 0.5), Color(0.55, 0.45, 0.35))


## The second floor: doors of the flats. Nobody opens.
func _build_flats() -> void:
	var y := FLOOR_HEIGHT
	for entry in [["2A", -1.5], ["2B", 0.5]]:
		ApartmentKit.box(self, Vector3(entry[1], y + 1.1, -3.62), Vector3(1.0, 2.2, 0.1), Color(0.3, 0.2, 0.15), false)
		ApartmentKit.label(self, entry[0], Vector3(entry[1], y + 2.5, -3.5), 0.006)
	ApartmentKit.label(self, "Nobody answers.", Vector3(0.0, y + 0.5, -3.4), 0.004, Color(0.8, 0.8, 0.8))


func _build_gambling_room() -> void:
	var y := FLOOR_HEIGHT * 2.0
	var door_top := y + DOOR_HEIGHT
	# The partition between the stairwell and the room, with the doorway.
	ApartmentKit.wall_z(self, -2.35, -3.7, 3.7, y, y + FLOOR_HEIGHT, 0.2, Color(0.25, 0.1, 0.15), [[2.5, 3.6, door_top]])
	var door := TimedDoor.new()
	door.venue_name = "The Back Room"
	door.open_days = OPEN_DAYS
	door.open_from = 0.0
	door.open_to = 24.0
	door.door_size = Vector3(0.15, DOOR_HEIGHT, 1.1)
	door.inside_direction = Vector3(1, 0, 0)
	door.position = Vector3(-2.35, y, 3.05)
	add_child(door)
	# The red-lit room.
	ApartmentKit.light(self, Vector3(1.0, y + 2.6, 0.0), Color(1.0, 0.15, 0.35), 2.2, 9.0)
	ApartmentKit.label(self, "THE BACK ROOM", Vector3(1.0, y + 3.0, -3.55), 0.014, Color(1.0, 0.3, 0.5))
	var machines := [
		["SLOTS", 20, 0.30, 3.0, Vector3(3.7, y, -2.6), Color(0.7, 0.1, 0.35)],
		["SLOTS", 20, 0.30, 3.0, Vector3(3.7, y, -1.3), Color(0.7, 0.1, 0.35)],
		["SLOTS", 20, 0.30, 3.0, Vector3(3.7, y, 0.0), Color(0.7, 0.1, 0.35)],
		["HIGH ROLLER", 1000, 0.45, 2.1, Vector3(3.7, y, 1.5), Color(0.75, 0.6, 0.1)],
	]
	for m in machines:
		var machine := GamblingMachine.new()
		machine.title = m[0]
		machine.bet = m[1]
		machine.win_chance = m[2]
		machine.payout = m[3]
		machine.color = m[5]
		machine.position = m[4]
		add_child(machine)
	var poker := GamblingMachine.new()
	poker.title = "POKER TABLE"
	poker.bet = 100
	poker.win_chance = 0.45
	poker.payout = 2.0
	poker.size = Vector3(2.4, 0.95, 1.4)
	poker.color = Color(0.1, 0.45, 0.2)
	poker.position = Vector3(0.4, y, 0.2)
	add_child(poker)
	var roulette := GamblingMachine.new()
	roulette.title = "ROULETTE (lucky number)"
	roulette.bet = 50
	roulette.win_chance = 0.18
	roulette.payout = 5.0
	roulette.size = Vector3(1.6, 0.95, 1.6)
	roulette.color = Color(0.5, 0.08, 0.08)
	roulette.position = Vector3(0.4, y, -2.4)
	add_child(roulette)
