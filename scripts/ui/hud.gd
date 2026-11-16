class_name PlayerHUD
extends CanvasLayer
## Per-player HUD. Each Player owns one, so a second player (split-screen/co-op)
## gets their own HUD instead of fighting over a global one.
## Health and energy bars, crosshair, interaction prompts, carried-box readout, the
## hotbar, the selected bill, a message line, and the phone (bottom right).

@onready var prompt_label: Label = $Root/Prompt
@onready var carry_label: Label = $Root/CarryInfo
@onready var bill_panel: PanelContainer = $Root/BillPanel
@onready var bill_rows: VBoxContainer = $Root/BillPanel/Rows
@onready var toast_label: Label = $Root/Toast
@onready var status_label: Label = $Root/StatusInfo
@onready var phone: Phone = $Root/Phone

const SLOT_SIZE := Vector2(92, 64)
const SLOT_GAP := 8

var _toast_id: int = 0
var _health_bar: ProgressBar
var _energy_bar: ProgressBar
var _inventory: Inventory = null
var _slot_panels: Array[PanelContainer] = []
## Per slot: the picture of the item (a little 3D scene rendered once into a texture),
## the text shown for bills, and what the picture currently shows.
var _slot_thumbs: Array[TextureRect] = []
var _slot_viewports: Array[SubViewport] = []
var _slot_stages: Array[Node3D] = []
var _slot_bill_labels: Array[Label] = []
var _slot_items: Array[ItemData] = []
var _held_name: Label
static var _thumb_environment: Environment = null


func _ready() -> void:
	set_prompt("")
	carry_label.visible = false  # (the old line; the details are in the panel on the right)
	set_bill(null)
	toast_label.visible = false
	_build_vitals()
	_build_fade()
	_build_quest_log()
	_build_throw_bar()
	_build_hint_panel()
	_build_carry_panel()
	_build_achievement_box()
	# Health, energy and the shift come from the global GameState.
	GameState.health_changed.connect(_refresh_status)
	GameState.energy_changed.connect(_refresh_status)
	GameState.multiplier_changed.connect(_refresh_status)
	GameState.shift_changed.connect(_on_shift_changed)
	GameState.payout_made.connect(_on_payout_made)
	GameState.notice.connect(func(text: String) -> void: show_message(text, 5.0))
	Career.retired.connect(_show_ending)
	_refresh_status()


## The health and energy bars (top left).
func _build_vitals() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.position = Vector2(24, 24)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(column)
	_health_bar = _make_bar(column, "HP", Color(0.85, 0.2, 0.2))
	_energy_bar = _make_bar(column, "EN", Color(0.95, 0.8, 0.2))


func _make_bar(parent: Control, caption: String, fill_color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(28, 0)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(230, 18)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.05, 0.07, 0.8)
	background.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return bar


const ENDING_TEXT := "The number on the screen finally says it: $1,000,000.

You hand in your badge, buy the little house by the lake, and never touch a cardboard box again.

Retirement: achieved. The company would like you to know that you will be missed, and that your replacement is already on shift."

var _payout_text: String = ""
var _fade: ColorRect
var _heat_bar: ProgressBar
var _was_exhausted: bool = false


## The ending: the game pauses and the story is told. Then keep playing (free play)
## or go back to the main menu.
func _show_ending() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var overlay := Control.new()
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS  # still works while the game is paused
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.9)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(640, 0)
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	var title := Label.new()
	title.text = "YOU RETIRED"
	title.add_theme_font_size_override("font_size", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var story := Label.new()
	story.text = ENDING_TEXT
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.add_theme_font_size_override("font_size", 20)
	column.add_child(story)
	var keep := Button.new()
	keep.text = "Keep playing (free play)"
	keep.custom_minimum_size = Vector2(0, 48)
	keep.pressed.connect(func() -> void:
		get_tree().paused = false
		Career.continue_free_play()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		overlay.queue_free())
	column.add_child(keep)
	var menu := Button.new()
	menu.text = "Main menu"
	menu.custom_minimum_size = Vector2(0, 48)
	menu.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	column.add_child(menu)
	$Root.add_child(overlay)
	keep.grab_focus()


## A black overlay over everything, for fading out when the player passes out.
func _build_fade() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_fade)


