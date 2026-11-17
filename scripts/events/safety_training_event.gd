extends WarehouseEvent
## Workplace Safety Training: the two doors from the corridor into the shelf rooms (Z and X)
## are guarded by an obstacle course. A rotating barrier sweeps the approach and a giant
## pendulum knocks you back; time your run, and carry your packages through it.

## x of the doors (centre), the wall they are in (z), and where the course stands.
const DOOR_X: Array[float] = [16.75, 45.75]
const WALL_Z := 2.0

const BLOCK_COLOR := Color(0.9, 0.2, 0.2)


func _start() -> void:
	for x in DOOR_X:
		_sign(x)
		_build_course(x)


## A warning sign over the door.
func _sign(x: float) -> void:
	var label := PaperLabel.new()
	label.text = "SAFETY TRAINING\nWATCH THE BARRIER"
	label.pixel_size = 0.006
	label.modulate = BLOCK_COLOR
	label.position = Vector3(x, 3.4, WALL_Z + 0.3)
	label.font_size = 56
	add_to_interior(label)


## A rotating barrier in the lane in front of the door and a pendulum swinging across it.
func _build_course(x: float) -> void:
	var bar := RotatingBar.new()
	bar.setup(3.4, Color(0.9, 0.3, 0.2))
	bar.position = Vector3(x, 0.55, 6.0)
	add_to_interior(bar)
	var pendulum := Pendulum.new()
	pendulum.arm_length = 4.9
	pendulum.ball_radius = 0.7
	pendulum.amplitude = 0.8
	pendulum.period = 3.6
	pendulum.hit_mode = Pendulum.Hit.KNOCK_BACK
	pendulum.swing_about_z = true
	pendulum.position = Vector3(x, WarehouseLayout.CEILING - 0.05, 4.6)
	pendulum.build()
	add_to_interior(pendulum)
