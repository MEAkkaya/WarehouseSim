class_name TownLake
extends MeshInstance3D
## A lake: a flat disc (CylinderMesh, radius 1) that you move and scale in the editor
## (Scale x / z = the two radii in metres). At game start TownBuilder reads it: houses and
## trees keep away, an invisible fence runs round the shore, the map draws it.
## A lake with `beach` gets a sand shore (its own sand disc node next to it) and no reeds.

@export var beach: bool = false


## Centre on the ground (x, z).
func get_center() -> Vector2:
	return Vector2(global_position.x, global_position.z)


## The two radii in metres (along x and along z).
func get_radius() -> Vector2:
	var base := 1.0
	if mesh is CylinderMesh:
		base = (mesh as CylinderMesh).top_radius
	return Vector2(global_transform.basis.x.length(), global_transform.basis.z.length()) * base
