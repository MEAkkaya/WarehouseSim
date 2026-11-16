class_name DayNightCycle
extends Node
## Drives the sun, the moon and the sky colour from GameState's clock.
## Put one in a level and assign the three nodes in the Inspector.

@export var sun: DirectionalLight3D
@export var moon: DirectionalLight3D
@export var world_environment: WorldEnvironment

@export_group("Look")
@export var day_sky: Color = Color(0.55, 0.62, 0.7)
@export var night_sky: Color = Color(0.02, 0.03, 0.08)
@export var day_ambient: Color = Color(0.75, 0.75, 0.8)
@export var night_ambient: Color = Color(0.18, 0.2, 0.35)
@export var day_ambient_energy: float = 0.6
@export var night_ambient_energy: float = 0.35
@export var max_sun_energy: float = 1.0
@export var max_moon_energy: float = 0.25


var _darkness: float = 0.0


func _process(delta: float) -> void:
	var height := GameState.get_sun_height()  # -1 (midnight) .. 1 (noon)
	# Day factor: 0 at night, 1 in daylight, smooth through dawn/dusk. A power outage
	# at work (blackout) turns everything dark, whatever the hour.
	var target_darkness := 1.0 if GameState.blackout and GameState.on_shift else 0.0
	_darkness = move_toward(_darkness, target_darkness, delta * 2.0)
	var day := smoothstep(-0.1, 0.35, height) * (1.0 - _darkness)

	if sun != null:
		# Rotation order is yaw then pitch. Pitch points the light down; yaw sweeps
		# the sun across the sky (15 degrees per hour, due south at noon).
		sun.rotation_degrees = Vector3(-height * 75.0, (GameState.hour - 12.0) * 15.0, 0.0)
		sun.light_energy = max_sun_energy * day
		sun.visible = day > 0.001
	if moon != null:
		moon.rotation_degrees = Vector3(height * 60.0, (GameState.hour - 12.0) * 15.0 + 180.0, 0.0)
		moon.light_energy = max_moon_energy * (1.0 - day) * (1.0 - _darkness)
		moon.visible = day < 0.999
	if world_environment != null and world_environment.environment != null:
		var env := world_environment.environment
		env.background_color = night_sky.lerp(day_sky, day)
		env.ambient_light_color = night_ambient.lerp(day_ambient, day)
		env.ambient_light_energy = lerpf(night_ambient_energy, day_ambient_energy, day) * (1.0 - 0.92 * _darkness)
		# Distance fog takes the sky colour, so far things melt into the sky (and the
		# edge of the world is never visible) at any hour.
		env.fog_light_color = env.background_color
