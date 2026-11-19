class_name GameSettings
extends RefCounted
## Player settings (volume, fullscreen, mouse sensitivity, graphics), saved to user://settings.cfg.
## Static members: read `GameSettings.mouse_sensitivity` from anywhere, change a value
## and call `GameSettings.save_settings()`.
##
## The graphics options live in the dictionary `graphics` (keys below). The `Graphics` autoload
## puts them into effect (live, no restart); the screens that edit them call `Graphics.apply()`.

const PATH := "user://settings.cfg"

## The three presets. Keys:
##   sdfgi, ssao, ssil   true/false   global illumination, ambient occlusion, bounce light
##   clouds, wind        true/false   the clouds of the sky shader; moving grass and leaves
##   grass, forest       0.2 .. 1.0   how much of the grass / of the hill forest is drawn
##   shadows             0 .. 3       off, low, medium, high (sun shadows: size and distance)
##   scale               0.5 .. 1.0   3D render scale (upscaled with FSR when below 1)
##   msaa                0, 1, 2      anti-aliasing off, 2x, 4x
const PRESETS := {
	"Low": {"sdfgi": false, "ssao": false, "ssil": false, "clouds": false, "wind": false,
			"grass": 0.4, "forest": 0.5, "shadows": 1, "scale": 0.75, "msaa": 0},
	"Medium": {"sdfgi": false, "ssao": true, "ssil": false, "clouds": true, "wind": true,
			"grass": 0.7, "forest": 0.75, "shadows": 2, "scale": 1.0, "msaa": 0},
	"High": {"sdfgi": true, "ssao": true, "ssil": true, "clouds": true, "wind": true,
			"grass": 1.0, "forest": 1.0, "shadows": 3, "scale": 1.0, "msaa": 0},
}

static var master_volume: float = 1.0
static var fullscreen: bool = false
static var mouse_sensitivity: float = 0.0025
static var graphics: Dictionary = (PRESETS["High"] as Dictionary).duplicate()
static var _loaded: bool = false


## Reads the file once (later calls do nothing) and applies the settings.
static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		master_volume = config.get_value("audio", "master_volume", master_volume)
		fullscreen = config.get_value("video", "fullscreen", fullscreen)
		mouse_sensitivity = config.get_value("controls", "mouse_sensitivity", mouse_sensitivity)
		for key: String in graphics:
			var value: Variant = config.get_value("graphics", key, graphics[key])
			# (a value of the wrong type from an edited file is ignored)
			if typeof(value) == typeof(graphics[key]):
				graphics[key] = value
	apply()


static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	for key: String in graphics:
		config.set_value("graphics", key, graphics[key])
	config.save(PATH)


## Puts volume and window mode into effect.
static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## Copies a preset ("Low", "Medium", "High") into the graphics options.
static func set_preset(preset_name: String) -> void:
	if PRESETS.has(preset_name):
		graphics = (PRESETS[preset_name] as Dictionary).duplicate()


## The name of the preset the options match, or "Custom".
static func current_preset() -> String:
	for preset_name: String in PRESETS:
		var preset: Dictionary = PRESETS[preset_name]
		var same := true
		for key: String in preset:
			var a: Variant = preset[key]
			var b: Variant = graphics[key]
			if typeof(a) == TYPE_FLOAT:
				same = same and is_equal_approx(a as float, b as float)
			else:
				same = same and a == b
		if same:
			return preset_name
	return "Custom"
