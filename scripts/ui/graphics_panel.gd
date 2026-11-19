class_name GraphicsPanel
extends ScrollContainer
## The graphics options (a preset and every option behind it), built in code. Used by the
## phone's Settings app and by the main menu's settings, so it is the same everywhere.
## Every change applies at once (Graphics.apply(): no restart) and moves the preset to
## "Custom" when it no longer matches Low, Medium or High. The caller saves the settings when
## it closes the page (GameSettings.save_settings()).

const SHADOW_NAMES := ["Off", "Low", "Medium", "High"]
const SCALE_VALUES := [0.5, 0.6, 0.75, 0.85, 1.0]
const MSAA_NAMES := ["Off", "2x", "4x"]

## Text size of the labels (the phone's screen is small).
@export var font_size: int = 15

var _preset: OptionButton
var _checks := {}      # option key -> CheckBox
var _sliders := {}     # option key -> HSlider
var _slider_labels := {}
var _shadows: OptionButton
var _scale: OptionButton
var _msaa: OptionButton
var _building: bool = false


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	_label(column, "Preset")
	_preset = OptionButton.new()
	for preset_name: String in GameSettings.PRESETS:
		_preset.add_item(preset_name)
	_preset.add_item("Custom")
	_preset.item_selected.connect(_on_preset_selected)
	column.add_child(_preset)

	_section(column, "Lighting")
	_check(column, "sdfgi", "Global illumination (SDFGI) - heavy")
	_check(column, "ssao", "Ambient occlusion (SSAO)")
	_check(column, "ssil", "Bounce light (SSIL) - heavy")
	_shadows = _option(column, "Shadows", SHADOW_NAMES, func(index: int) -> void: _change("shadows", index))

	_section(column, "World")
	_check(column, "clouds", "Clouds")
	_check(column, "wind", "Wind (grass and leaves move)")
	_slider(column, "grass", "Grass")
	_slider(column, "forest", "Distant forest")

	_section(column, "Picture")
	var scale_names: Array[String] = []
	for value: float in SCALE_VALUES:
		scale_names.append("%d%%" % roundi(value * 100.0))
	_scale = _option(column, "Render scale (upscaled below 100%)", scale_names,
			func(index: int) -> void: _change("scale", SCALE_VALUES[index]))
	_msaa = _option(column, "Anti-aliasing (MSAA)", MSAA_NAMES, func(index: int) -> void: _change("msaa", index))

	var note := _label(column, "Changes apply at once. Turning global illumination on may stutter for a moment.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	note.add_theme_font_size_override("font_size", font_size - 2)
	refresh()


## Shows the current options (call it when the page opens).
func refresh() -> void:
	if _preset == null:
		return
	_building = true
	var g := GameSettings.graphics
	var name_now := GameSettings.current_preset()
	for i in _preset.item_count:
		if _preset.get_item_text(i) == name_now:
			_preset.select(i)
	for key: String in _checks:
		(_checks[key] as CheckBox).button_pressed = g[key]
	for key: String in _sliders:
		(_sliders[key] as HSlider).value = g[key]
		_update_slider_label(key)
	_shadows.select(clampi(g.shadows as int, 0, SHADOW_NAMES.size() - 1))
	_scale.select(_nearest_scale(g.scale as float))
	_msaa.select(clampi(g.msaa as int, 0, MSAA_NAMES.size() - 1))
	_building = false


func _on_preset_selected(index: int) -> void:
	if _building:
		return
	var preset_name := _preset.get_item_text(index)
	if GameSettings.PRESETS.has(preset_name):
		GameSettings.set_preset(preset_name)
		Graphics.apply()
	refresh()


## Sets one option, applies it and updates the preset name.
func _change(key: String, value: Variant) -> void:
	if _building:
		return
	GameSettings.graphics[key] = value
	Graphics.apply()
	refresh()


func _nearest_scale(value: float) -> int:
	var best := 0
	for i in SCALE_VALUES.size():
		if absf(SCALE_VALUES[i] - value) < absf(SCALE_VALUES[best] - value):
			best = i
	return best


# ---- Building the rows ---------------------------------------------------------------------

func _label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _section(parent: Control, text: String) -> void:
	var label := _label(parent, text.to_upper())
	label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	label.add_theme_font_size_override("font_size", font_size - 1)


func _check(parent: Control, key: String, text: String) -> void:
	var box := CheckBox.new()
	box.text = text
	box.add_theme_font_size_override("font_size", font_size)
	box.toggled.connect(func(on: bool) -> void: _change(key, on))
	parent.add_child(box)
	_checks[key] = box


func _slider(parent: Control, key: String, text: String) -> void:
	var label := _label(parent, text)
	_slider_labels[key] = [label, text]
	var slider := HSlider.new()
	slider.min_value = 0.2
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(0, 24)
	slider.value_changed.connect(func(v: float) -> void: _change(key, v))
	parent.add_child(slider)
	_sliders[key] = slider


func _update_slider_label(key: String) -> void:
	var pair: Array = _slider_labels[key]
	(pair[0] as Label).text = "%s (%d%%)" % [pair[1], roundi((GameSettings.graphics[key] as float) * 100.0)]


func _option(parent: Control, text: String, names: Array, on_selected: Callable) -> OptionButton:
	_label(parent, text)
	var option := OptionButton.new()
	for item: String in names:
		option.add_item(item)
	option.add_theme_font_size_override("font_size", font_size)
	option.item_selected.connect(on_selected)
	parent.add_child(option)
	return option