## The burning-floor bar (Emergency Floor Heating event): `fraction` 0..1, or a
## negative number to hide it.
func set_heat(fraction: float) -> void:
	if _heat_bar == null:
		if fraction < 0.0:
			return
		_heat_bar = ProgressBar.new()
		_heat_bar.custom_minimum_size = Vector2(230, 16)
		_heat_bar.position = Vector2(60, 118)
		_heat_bar.show_percentage = false
		_heat_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(1.0, 0.45, 0.1)
		fill.set_corner_radius_all(5)
		_heat_bar.add_theme_stylebox_override("fill", fill)
		var heat_label := Label.new()
		heat_label.text = "HEAT"
		heat_label.position = Vector2(-48, -3)
		heat_label.add_theme_color_override("font_outline_color", Color.BLACK)
		heat_label.add_theme_constant_override("outline_size", 6)
		_heat_bar.add_child(heat_label)
		_heat_bar.max_value = 1.0
		$Root.add_child(_heat_bar)
	_heat_bar.visible = fraction >= 0.0
	_heat_bar.value = maxf(fraction, 0.0)


## Fades the screen to `alpha` (1 = black, 0 = clear). `await` it to wait.
func fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, seconds)
	await tween.finished


func _on_payout_made(amount: int, multiplier: float) -> void:
	_payout_text = "  -  paid $%s (x%.2f)" % [_money(amount), multiplier]


func _on_shift_changed(on_shift: bool) -> void:
	_refresh_status()
	if on_shift:
		show_message("Clocked in - " + GameState.get_clock_text(), 3.0)
	else:
		show_message("Clocked out - " + GameState.get_clock_text() + _payout_text, 4.0)
		_payout_text = ""


func _refresh_status(_unused1: Variant = null, _unused2: Variant = null) -> void:
	# One warning when energy drops low.
	var exhausted := GameState.energy < GameState.max_energy * 0.2 and GameState.on_shift
	if exhausted and not _was_exhausted:
		show_message("You're exhausted... you need a rest.", 3.0)
	_was_exhausted = exhausted
	_health_bar.max_value = GameState.max_health
	_health_bar.value = GameState.health
	_energy_bar.max_value = GameState.max_energy
	_energy_bar.value = GameState.energy
	if GameState.on_shift:
		status_label.text = "ON SHIFT   x%.2f   unpaid $%s" % [
				GameState.multiplier, _money(GameState.get_pending_payout())]
	else:
		status_label.text = "off shift"


## 1234567 -> "1,234,567"
func _money(amount: int) -> String:
	var digits := str(amount)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out


var _hotbar_row: Control = null


## The hotbar is greyed out while a box is in the hands (you cannot use it then).
func set_hotbar_locked(locked: bool) -> void:
	if _hotbar_row != null:
		_hotbar_row.modulate = Color(1, 1, 1, 0.35) if locked else Color.WHITE


## Builds the hotbar (bottom centre) for `inventory` and keeps it redrawn.
## The slots are made in code because their number is a setting on the Player.
## A slot shows the MODEL of its item (a small 3D picture), with the slot number in its
## bottom right corner, drawn last so it is always on top. The name of the item you are
## holding (the selected slot) is shown above the hotbar.
func bind_inventory(inventory: Inventory) -> void:
	_inventory = inventory
	var count := inventory.size()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SLOT_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotbar_row = row
	$Root.add_child(row)
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var width := count * SLOT_SIZE.x + (count - 1) * SLOT_GAP
	row.offset_left = -width / 2.0
	row.offset_right = width / 2.0
	row.offset_top = -SLOT_SIZE.y - 20.0
	row.offset_bottom = -20.0
	for i in count:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = SLOT_SIZE
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var content := Control.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.clip_contents = true
		panel.add_child(content)
		# 1. the picture of the item
		var thumb := TextureRect.new()
		thumb.set_anchors_preset(Control.PRESET_FULL_RECT)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.visible = false
		content.add_child(thumb)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(184, 128)
		viewport.own_world_3d = true
		viewport.transparent_bg = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		thumb.add_child(viewport)
		var stage := _build_thumbnail_stage(viewport)
		thumb.texture = viewport.get_texture()
		# 2. what bills show (they have no model)
		var bill_label := Label.new()
		bill_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		bill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bill_label.add_theme_font_size_override("font_size", 14)
		bill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bill_label.visible = false
		content.add_child(bill_label)
		# 3. the slot number, last = on top of everything, bottom right
		var number := Label.new()
		number.text = str(i + 1)
		number.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		number.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		number.grow_vertical = Control.GROW_DIRECTION_BEGIN
		number.offset_left = -26.0
		number.offset_top = -24.0
		number.offset_right = -5.0
		number.offset_bottom = -1.0
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		number.add_theme_font_size_override("font_size", 17)
		number.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		number.add_theme_constant_override("outline_size", 6)
		number.z_index = 10
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(number)
		row.add_child(panel)
		_slot_panels.append(panel)
		_slot_thumbs.append(thumb)
		_slot_viewports.append(viewport)
		_slot_stages.append(stage)
		_slot_bill_labels.append(bill_label)
		_slot_items.append(null)
	# The name of the item in your hand, just above the hotbar.
	_held_name = Label.new()
	_held_name.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_held_name.offset_left = -200.0
	_held_name.offset_right = 200.0
	_held_name.offset_top = -SLOT_SIZE.y - 48.0
	_held_name.offset_bottom = -SLOT_SIZE.y - 24.0
	_held_name.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_held_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_held_name.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_held_name.add_theme_font_size_override("font_size", 19)
	_held_name.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_held_name.add_theme_constant_override("outline_size", 6)
	_held_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_name.visible = false
	$Root.add_child(_held_name)
	inventory.changed.connect(_redraw_hotbar)
	_redraw_hotbar()


