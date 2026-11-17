@tool
class_name StreetFixtures
extends RefCounted
## The shapes of the street furniture, built from simple boxes and cylinders (no models):
## the street lamp, the utility pole (with its cable attach points) and the pool of light
## under a lamp. Shared by the street generator (StreetFurniture) and by hand-placed lamps
## (StreetLamp). If you make a model of a lamp or a pole, use it in place of these.
##
## All shapes stand on y = 0 with the lamp's arm pointing along +X.

## Height of a street lamp and of a utility pole, in metres.
const LAMP_HEIGHT := 6.0
const POLE_HEIGHT := 9.0
## Where the lamp's light shines (its head), measured from the pole along +X.
const LAMP_REACH := 1.5
## Where a pole's three cables hang (local to the pole; the crossarm runs along X).
const POLE_ATTACH: Array[Vector3] = [Vector3(-0.9, 8.6, 0.0), Vector3(0.9, 8.6, 0.0), Vector3(0.0, 9.05, 0.0)]

static var _lamp_mesh: ArrayMesh = null
static var _pole_mesh: ArrayMesh = null
static var _pool_mesh: ArrayMesh = null
static var _metal: StandardMaterial3D = null
static var _wood: StandardMaterial3D = null
static var _glow: StandardMaterial3D = null
static var _pool: StandardMaterial3D = null


## The street lamp: pole, arm and housing (surface 0, metal) and the lit panel (surface 1).
static func lamp_mesh() -> ArrayMesh:
	if _lamp_mesh == null:
		_lamp_mesh = ArrayMesh.new()
		var metal := _begin()
		_cylinder(metal, 0.15, 0.15, 0.5, Vector3(0, 0.25, 0))
		_cylinder(metal, 0.09, 0.06, LAMP_HEIGHT, Vector3(0, LAMP_HEIGHT / 2.0, 0))
		_box(metal, Vector3(LAMP_REACH, 0.07, 0.07), Vector3(LAMP_REACH / 2.0, LAMP_HEIGHT - 0.05, 0))
		_box(metal, Vector3(0.75, 0.12, 0.32), Vector3(LAMP_REACH, LAMP_HEIGHT - 0.08, 0))
		metal.commit(_lamp_mesh)
		_lamp_mesh.surface_set_material(0, metal_material())
		var glow := _begin()
		_box(glow, Vector3(0.6, 0.03, 0.24), Vector3(LAMP_REACH, LAMP_HEIGHT - 0.155, 0))
		glow.commit(_lamp_mesh)
		_lamp_mesh.surface_set_material(1, glow_material())
	return _lamp_mesh


## A wooden utility pole with two crossarms and insulators.
static func pole_mesh() -> ArrayMesh:
	if _pole_mesh == null:
		_pole_mesh = ArrayMesh.new()
		var wood := _begin()
		_cylinder(wood, 0.16, 0.11, POLE_HEIGHT, Vector3(0, POLE_HEIGHT / 2.0, 0))
		_box(wood, Vector3(2.2, 0.12, 0.12), Vector3(0, 8.45, 0))
		_box(wood, Vector3(1.5, 0.1, 0.1), Vector3(0, 7.7, 0))
		wood.commit(_pole_mesh)
		_pole_mesh.surface_set_material(0, wood_material())
		var steel := _begin()
		for attach in POLE_ATTACH:
			_cylinder(steel, 0.05, 0.03, 0.16, attach - Vector3(0, 0.06, 0))
		steel.commit(_pole_mesh)
		_pole_mesh.surface_set_material(1, metal_material())
	return _pole_mesh


## A soft disc of light on the ground, centred under the lamp's head (shown only at night).
static func pool_mesh() -> ArrayMesh:
	if _pool_mesh == null:
		_pool_mesh = ArrayMesh.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(9.0, 9.0)
		var pool := _begin()
		pool.append_from(plane, 0, Transform3D(Basis(), Vector3(LAMP_REACH, 0.045, 0.0)))
		pool.commit(_pool_mesh)
		_pool_mesh.surface_set_material(0, pool_material())
	return _pool_mesh


static func metal_material() -> StandardMaterial3D:
	if _metal == null:
		_metal = StandardMaterial3D.new()
		_metal.albedo_color = Color(0.2, 0.21, 0.23)
		_metal.roughness = 0.6
		_metal.metallic = 0.3
	return _metal


static func wood_material() -> StandardMaterial3D:
	if _wood == null:
		_wood = StandardMaterial3D.new()
		_wood.albedo_color = Color(0.3, 0.22, 0.15)
		_wood.roughness = 0.95
	return _wood


static func glow_material() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.albedo_color = Color(0.9, 0.9, 0.85)
		_glow.emission_enabled = true
		_glow.emission = Color(1.0, 0.82, 0.5)
		_glow.emission_energy_multiplier = 0.0
	return _glow


static func pool_material() -> StandardMaterial3D:
	if _pool == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gradient.colors = PackedColorArray([Color.WHITE, Color(0.3, 0.3, 0.3), Color.BLACK])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 128
		texture.height = 128
		_pool = StandardMaterial3D.new()
		_pool.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pool.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pool.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_pool.cull_mode = BaseMaterial3D.CULL_DISABLED
		_pool.albedo_texture = texture
		_pool.albedo_color = Color(1.0, 0.8, 0.5, 0.0)
	return _pool


## 0 = day (lamps dark), 1 = night (lamps shine, pools of light on the ground).
static func set_night(night: float) -> void:
	glow_material().emission_energy_multiplier = 3.0 * night
	pool_material().albedo_color = Color(1.0, 0.8, 0.5, 0.45 * night)


static func _begin() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


static func _box(tool: SurfaceTool, size: Vector3, at: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	tool.append_from(box, 0, Transform3D(Basis(), at))


static func _cylinder(tool: SurfaceTool, bottom_radius: float, top_radius: float, height: float, at: Vector3) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = bottom_radius
	cylinder.top_radius = top_radius
	cylinder.height = height
	cylinder.radial_segments = 8
	cylinder.rings = 1
	tool.append_from(cylinder, 0, Transform3D(Basis(), at))
