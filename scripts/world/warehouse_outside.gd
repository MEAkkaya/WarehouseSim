class_name WarehouseOutside
extends Node3D
## The area outside the warehouse: the plaza in front of the main door, the parking lot
## beside it (with a few parked cars) and the loading yard south of the corridor (the
## trucks and the robot are in LoadingYard). All flat grey-box pieces, built in code from the
## numbers below - replace them with models whenever you have them.

const G := TownLayout.GROUND_TOP

## Rectangles (x, z) of the paved areas.
const PLAZA := Rect2(-3.5, 10.0, 13.5, 18.0)
const PARKING := Rect2(-15.0, 10.0, 11.5, 18.0)
const YARD := Rect2(11.0, 10.0, 32.0, 14.0)

const CAR_COLORS: Array[Color] = [Color(0.8, 0.15, 0.15), Color(0.2, 0.35, 0.75), Color(0.9, 0.85, 0.3), Color(0.25, 0.25, 0.28), Color(0.85, 0.85, 0.88)]


func _ready() -> void:
	_pave(PLAZA, Color(0.5, 0.5, 0.53))
	_pave(PARKING, Color(0.7, 0.7, 0.72))
	_pave(YARD, Color(0.4, 0.4, 0.43))
	_parking_lines()
	_cars()
	# Markings in the loading yard: a yellow line along the truck bay.
	var line := ApartmentKit.box(self, Vector3(WarehouseLayout.TRUCK_BAY.x, G + 0.03, WarehouseLayout.TRUCK_BAY.z + 2.0),
			Vector3(17.5, 0.02, 0.2), Color(0.95, 0.8, 0.15), false)
	line.name = "BayLine"
	ApartmentKit.label(self, "PARKING", Vector3(-9.0, 2.4, 27.5), 0.015, Color.WHITE)
	ApartmentKit.label(self, "LOADING YARD - DELIVERIES", Vector3(27.0, 5.4, 23.9), 0.014, Color(1.0, 0.85, 0.3))


## A flat visual slab on the ground (no collision: you walk on the town's ground).
func _pave(rect: Rect2, color: Color) -> void:
	ApartmentKit.box(self, Vector3(rect.get_center().x, G + 0.012, rect.get_center().y),
			Vector3(rect.size.x, 0.03, rect.size.y), color, false)


## White lines between the parking bays, 3 m apart, a double row of bays.
func _parking_lines() -> void:
	var z := PARKING.position.y + 2.0
	while z < PARKING.end.y - 1.0:
		ApartmentKit.box(self, Vector3(PARKING.position.x + 3.2, G + 0.035, z), Vector3(5.2, 0.02, 0.12), Color.WHITE, false)
		ApartmentKit.box(self, Vector3(PARKING.end.x - 3.2, G + 0.035, z), Vector3(5.2, 0.02, 0.12), Color.WHITE, false)
		z += 3.0


## A few parked cars (boxes with a cabin), nose to the lines.
func _cars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var z := PARKING.position.y + 3.5
	var k := 0
	while z < PARKING.end.y - 2.0:
		for west in [true, false]:
			if rng.randf() < 0.65:
				var x := PARKING.position.x + 3.2 if west else PARKING.end.x - 3.2
				_car(Vector3(x, 0.0, z), CAR_COLORS[k % CAR_COLORS.size()], 1.0 if west else -1.0)
				k += 1
		z += 3.0


func _car(at: Vector3, color: Color, facing: float) -> void:
	var car := StaticBody3D.new()
	car.position = Vector3(at.x, G, at.z)
	add_child(car)
	ApartmentKit.box(car, Vector3(0, 0.55, 0), Vector3(4.2, 0.7, 1.7), color)
	ApartmentKit.box(car, Vector3(-0.2 * facing, 1.15, 0), Vector3(2.2, 0.6, 1.5), color.darkened(0.2))
	ApartmentKit.box(car, Vector3(-0.2 * facing, 1.15, 0), Vector3(2.25, 0.4, 1.55), Color(0.35, 0.5, 0.65), false)
