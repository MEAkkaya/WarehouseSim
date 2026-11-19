extends Node
## (Autoload "Graphics".) Puts GameSettings.graphics into effect, live: nothing needs a restart.
## The world registers what can be changed:
##   - DayNightCycle calls `register_world(environment, sun)` (global illumination, ambient
##     occlusion, bounce light, shadows),
##   - TownScenery and HillForest call `register_thinnable(holder, "grass" / "forest")` for each
##     MultiMesh they draw (a MultiMesh can show just its first N instances; the scatter order is
##     random, so showing fewer thins them out evenly),
## and two shader globals (project.godot > shader_globals) switch the clouds of the sky shader
## and the wind of the leaves and grass. The window itself gets the render scale and the
## anti-aliasing. Call `apply()` after changing a value.

signal changed

## Sun shadow quality 0..3 (off, low, medium, high): atlas size, how far they reach (m),
## softness (RenderingServer.ShadowQuality: 1 = very low, 2 = low).
const SHADOW_ATLAS := [2048, 2048, 2048, 4096]
const SHADOW_DISTANCE := [0.0, 45.0, 70.0, 100.0]
const SHADOW_SOFTNESS := [1, 1, 2, 2]

var _environment: Environment = null
var _sun: DirectionalLight3D = null
## {"grass": [MultiMeshInstance3D, ...], "forest": [...]}
var _thinnable := {"grass": [], "forest": []}


func _ready() -> void:
	GameSettings.load_settings()
	apply()


func register_world(environment: Environment, sun: DirectionalLight3D) -> void:
	_environment = environment
	_sun = sun
	apply()


## `holder` shows only a part of its instances (the part chosen by `kind`'s density).
func register_thinnable(holder: MultiMeshInstance3D, kind: String) -> void:
	if not _thinnable.has(kind):
		return
	(_thinnable[kind] as Array).append(holder)
	_apply_density(holder, kind)


## Puts every graphics option into effect.
func apply() -> void:
	var g := GameSettings.graphics
	# the shader globals: 1 = on
	RenderingServer.global_shader_parameter_set("sky_clouds", 1.0 if g.clouds else 0.0)
	RenderingServer.global_shader_parameter_set("wind_amount", 1.0 if g.wind else 0.0)
	# the window: render scale (FSR upscaling below 1) and anti-aliasing
	var root := get_tree().root
	var scale := clampf(g.scale as float, 0.5, 1.0)
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if scale >= 0.999 else Viewport.SCALING_3D_MODE_FSR
	root.scaling_3d_scale = scale
	root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(g.msaa as int, 0, 2)]
	# the lighting of the world
	if _environment != null:
		_environment.sdfgi_enabled = g.sdfgi
		_environment.ssao_enabled = g.ssao
		_environment.ssil_enabled = g.ssil
	var quality := clampi(g.shadows as int, 0, 3)
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS[quality], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(SHADOW_SOFTNESS[quality])
	if is_instance_valid(_sun):
		_sun.shadow_enabled = quality > 0
		_sun.directional_shadow_max_distance = maxf(SHADOW_DISTANCE[quality], 1.0)
	for kind: String in _thinnable:
		var list: Array = _thinnable[kind]
		for i in range(list.size() - 1, -1, -1):
			if is_instance_valid(list[i]):
				_apply_density(list[i] as MultiMeshInstance3D, kind)
			else:
				list.remove_at(i)   # (the world was left: its nodes are gone)
	changed.emit()


func _apply_density(holder: MultiMeshInstance3D, kind: String) -> void:
	var multimesh := holder.multimesh
	if multimesh == null:
		return
	var density := clampf(GameSettings.graphics[kind] as float, 0.0, 1.0)
	multimesh.visible_instance_count = -1 if density >= 0.999 else int(multimesh.instance_count * density)
