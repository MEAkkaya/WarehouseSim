extends WarehouseEvent
## Demolition Inspection: a giant wrecking ball swings in the corridor, just inside the
## door to the warehouse floor to test the building's structure. Time your movements between
## swings, or you are knocked out and wake up outside.


func _start() -> void:
	var ball := Pendulum.new()
	ball.arm_length = 4.9
	ball.ball_radius = 1.0
	ball.amplitude = 0.95
	ball.period = 4.2
	ball.hit_mode = Pendulum.Hit.KNOCK_OUT
	ball.swing_about_z = true  # swings along X, across the doorway lane
	ball.position = Vector3(15.5, WarehouseLayout.CEILING - 0.05, 7.0)  # just inside the warehouse door
	ball.build()
	add_to_interior(ball)
