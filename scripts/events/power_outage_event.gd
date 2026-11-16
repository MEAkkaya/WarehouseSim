extends WarehouseEvent
## Power Outage: the warehouse goes dark. You only see what your flashlight lights.
## (DayNightCycle darkens the world while GameState.blackout is set, and the Player
## switches its flashlight on.)


func _start() -> void:
	GameState.blackout = true


func _stop() -> void:
	GameState.blackout = false
