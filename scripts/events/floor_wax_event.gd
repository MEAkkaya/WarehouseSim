extends WarehouseEvent
## Floor Waxing Day: the whole floor is slippery. You build up momentum, slide round
## corners and struggle to stop - and a heavy box makes it worse (see
## Player._physics_process, which scales the grip by the carried weight).


func _start() -> void:
	player.friction_factor = 0.1


func _stop() -> void:
	player.friction_factor = 1.0
