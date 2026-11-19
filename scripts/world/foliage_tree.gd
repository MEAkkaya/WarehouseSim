class_name FoliageTree
extends StaticBody3D
## The root of scenes/props/tree.tscn: when it enters the game the crown of the tree model gets the foliage
## shader (normals from the canopy centre, a tiny sway). The trunk stays as modelled.

func _ready() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model != null:
		Foliage.apply(model, 0.05)
