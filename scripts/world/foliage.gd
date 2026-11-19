class_name Foliage
extends RefCounted
## Gives the LEAF parts of a tree or bush model the foliage shader (assets/shaders/foliage.gdshader):
## normals from the canopy centre and a tiny sway. A part counts as a leaf when its material is
## green; the trunk (brown) is left alone. The canopy centre is the middle of all the leaf parts
## together, and every part gets it in its own space.
##
## Use `apply(model)` on a model that is placed as a scene (tree.tscn does it), or
## `make_materials(model)` to get the materials for a MultiMesh batch (TownScenery, HillForest).
## Materials are shared: every copy of the same mesh gets the same material.

const SHADER := preload("res://assets/shaders/foliage.gdshader")

static var _cache: Dictionary = {}


## A mesh part is a leaf when it has one green material.
static func is_leaf(part: MeshInstance3D) -> bool:
	if part.mesh == null or part.mesh.get_surface_count() != 1:
		return false
	var material := part.mesh.surface_get_material(0) as StandardMaterial3D
	if material == null:
		return false
	var color := material.albedo_color
	return color.g > color.r * 1.15 and color.g > color.b * 1.1


## {MeshInstance3D: ShaderMaterial} for the leaf parts of `model`. `sway` = how far the outer
## leaves move in the whole model's units (metres at scale 1).
static func make_materials(model: Node3D, sway: float = 0.04, normal_blend: float = 0.85) -> Dictionary:
	var leaves: Array[MeshInstance3D] = []
	var bounds := AABB()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if not is_leaf(part):
			continue
		var box := _in_model(model, part) * part.get_aabb()
		bounds = box if leaves.is_empty() else bounds.merge(box)
		leaves.append(part)
	var result := {}
	if leaves.is_empty():
		return result
	var center := bounds.get_center()
	var radius := maxf(bounds.size.x, bounds.size.z) * 0.5
	for part in leaves:
		var to_model := _in_model(model, part)
		var key := "%d_%s_%s" % [part.mesh.get_instance_id(), snappedf(sway, 0.001), snappedf(normal_blend, 0.01)]
		if not _cache.has(key):
			var scale := to_model.basis.get_scale()
			var mean_scale := maxf((scale.x + scale.y + scale.z) / 3.0, 0.0001)
			var original := part.mesh.surface_get_material(0) as StandardMaterial3D
			var material := ShaderMaterial.new()
			material.shader = SHADER
			material.set_shader_parameter("albedo_color", original.albedo_color)
			material.set_shader_parameter("canopy_center", to_model.affine_inverse() * center)
			material.set_shader_parameter("canopy_radius", radius / mean_scale)
			material.set_shader_parameter("sway_amount", sway / mean_scale)
			material.set_shader_parameter("normal_blend", normal_blend)
			_cache[key] = material
		result[part] = _cache[key]
	return result


## Puts the foliage shader on the leaf parts of a model that stands in the scene.
static func apply(model: Node3D, sway: float = 0.04) -> void:
	var materials := make_materials(model, sway)
	for part: MeshInstance3D in materials:
		part.material_override = materials[part]


## The transform of `part` relative to `model` (the model's own transform not included).
static func _in_model(model: Node3D, part: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var walker: Node = part
	while walker != model and walker != null:
		result = (walker as Node3D).transform * result
		walker = walker.get_parent()
	return result
