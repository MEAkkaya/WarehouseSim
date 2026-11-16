extends WarehouseEvent
## Security Upgrade: lasers are installed across the aisles. Low beams must be jumped,
## high beams crawled under (crouch), or climb over the shelves instead. Touching a
## beam - with your body or with the box you carry - sets off the alarm: your
## multiplier is lost and the supervisors come running.

const BEAM_HEIGHTS: Array[float] = [0.35, 0.8, 1.55, 1.7]
const COOLDOWN := 4.0

# Each beam: {from: Vector3, to: Vector3} in world coordinates (a horizontal segment).
var _beams: Array[Dictionary] = []
var _cooldown: float = 0.0
var _material: StandardMaterial3D


func _start() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.1, 0.1)
	_material.emission_enabled = true
	_material.emission = Color(1.0, 0.1, 0.1)
	_material.emission_energy_multiplier = 3.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for region in ground_regions():
		for corridor in region.corridor_count:
			var x_centre := corridor * region.pitch + region.pitch / 2.0
			var half_width := region.aisle_width / 2.0
			for k in 2:
				# Two beams per aisle, on different columns, at different heights.
				var depth := rng.randi_range(1, region.columns_per_side - 1) if k == 0 else rng.randi_range(0, 1)
				var z := -(depth + 0.5) * Shelf.LENGTH
				var y := BEAM_HEIGHTS[rng.randi() % BEAM_HEIGHTS.size()]
				var start := region.to_global(Vector3(x_centre - half_width, y + 0.1, z))
				var finish := region.to_global(Vector3(x_centre + half_width, y + 0.1, z))
				_make_beam(start, finish)


func _make_beam(from: Vector3, to: Vector3) -> void:
	_beams.append({"from": from, "to": to})
	var beam := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(from.distance_to(to), 0.025, 0.025)
	mesh.material = _material
	beam.mesh = mesh
	beam.position = (from + to) / 2.0
	add_to_interior(beam)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0 or player == null or not GameState.on_shift:
		return
	var shape := player.get_node("CollisionShape3D") as CollisionShape3D
	var capsule := shape.shape as CapsuleShape3D
	var feet := player.global_position.y + capsule.radius
	var head := player.global_position.y + capsule.height - capsule.radius
	var box_point := Vector3.ZERO
	var has_box := player.carried != null
	if has_box:
		box_point = player.carried.global_position + Vector3.UP * player.carried.stack_height * 0.5
	for beam in _beams:
		var from: Vector3 = beam.from
		var to: Vector3 = beam.to
		# The body: the beam must cross the vertical axis of the capsule (with its radius).
		var dz := absf(player.global_position.z - from.z)
		if dz < capsule.radius and player.global_position.x >= from.x - capsule.radius \
				and player.global_position.x <= to.x + capsule.radius:
			var reach := sqrt(maxf(0.0, capsule.radius * capsule.radius - dz * dz))
			if from.y >= feet - reach and from.y <= head + reach:
				_alarm("your body touched a laser")
				return
		# The carried box.
		if has_box and absf(box_point.z - from.z) < 0.3 and box_point.x >= from.x - 0.3 \
				and box_point.x <= to.x + 0.3 and absf(box_point.y - from.y) < 0.3:
			_alarm("the box you carry touched a laser")
			return


func _alarm(reason: String) -> void:
	_cooldown = COOLDOWN
	GameState.multiplier = 1.0
	GameState.multiplier_changed.emit(GameState.multiplier, GameState.shift_earnings)
	GameState.notice.emit("ALARM! %s. Multiplier lost - the supervisors are coming!" % reason.capitalize())
	var manager := interior.get_node_or_null("SupervisorManager") as SupervisorManager
	if manager != null:
		manager.alert_all()
