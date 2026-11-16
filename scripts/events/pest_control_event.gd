extends WarehouseEvent
## Pest Control: giant rats roam the work floor. A box left open on the ground with
## items in it is a snack bar: a rat walks up and steals an item. Refill the box (or
## keep it closed, or off the floor).

@export var rat_count: int = 5


func _start() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for k in rat_count:
		var rat := Rat.new()
		rat.position = random_work_floor_point(rng)
		add_to_interior(rat)