## The little 3D scene behind one slot picture: a camera, two lights and an empty
## "stage" the item is put on. Returns the stage.
func _build_thumbnail_stage(viewport: SubViewport) -> Node3D:
	if _thumb_environment == null:
		_thumb_environment = Environment.new()
		_thumb_environment.background_mode = Environment.BG_CLEAR_COLOR
		_thumb_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_thumb_environment.ambient_light_color = Color(0.85, 0.87, 0.95)
		_thumb_environment.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _thumb_environment
	viewport.add_child(world_environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.2
	camera.position = Vector3(0.0, 0.0, 3.0)
	viewport.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40.0, 30.0, 0.0)
	light.light_energy = 1.2
	viewport.add_child(light)
	var stage := Node3D.new()
	viewport.add_child(stage)
	return stage


## Puts the picture of `item` into slot `i` (it is only drawn again when the item changes).
func _set_slot_model(i: int, item: ItemData) -> void:
	if _slot_items[i] == item:
		return
	_slot_items[i] = item
	for child in _slot_stages[i].get_children():
		child.queue_free()
	_slot_thumbs[i].visible = item != null
	if item == null:
		return
	var visual := item.create_visual()
	var bounds := item.measure_visual(visual)
	var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var fit := 1.0 / maxf(longest, 0.01)
	visual.scale = Vector3.ONE * fit
	visual.position = -bounds.get_center() * fit
	var pivot := Node3D.new()
	pivot.add_child(visual)
	pivot.rotation_degrees = Vector3(22.0, -35.0, 0.0)  # a three-quarter view from above
	_slot_stages[i].add_child(pivot)
	_slot_viewports[i].render_target_update_mode = SubViewport.UPDATE_ONCE


func _redraw_hotbar() -> void:
	for i in _slot_panels.size():
		var entry := _inventory.slots[i]
		var chosen := i == _inventory.selected
		_set_slot_model(i, entry.item if entry != null and entry.kind == InventoryEntry.Kind.ITEM else null)
		var is_bill := entry != null and entry.kind == InventoryEntry.Kind.BILL
		_slot_bill_labels[i].visible = is_bill
		if is_bill:
			_slot_bill_labels[i].text = "BILL\n#%d" % entry.order.number
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.12, 0.75)
		style.set_border_width_all(4 if chosen else 1)
		style.border_color = Color(1.0, 0.85, 0.2) if chosen else Color(0.6, 0.6, 0.65)
		style.set_corner_radius_all(6)
		_slot_panels[i].add_theme_stylebox_override("panel", style)
	# The name of what you hold.
	var held := _inventory.get_selected()
	_held_name.visible = held != null
	if held != null:
		_held_name.text = held.get_label()


var _hint_box: VBoxContainer


## The control hints on the left side of the screen: small and half transparent, so they
## can stay up as long as they apply without being in the way.
func _build_hint_panel() -> void:
	_hint_box = VBoxContainer.new()
	_hint_box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_hint_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_hint_box.offset_left = 24.0
	_hint_box.offset_right = 360.0
	_hint_box.offset_top = -60.0
	_hint_box.offset_bottom = 60.0
	_hint_box.add_theme_constant_override("separation", 2)
	_hint_box.modulate = Color(1, 1, 1, 0.55)
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_hint_box)


