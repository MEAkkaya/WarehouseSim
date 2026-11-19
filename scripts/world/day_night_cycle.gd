class_name DayNightCycle
extends Node
## Drives the sun, the moon, the sky and the fog from GameState's clock.
## Put one in a level and assign the three nodes in the Inspector.
##
## The sky is the shader assets/shaders/sky_clouds.gdshader (gradient with a warm horizon at
## sunrise and sunset, clouds, sun, moon, stars); this node feeds it the time of day. The
## sky also lights the world (the environment's ambient light comes from the sky), and the
## distance fog takes the colour of the horizon, so far things melt into it.
##
## Sun: warm white at noon, orange when it is low. Moon: icy blue.

@export var sun: DirectionalLight3D
@export var moon: DirectionalLight3D
@export var world_environment: WorldEnvironment

@export_group("Lights")
@export var sun_noon_color: Color = Color(1.0, 0.93, 0.8)
@export var sun_low_color: Color = Color(1.0, 0.54, 0.26)
@export var moon_color: Color = Color(0.5, 0.7, 1.0)
@export var max_sun_energy: float = 1.0
@export var max_moon_energy: float = 0.3
## Ambient light that comes from the sky (it is the sky's own brightness times this).
@export var day_ambient_energy: float = 1.0
@export var night_ambient_energy: float = 1.6

@export_group("Sky colours")
@export var top_day: Color = Color(0.2, 0.42, 0.85)
@export var horizon_day: Color = Color(0.72, 0.83, 0.93)
@export var top_warm: Color = Color(0.3, 0.36, 0.62)
@export var horizon_warm: Color = Color(1.0, 0.55, 0.26)
@export var top_night: Color = Color(0.004, 0.01, 0.04)
@export var horizon_night: Color = Color(0.035, 0.06, 0.14)
@export_range(0.0, 1.0) var cloud_cover: float = 0.5

var _darkness: float = 0.0


func _ready() -> void:
	# The graphics options (global illumination, AO, shadows...) act on these two.
	if world_environment != null:
		Graphics.register_world(world_environment.environment, sun)


func _process(delta: float) -> void:
	var height := GameState.get_sun_height()  # -1 (midnight) .. 1 (noon)
	# Day factor: 0 at night, 1 in daylight, smooth through dawn/dusk. A power outage
	# at work (blackout) turns everything dark, whatever the hour.
	var target_darkness := 1.0 if GameState.blackout and GameState.on_shift else 0.0
	_darkness = move_toward(_darkness, target_darkness, delta * 2.0)
	var day := smoothstep(-0.1, 0.35, height) * (1.0 - _darkness)
	# 1 while the sun is on the horizon (sunrise, sunset), fading out as it climbs
	var warmth := exp(-pow(height / 0.28, 2.0))

	if sun != null:
		# Rotation order is yaw then pitch. Pitch points the light down; yaw sweeps
		# the sun across the sky (15 degrees per hour, due south at noon).
		sun.rotation_degrees = Vector3(-height * 75.0, (GameState.hour - 12.0) * 15.0, 0.0)
		sun.light_energy = max_sun_energy * day
		sun.light_color = sun_noon_color.lerp(sun_low_color, warmth)
		sun.visible = day > 0.001
	if moon != null:
		moon.rotation_degrees = Vector3(height * 60.0, (GameState.hour - 12.0) * 15.0 + 180.0, 0.0)
		moon.light_energy = max_moon_energy * (1.0 - day) * (1.0 - _darkness)
		moon.light_color = moon_color
		moon.visible = day < 0.999
	if world_environment == null or world_environment.environment == null:
		return
	var env := world_environment.environment
	var horizon := horizon_night.lerp(horizon_day.lerp(horizon_warm, warmth), day)
	var material: ShaderMaterial = null
	if env.sky != null:
		material = env.sky.sky_material as ShaderMaterial
	if material != null:
		# (the light points along its -Z, so "towards the sun" is its +Z)
		material.set_shader_parameter("sun_dir", sun.global_transform.basis.z if sun != null else Vector3.UP)
		material.set_shader_parameter("moon_dir", moon.global_transform.basis.z if moon != null else Vector3.DOWN)
		material.set_shader_parameter("day", day)
		material.set_shader_parameter("warmth", warmth * (1.0 - _darkness))
		material.set_shader_parameter("top_day", top_day)
		material.set_shader_parameter("horizon_day", horizon_day)
		material.set_shader_parameter("top_warm", top_warm)
		material.set_shader_parameter("horizon_warm", horizon_warm)
		material.set_shader_parameter("top_night", top_night)
		material.set_shader_parameter("horizon_night", horizon_night)
		material.set_shader_parameter("cloud_cover", cloud_cover)
		env.ambient_light_energy = lerpf(night_ambient_energy, day_ambient_energy, day) * (1.0 - 0.92 * _darkness)
	else:
		env.background_color = horizon
		env.ambient_light_energy = lerpf(night_ambient_energy, day_ambient_energy, day) * (1.0 - 0.92 * _darkness) * 0.4
	# Distance fog takes the colour of the horizon, so far things melt into the sky (and
	# the edge of the world is never visible) at any hour.
	env.fog_light_color = horizon
