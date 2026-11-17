class_name PaperLabel
extends Label3D
## Text on a sheet of paper. A normal Label3D floats in the air and (with billboard on) turns to
## face you; this one never turns: it is a real sheet of paper (a thin box) with the text
## printed on it, so it can be stuck on a wall or a person, tied to a post or hung from the
## ceiling by two strings.
##
## Use it like a Label3D (`PaperLabel.new()`, or give an existing Label3D node this script),
## after changing `text` at run time call `fit_paper()` so the sheet grows or shrinks with it.
##
## The text colour (`modulate`) is used as the ink colour, made dark enough to read on paper.

## Paper colour.
const PAPER_COLOR := Color(0.95, 0.93, 0.85)
const CABLE_COLOR := Color(0.25, 0.25, 0.28)

## Also print the text on the back of the sheet (for signs you walk around).
@export var two_sided: bool = false
## > 0: the sheet hangs from two strings this long (they go up from its top corners).
@export var hang_length: float = 0.0
## The floor height (in the parent's space) to which a post is drawn under the sheet.
## NaN = no post. Posts are for signs that would otherwise float in the air.
@export var post_to_y: float = NAN

static var _unit_box: BoxMesh = null
static var _paper_material: StandardMaterial3D = null
static var _cable_material: StandardMaterial3D = null

var _paper: MeshInstance3D = null
var _back: Label3D = null
var _extras: Array[MeshInstance3D] = []


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_DISABLED
	outline_size = 0
	fit_paper()


## Changes the text and refits the sheet.
func set_paper_text(new_text: String) -> void:
	text = new_text
	fit_paper()


## Makes the sheet the right size for the current text (call it after changing `text`).
func fit_paper() -> void:
	_make_shared()
	modulate = _ink(modulate)
	var font := ThemeDB.fallback_font
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size) * pixel_size
	var pad := 0.035 + 0.25 * pixel_size * font_size * 0.2
	var width := size.x + pad * 2.0
	var height := size.y + pad * 1.4
	if _paper == null:
		_paper = MeshInstance3D.new()
		_paper.mesh = _unit_box
		_paper.material_override = _paper_material
		_paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_paper, false, Node.INTERNAL_MODE_FRONT)
	# The sheet is just behind the text.
	_paper.visible = not text.is_empty()
	_paper.scale = Vector3(width, height, 0.004)
	_paper.position = Vector3(0.0, 0.0, -0.0035)
	for extra in _extras:
		extra.queue_free()
	_extras.clear()
	if hang_length > 0.0:
		for side in [-1.0, 1.0]:
			_add_bar(Vector3(side * (width / 2.0 - 0.02), height / 2.0 + hang_length / 2.0, -0.0035), Vector3(0.008, hang_length, 0.008), _cable_material)
	if not is_nan(post_to_y):
		var length := position.y - height / 2.0 - post_to_y
		if length > 0.05:
			_add_bar(Vector3(0.0, -height / 2.0 - length / 2.0, -0.012), Vector3(0.035, length, 0.02), _cable_material)
	if two_sided:
		if _back == null:
			_back = Label3D.new()
			add_child(_back, false, Node.INTERNAL_MODE_FRONT)
		_back.rotation = Vector3(0.0, PI, 0.0)
		_back.position = Vector3(0.0, 0.0, -0.0075)
		_back.text = text
		_back.font_size = font_size
		_back.pixel_size = pixel_size
		_back.outline_size = 0
		_back.modulate = modulate
		_back.horizontal_alignment = horizontal_alignment


func _add_bar(at: Vector3, size: Vector3, material: Material) -> void:
	var bar := MeshInstance3D.new()
	bar.mesh = _unit_box
	bar.material_override = material
	bar.scale = size
	bar.position = at
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar, false, Node.INTERNAL_MODE_FRONT)
	_extras.append(bar)


static func _make_shared() -> void:
	if _unit_box != null:
		return
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	_paper_material = StandardMaterial3D.new()
	_paper_material.albedo_color = PAPER_COLOR
	_paper_material.roughness = 0.95
	_cable_material = StandardMaterial3D.new()
	_cable_material.albedo_color = CABLE_COLOR


## Ink: the given colour, darkened until it can be read on paper (white becomes dark grey).
static func _ink(color: Color) -> Color:
	if color.v < 0.5:
		return color
	return Color.from_hsv(color.h, minf(color.s, 0.9), 0.22)


## A paper label made in code: `PaperLabel.make(parent, "TEXT", position, 0.01)`.
static func make(parent: Node, label_text: String, at: Vector3, label_pixel_size: float = 0.01,
		ink: Color = Color.WHITE, double_sided: bool = false, font: int = 56) -> PaperLabel:
	var label := PaperLabel.new()
	label.text = label_text
	label.pixel_size = label_pixel_size
	label.font_size = font
	label.modulate = ink
	label.two_sided = double_sided
	label.position = at
	parent.add_child(label)
	return label