## Shows these lines (e.g. "[Left click] Place Banana Bar") on the left; an empty list hides
## the panel.
func set_hints(lines: PackedStringArray) -> void:
	for child in _hint_box.get_children():
		_hint_box.remove_child(child)
		child.queue_free()
	for line in lines:
		var label := Label.new()
		label.text = line
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint_box.add_child(label)


## The bill being read, as a paper panel above the hotbar. Each product is a
## row: "A3 : Water Bottle ______ 3" - the underscores are a leader line that
## fills the gap, so it is easy to see which count belongs to which name.
## Pass null to hide the panel.
func set_bill(order: Order) -> void:
	for child in bill_rows.get_children():
		bill_rows.remove_child(child)
		child.queue_free()
	bill_panel.visible = order != null
	if order == null:
		return
	bill_rows.add_child(_bill_label("ORDER #%d" % order.number))
	for line in order.lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_bill_label("%s : %s" % [line.shelf_id, line.item.display_name]))
		# Far more underscores than will ever fit; clip_text cuts them at the
		# edge of the space the row leaves free.
		var leader := _bill_label("_".repeat(80))
		leader.clip_text = true
		leader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		leader.modulate = Color(1, 1, 1, 0.55)
		row.add_child(leader)
		row.add_child(_bill_label(str(line.quantity)))
		bill_rows.add_child(row)
	if order.completed:
		bill_rows.add_child(_bill_label("- SHIPPED: %s -" % ("CORRECT" if order.correct else "WRONG")))


func _bill_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08))
	label.add_theme_font_size_override("font_size", 20)
	return label


var _throw_bar: ProgressBar
var _quest_log: PanelContainer
var _quest_rows: VBoxContainer


## The throw power bar under the crosshair (shown while the right mouse button is held).
func _build_throw_bar() -> void:
	_throw_bar = ProgressBar.new()
	_throw_bar.show_percentage = false
	_throw_bar.max_value = 1.0
	_throw_bar.set_anchors_preset(Control.PRESET_CENTER)
	_throw_bar.offset_left = -70.0
	_throw_bar.offset_right = 70.0
	_throw_bar.offset_top = 110.0
	_throw_bar.offset_bottom = 124.0
	_throw_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.55)
	back.set_corner_radius_all(3)
	_throw_bar.add_theme_stylebox_override("background", back)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.7, 0.2)
	fill.set_corner_radius_all(3)
	_throw_bar.add_theme_stylebox_override("fill", fill)
	_throw_bar.visible = false
	$Root.add_child(_throw_bar)


## How hard the throw is charged (0..1); a negative value hides the bar.
func set_throw_power(fraction: float) -> void:
	_throw_bar.visible = fraction >= 0.0
	_throw_bar.value = maxf(fraction, 0.0)


## The quest log at the top right: a short list of the titles of your active quests
## (the phone's Quests app has the descriptions). Hidden while there is no quest.
func _build_quest_log() -> void:
	_quest_log = PanelContainer.new()
	_quest_log.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_quest_log.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_quest_log.offset_left = -300.0
	_quest_log.offset_right = -24.0
	_quest_log.offset_top = 24.0
	_quest_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.6)
	style.border_color = Color(0.85, 0.68, 0.25, 0.9)
	style.border_width_left = 3
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_quest_log.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_quest_log.add_child(column)
	var header := Label.new()
	header.text = "QUESTS"
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	column.add_child(header)
	_quest_rows = VBoxContainer.new()
	_quest_rows.add_theme_constant_override("separation", 2)
	column.add_child(_quest_rows)
	$Root.add_child(_quest_log)
	Quests.changed.connect(_refresh_quest_log)
	Quests.quest_added.connect(_on_quest_added)
	_refresh_quest_log()


func _refresh_quest_log() -> void:
	for child in _quest_rows.get_children():
		_quest_rows.remove_child(child)
		child.queue_free()
	for quest in Quests.quests:
		var label := Label.new()
		label.text = quest.title
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 4)
		_quest_rows.add_child(label)
	_quest_log.visible = not Quests.quests.is_empty()


## A new quest: the log flashes gold for a moment and a message says so.
func _on_quest_added(id: StringName) -> void:
	show_message("New quest: " + str(Quests.get_quest(id).get("title", "")), 4.0)
	_quest_log.modulate = Color(1.6, 1.4, 0.7)
	create_tween().tween_property(_quest_log, "modulate", Color.WHITE, 1.2)


