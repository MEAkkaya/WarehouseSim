class_name CharacterModel
extends Node3D
## The visible body of a person (assets/models/employee.glb inside employee_model.tscn).
## Look: the body is painted with assets/textures/employeeUv.png; the clothes are recoloured
## with a shader (assets/shaders/character_tint.gdshader) that uses the clothes mask
## (assets/textures/employeeUv_mask.png). `shirt_color` and `pants_color` pick the colours,
## everything else (skin, face, hair) stays as painted. Materials are shared between people
## who wear the same colours.
##
## Animation: the glb carries the clips `idle` and `walk` (an AnimationPlayer made by the
## import). The model watches how fast it moves in the world and plays `walk` (sped up or
## slowed down to match the speed) or `idle`, so the NPC scripts do not have to know.
##
## The glb faces +Z (the glTF way); employee_model.tscn turns it around, so the person
## looks along -Z like everything else in the game (and is centred on the origin).

const TINT_SHADER := preload("res://assets/shaders/character_tint.gdshader")
const BASE_TEXTURE := preload("res://assets/textures/employeeUv.png")
const MASK_TEXTURE := preload("res://assets/textures/employeeUv_mask.png")

@export var shirt_color: Color = Color(0.2, 0.4, 0.75):
	set(value):
		shirt_color = value
		_apply()
@export var pants_color: Color = Color(0.18, 0.2, 0.28):
	set(value):
		pants_color = value
		_apply()

## The speed (m/s) at which the `walk` clip's feet do not slide on the ground.
@export var stride_speed: float = 1.25
## Seconds to blend from one clip into the next.
@export var blend_time: float = 0.2

static var _materials: Dictionary = {}

var _player: AnimationPlayer = null
var _last_position: Vector3 = Vector3.ZERO
var _walking: bool = false


func _ready() -> void:
	_apply()
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null:
		return
	for clip in ["idle", "walk"]:
		if _player.has_animation(clip):
			_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_last_position = global_position
	_play("idle")
	# (people standing next to each other should not breathe in sync)
	_player.seek(randf() * _player.current_animation_length)


func _process(delta: float) -> void:
	if _player == null or delta <= 0.0:
		return
	var speed := (global_position - _last_position).length() / delta
	_last_position = global_position
	# (a little hysteresis, so a stuttering step does not flicker between the clips)
	if _walking and speed < 0.15:
		_walking = false
		_play("idle")
	elif not _walking and speed > 0.3:
		_walking = true
		_play("walk")
	if _walking:
		_player.speed_scale = clampf(speed / stride_speed, 0.5, 2.5)


func _play(clip: String) -> void:
	if _player.has_animation(clip):
		_player.speed_scale = 1.0
		_player.play(clip, blend_time)


func _apply() -> void:
	if not is_inside_tree():
		return
	var material := _material(shirt_color, pants_color)
	for node in find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = material


static func _material(shirt: Color, pants: Color) -> ShaderMaterial:
	var key := "%s_%s" % [shirt.to_html(), pants.to_html()]
	if not _materials.has(key):
		var material := ShaderMaterial.new()
		material.shader = TINT_SHADER
		material.set_shader_parameter("base_texture", BASE_TEXTURE)
		material.set_shader_parameter("clothes_mask", MASK_TEXTURE)
		material.set_shader_parameter("shirt_color", shirt)
		material.set_shader_parameter("pants_color", pants)
		_materials[key] = material
	return _materials[key]
