class_name DanceFloor
extends Interactable
## The club's dance floor: click to dance for a few seconds. It costs a little energy,
## and now and then you win the dance-off. The tiles flash with colour.

@export var floor_size: Vector2 = Vector2(6.0, 6.0)
@export var duration: float = 8.0
@export var energy_rate: float = -1.0
@export_range(0.0, 1.0) var dance_off_chance: float = 0.15
@export var dance_off_prize: int = 150

## Glowing tiles on or off (the club switches them off while it is closed).
var lit: bool = true

var _tiles: Array[MeshInstance3D] = []
var _time: float = 0.0


func _ready() -> void:
	# The solid floor you aim at, and a grid of glowing tiles on top of it.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(floor_size.x, 0.2, floor_size.y)
	shape.shape = box
	shape.position.y = 0.05  # a hair above the club's floor, so aiming hits the dance floor
	add_child(shape)
	var columns := int(floor_size.x / 1.0)
	var rows := int(floor_size.y / 1.0)
	for i in columns:
		for j in rows:
			var tile := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.96, 0.04, 0.96)
			tile.mesh = mesh
			tile.material_override = StandardMaterial3D.new()
			tile.position = Vector3(-floor_size.x / 2.0 + 0.5 + i, 0.17, -floor_size.y / 2.0 + 0.5 + j)
			add_child(tile)
			_tiles.append(tile)
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	for k in _tiles.size():
		var material := _tiles[k].material_override as StandardMaterial3D
		if not lit:
			material.albedo_color = Color(0.12, 0.11, 0.15)
			material.emission_enabled = false
			continue
		var color := Color.from_hsv(fposmod(_time * 0.25 + k * 0.07, 1.0), 0.8, 1.0)
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.5 + 0.5 * sin(_time * 4.0 + k)


func can_interact(who: Node) -> bool:
	return not GameState.on_shift and not (who as Player).busy


func get_prompt(_who: Node) -> String:
	return "Dance!"


func interact(who: Node) -> void:
	(who as Player).start_activity(&"dancing", duration, energy_rate, _done)
	GameState.notice.emit("You dance like nobody is watching. Everybody is watching.")
	super(who)


func _done() -> void:
	Stats.add(&"dances")
	if randf() < dance_off_chance:
		GameState.add_money(dance_off_prize)
		GameState.notice.emit("You won the dance-off! +$%d" % dance_off_prize)
	else:
		GameState.notice.emit("Great moves. Nobody noticed.")
