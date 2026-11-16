extends WarehouseEvent
## Mandatory Exercise Hour: the boss has installed trampolines and treadmills. A
## trampoline throws you into the air; a treadmill is a conveyor belt that carries you
## along while you stand on it - whether you like where it goes or not.

@export var trampolines: int = 7
@export var treadmills: int = 7


func _start() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for k in trampolines:
		_place(BounceZone.Kind.TRAMPOLINE, rng)
	for k in treadmills:
		_place(BounceZone.Kind.TREADMILL, rng)


func _place(kind: BounceZone.Kind, rng: RandomNumberGenerator) -> void:
	var zone := BounceZone.new()
	zone.kind = kind
	if kind == BounceZone.Kind.TREADMILL:
		zone.size = Vector3(1.4, 0.4, 3.0)
		# The belt runs along the Z axis (forward or back), or sideways on the work floor.
		zone.belt_direction = Vector3(0, 0, -1 if rng.randf() < 0.5 else 1)
	# Mostly on the work floor, sometimes in an aisle.
	zone.position = random_work_floor_point(rng) if rng.randf() < 0.6 else random_aisle_point(rng)
	zone.build()
	add_to_interior(zone)
