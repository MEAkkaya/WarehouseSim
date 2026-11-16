extends WarehouseEvent
## Storage Overflow: boxes appear everywhere, in stacks of one to three, turning the
## aisles into a giant maze. Climb the stacks, squeeze through the gaps, and pick
## boxes up and move them to make a path.

const BOX_SCENES: Array[PackedScene] = [
	preload("res://scenes/props/box.tscn"),
	preload("res://scenes/props/box_small.tscn"),
	preload("res://scenes/props/box_big.tscn"),
]
@export var boxes_per_corridor: int = 4
@export var work_floor_stacks: int = 16


func _start() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for region in ground_regions():
		for corridor in region.corridor_count:
			for k in boxes_per_corridor:
				var local := Vector3(
						corridor * region.pitch + region.pitch / 2.0 + rng.randf_range(-0.45, 0.45),
						0.0, -rng.randf_range(0.6, region.corridor_length - 0.6))
				run_later(_make_stack.bind(region.to_global(local), rng))
	for k in work_floor_stacks:
		run_later(_make_stack.bind(random_work_floor_point(rng), rng))


## One to three boxes on top of each other, standing on the floor at `at`.
func _make_stack(at: Vector3, rng: RandomNumberGenerator) -> void:
	var height := at.y
	for level in rng.randi_range(1, 3):
		var box := BOX_SCENES[rng.randi() % BOX_SCENES.size()].instantiate() as Box
		box.start_open = false  # sealed, ready to be carried
		box.position = Vector3(at.x, height if level > 0 else at.y, at.z)
		box.rotation.y = rng.randf_range(-0.4, 0.4)
		add_to_interior(box)
		height += box.stack_height
