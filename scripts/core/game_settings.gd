class_name GameSettings
extends RefCounted
## Player settings (volume, fullscreen, mouse sensitivity), saved to user://settings.cfg.
## Static members: read `GameSettings.mouse_sensitivity` from anywhere, change a value
## and call `GameSettings.save_settings()`.

const PATH := "user://settings.cfg"

static var master_volume: float = 1.0
static var fullscreen: bool = false
static var mouse_sensitivity: float = 0.0025
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
	apply()


static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.save(PATH)


## Puts volume and window mode into effect.
static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