## Shows a message just above the hotbar (above the bill too, when one is open) for a few
## seconds.
func show_message(text: String, seconds: float = 6.0) -> void:
	_toast_id += 1
	var my_id := _toast_id
	toast_label.text = text
	var bottom := -(SLOT_SIZE.y + 60.0)
	if bill_panel.visible:
		bottom = -(118.0 + bill_panel.size.y + 10.0)
	toast_label.offset_bottom = bottom
	toast_label.visible = true
	await get_tree().create_timer(seconds).timeout
	if my_id == _toast_id:  # a newer message may have replaced this one
		toast_label.visible = false


var _carry_box: VBoxContainer
var _ach_panel: PanelContainer
var _ach_title: Label
var _ach_text: Label
var _ach_id: int = 0
var _sleep_label: Label


## The panel on the right side of the screen with the details of the box in your hands
## (half transparent, like the key hints on the left).
func _build_carry_panel() -> void:
	_carry_box = VBoxContainer.new()
	_carry_box.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_carry_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_carry_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_carry_box.offset_left = -360.0
	_carry_box.offset_right = -24.0
	_carry_box.offset_top = -60.0
	_carry_box.offset_bottom = 60.0
	_carry_box.add_theme_constant_override("separation", 2)
	_carry_box.modulate = Color(1, 1, 1, 0.55)
	_carry_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Root.add_child(_carry_box)


## Shows the details of the carried box on the right; an empty list hides the panel.
func set_carry_lines(lines: PackedStringArray) -> void:
	for child in _carry_box.get_children():
		_carry_box.remove_child(child)
		child.queue_free()
	for i in lines.size():
		var label := Label.new()
		label.text = lines[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_size_override("font_size", 15 if i == 0 else 14)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_carry_box.add_child(label)


## A small box that slides down from the top of the screen, like an achievement
## notification: a coloured title line and one line of text.
func _build_achievement_box() -> void:
	_ach_panel = PanelContainer.new()
	_ach_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_ach_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ach_panel.offset_left = -125.0
	_ach_panel.offset_right = 125.0
	_ach_panel.custom_minimum_size = Vector2(250, 0)
	_ach_panel.offset_top = -90.0
	_ach_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.8)
	style.border_color = Color(0.85, 0.68, 0.25)
	style.border_width_left = 4
	style.set_corner_radius_all(5)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 7.0
	_ach_panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_ach_panel.add_child(column)
	_ach_title = Label.new()
	_ach_title.add_theme_font_size_override("font_size", 12)
	column.add_child(_ach_title)
	_ach_text = Label.new()
	_ach_text.add_theme_font_size_override("font_size", 15)
	_ach_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_ach_text)
	_ach_panel.visible = false
	$Root.add_child(_ach_panel)


## Order results and the like: slides in from the top, stays `seconds`, slides out.
func show_achievement(title: String, text: String, good: bool = true, seconds: float = 4.0) -> void:
	_ach_id += 1
	var my_id := _ach_id
	var accent := Color(0.55, 0.9, 0.45) if good else Color(1.0, 0.5, 0.4)
	_ach_title.text = title.to_upper()
	_ach_title.add_theme_color_override("font_color", accent)
	_ach_text.text = text
	(_ach_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = accent
	_ach_panel.visible = true
	_ach_panel.offset_top = -90.0
	var slide_in := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slide_in.tween_property(_ach_panel, "offset_top", 20.0, 0.45)
	await get_tree().create_timer(seconds).timeout
	if my_id != _ach_id:
		return  # a newer one took over
	var slide_out := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	slide_out.tween_property(_ach_panel, "offset_top", -90.0, 0.35)
	await slide_out.finished
	if my_id == _ach_id:
		_ach_panel.visible = false


## The text shown while the player sleeps ("" hides it).
func set_sleep_text(text: String) -> void:
	if _sleep_label == null:
		if text.is_empty():
			return
		_sleep_label = Label.new()
		_sleep_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_sleep_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_sleep_label.offset_left = -300.0
		_sleep_label.offset_right = 300.0
		_sleep_label.offset_top = -150.0
		_sleep_label.offset_bottom = -90.0
		_sleep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sleep_label.add_theme_font_size_override("font_size", 20)
		_sleep_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_sleep_label.add_theme_constant_override("outline_size", 6)
		_sleep_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Root.add_child(_sleep_label)
	_sleep_label.visible = not text.is_empty()
	_sleep_label.text = text


## Called by the Player whenever the Interactor's prompt text changes.
func set_prompt(text: String) -> void:
	prompt_label.visible = not text.is_empty()
	prompt_label.text = "[Click] " + text
