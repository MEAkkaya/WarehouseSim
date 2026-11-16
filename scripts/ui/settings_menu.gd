class_name SettingsMenu
extends PanelContainer
## The settings panel (volume, fullscreen, mouse sensitivity). Changes apply at once and
## are saved when you press Back. Built in code so the main menu scene stays simple.

signal closed

var _volume: HSlider
var _fullscreen: CheckBox
var _sensitivity: HSlider
var _sensitivity_label: Label


func _ready() -> void:
	GameSettings.load_settings()
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(420, 0)
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	column.add_child(_make_label("Master volume"))
	_volume = _make_slider(column, 0.0, 1.0, 0.05, GameSettings.master_volume)
	_volume.value_changed.connect(func(v: float) -> void:
		GameSettings.master_volume = v
		GameSettings.apply())

	_fullscreen = CheckBox.new()
	_fullscreen.text = "Fullscreen"
	_fullscreen.button_pressed = GameSettings.fullscreen
	_fullscreen.toggled.connect(func(on: bool) -> void:
		GameSettings.fullscreen = on
		GameSettings.apply())
	column.add_child(_fullscreen)

	_sensitivity_label = _make_label("")
	column.add_child(_sensitivity_label)
	_sensitivity = _make_slider(column, 0.0008, 0.006, 0.0001, GameSettings.mouse_sensitivity)
	_sensitivity.value_changed.connect(func(v: float) -> void:
		GameSettings.mouse_sensitivity = v
		_update_labels())
	_update_labels()

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 46)
	back.pressed.connect(func() -> void:
		GameSettings.save_settings()
		closed.emit())
	column.add_child(back)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _make_slider(parent: Control, low: float, high: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 26)
	parent.add_child(slider)
	return slider


func _update_labels() -> void:
	_sensitivity_label.text = "Mouse sensitivity (%.1f)" % (GameSettings.mouse_sensitivity / 0.0025)
