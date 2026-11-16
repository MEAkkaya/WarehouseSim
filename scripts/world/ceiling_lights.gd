class_name CeilingLights
extends Node3D
## Ceiling lights for the roofed warehouse: a grid of lamps in every room (see
## WarehouseLayout.LIGHT_ROOMS). They are one node in the world scene, so the building is lit
## whether or not the interior is loaded. They go out during a power outage (the event
## sets GameState.blackout).

## Distance between two lamps and how far they reach, in metres.
@export var spacing: float = 8.0
@export var light_range: float = 10.0
@export var energy: float = 0.9

var _lamps: Array[OmniLight3D] = []


func _ready() -> void:
	var panel_material := ApartmentKit.material(Color(1.0, 0.97, 0.85), 2.0)
	var y := WarehouseLayout.CEILING - 0.25
	for room in WarehouseLayout.LIGHT_ROOMS:
		var columns := maxi(1, roundi(room.size.x / spacing))
		var rows := maxi(1, roundi(room.size.y / spacing))
		for i in columns:
			for j in rows:
				var at := Vector3(room.position.x + (i + 0.5) * room.size.x / columns, y,
						room.position.y + (j + 0.5) * room.size.y / rows)
				var lamp := OmniLight3D.new()
				lamp.position = at
				lamp.light_energy = energy
				lamp.light_color = Color(1.0, 0.96, 0.88)
				lamp.omni_range = light_range
				lamp.shadow_enabled = false
				add_child(lamp)
				_lamps.append(lamp)
				# The visible lamp: a flat bright panel.
				var panel := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				mesh.size = Vector3(1.6, 0.06, 0.5)
				mesh.material = panel_material
				panel.mesh = mesh
				panel.position = at + Vector3(0, 0.2, 0)
				add_child(panel)
	set_process(true)


func _process(_delta: float) -> void:
	var on := not (GameState.blackout and GameState.on_shift)
	if visible != on:
		visible = on
