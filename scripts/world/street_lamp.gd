@tool
class_name StreetLamp
extends MeshInstance3D
## One street lamp you place by hand (the park has some; see scenes/props/street_lamp.tscn).
## Its arm points along the node's local +X, so turn it to face the way you want the light.
## The shape is StreetFixtures.lamp_mesh(); at night the panel shines and a pool of light
## lies on the ground (driven by StreetFurniture, which also lights the generated lamps).

func _ready() -> void:
	mesh = StreetFixtures.lamp_mesh()
	var pool := MeshInstance3D.new()
	pool.name = "LightPool"
	pool.mesh = StreetFixtures.pool_mesh()
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool, false, Node.INTERNAL_MODE_BACK)   # not saved in the scene
