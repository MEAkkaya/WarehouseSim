class_name Phone
extends Control
## The player's phone: hidden at the bottom right of the screen, opened and put
## away with the P key. It slides up; the HOME page shows the day and time and two
## apps - Bank (balance and progress towards $1,000,000) and Map (navigation).
## Each app has a Back button that puts the phone away.
##
## The game does NOT pause while the phone is out - using it at work is a good way
## to get caught. While it is open the mouse is free to tap the apps, so you cannot
## look around (you can still walk).
##
## The whole screen is built in code below, which keeps the scene file trivial.

const WIDTH := 250.0
const HEIGHT := 480.0
const MARGIN := 24.0

## How long the slide up/down takes, in seconds.
@export var slide_seconds: float = 0.35

var is_open: bool = false

var _tween: Tween = null
var _home_page: Control
var _bank_page: Control
var _map_page: Control
var _rules_page: Control
var _ranking_page: Control
var _quests_page: Control
var _quests_list: VBoxContainer
var _stats_page: Control
var _places_page: Control
var _stats_label: Label
var _places_label: Label
var _rules_label: Label
var _ranking_label: Label
var _time_label: Label
var _day_label: Label
var _balance_label: Label
var _progress_bar: ProgressBar
var _progress_label: Label
var _unpaid_label: Label
var _map: MapView
var _player: Player = null


func _ready() -> void:
	# Find the player this HUD belongs to (Phone -> Root -> HUD -> Player).
	var node: Node = self
	while node != null and not node is Player:
		node = node.get_parent()
	_player = node as Player
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_apply_slide(0.0)
	visible = false
	GameState.time_changed.connect(_refresh)
	GameState.bank_changed.connect(_refresh)
	GameState.multiplier_changed.connect(_refresh)
	Career.event_changed.connect(_refresh)
	GameState.day_started.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("phone"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	_show_page(_home_page)
	_refresh()
	# A free cursor so the apps can be tapped.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.set_phone_open(true)
	_slide_to(1.0)


func close() -> void:
	if not is_open:
		return
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.set_phone_open(false)
	_slide_to(0.0)


func _slide_to(target: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_apply_slide, _slide, target, slide_seconds)
	if target == 0.0:
		_tween.tween_callback(func() -> void: visible = false)


var _slide: float = 0.0


## 0 = hidden below the screen edge, 1 = fully up.
func _apply_slide(amount: float) -> void:
	_slide = amount
	offset_left = -WIDTH - MARGIN
	offset_right = -MARGIN
	offset_top = lerpf(12.0, -HEIGHT - MARGIN, amount)
	offset_bottom = offset_top + HEIGHT


func _refresh(_a: Variant = null, _b: Variant = null) -> void:
	if _time_label == null:
		return
	var minutes := int(GameState.hour * 60.0)
	_time_label.text = "%02d:%02d" % [minutes / 60, minutes % 60]
	_day_label.text = GameState.get_weekday_name()
	_stats_label.text = Stats.get_text()
	_refresh_quests()
	_places_label.text = _places_text()
	_balance_label.text = "$" + _money(GameState.bank)
	_progress_bar.max_value = GameState.GOAL
	_progress_bar.value = GameState.bank
	_progress_label.text = "%.2f%% of $%s" % [100.0 * GameState.bank / GameState.GOAL, _money(GameState.GOAL)]
	_rules_label.text = Career.get_notice_text()
	var lines: PackedStringArray = []
	var rank := 0
	for entry in Career.get_ranking():
		rank += 1
		lines.append("%d. %s%s   %d" % [rank, entry.name, " <" if entry.is_player else "", entry.score])
	_ranking_label.text = "Orders today\n" + "\n".join(lines)
	if GameState.on_shift:
		_unpaid_label.text = "Unpaid this shift: $%s  (x%.2f)" % [_money(GameState.get_pending_payout()), GameState.multiplier]
	else:
		_unpaid_label.text = "Not on shift"


## 1234567 -> "1,234,567"
func _money(amount: int) -> String:
	var digits := str(amount)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out


func _show_page(page: Control) -> void:
	_refresh()
	for p in [_home_page, _bank_page, _map_page, _rules_page, _ranking_page, _stats_page, _places_page, _quests_page]:
		p.visible = p == page
	if page == _map_page:
		_map.player = _player


# ---- Building the screen -----------------------------------------------------------

func _build_ui() -> void:
	var shell := PanelContainer.new()
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_stylebox_override("panel", _style(Color(0.06, 0.06, 0.08), 30, 9))
	add_child(shell)
	var screen := PanelContainer.new()
	screen.add_theme_stylebox_override("panel", _style(Color(0.1, 0.14, 0.22), 22, 14))
	shell.add_child(screen)
	var pages := VBoxContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(pages)

	# Home: time, day and the apps
	_home_page = VBoxContainer.new()
	_home_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_child(_home_page)
	_time_label = _make_label(_home_page, "08:00", 56)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label = _make_label(_home_page, "Monday", 22)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add_spacer(_home_page)
	var apps := GridContainer.new()
	apps.columns = 2
	apps.add_theme_constant_override("h_separation", 18)
	apps.add_theme_constant_override("v_separation", 8)
	var apps_center := CenterContainer.new()
	apps_center.add_child(apps)
	_home_page.add_child(apps_center)
	apps.add_child(_make_app_button("$\nBank", func() -> void: _show_page(_bank_page)))
	apps.add_child(_make_app_button("N\nMap", func() -> void: _show_page(_map_page)))
	apps.add_child(_make_app_button("!\nNotices", func() -> void: _show_page(_rules_page)))
	apps.add_child(_make_app_button("#\nRanking", func() -> void: _show_page(_ranking_page)))
	apps.add_child(_make_app_button("%\nStats", func() -> void: _show_page(_stats_page)))
	apps.add_child(_make_app_button("@\nPlaces", func() -> void: _show_page(_places_page)))
	apps.add_child(_make_app_button("?\nQuests", func() -> void: _show_page(_quests_page)))
	_add_spacer(_home_page, 20)

	# Bank app
	_bank_page = VBoxContainer.new()
	_bank_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_child(_bank_page)
	_make_label(_bank_page, "BANK", 22)
	_balance_label = _make_label(_bank_page, "$0", 40)
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(0, 22)
	_progress_bar.add_theme_stylebox_override("background", _style(Color(0.05, 0.07, 0.1), 6, 0))
	_progress_bar.add_theme_stylebox_override("fill", _style(Color(0.3, 0.8, 0.45), 6, 0))
	_bank_page.add_child(_progress_bar)
	_progress_label = _make_label(_bank_page, "0.00% of $1,000,000", 14)
	_add_spacer(_bank_page, 10)
	_unpaid_label = _make_label(_bank_page, "Not on shift", 15)
	_unpaid_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_spacer(_bank_page)
	_bank_page.add_child(_make_back_button())

	# Map app
	_map_page = VBoxContainer.new()
	_map_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_child(_map_page)
	_make_label(_map_page, "MAP", 22)
	_map = MapView.new()
	_map_page.add_child(_map)
	_make_label(_map_page, "Red arrow: you.  Yellow dot: warehouse door.  Red / pink dots: back room and club.", 12).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_spacer(_map_page)
	_map_page.add_child(_make_back_button())

	# Notice board: the fixed rules and the boss' event of the day
	_rules_page = VBoxContainer.new()
	_rules_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_child(_rules_page)
	_make_label(_rules_page, "NOTICE BOARD", 22)
	_add_spacer(_rules_page, 6)
	_rules_label = _make_label(_rules_page, "", 15)
	_rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_spacer(_rules_page)
	_rules_page.add_child(_make_back_button())

	# Ranking app: best employee of the day
	_ranking_page = VBoxContainer.new()
	_ranking_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_child(_ranking_page)
	_make_label(_ranking_page, "RANKING", 22)
	_ranking_label = _make_label(_ranking_page, "", 17)
	_add_spacer(_ranking_page)
	var ranking_note := _make_label(_ranking_page, "Best employee of the day (3+ orders) gets a bonus at midnight.", 13)
	ranking_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_spacer(_ranking_page, 6)
	_ranking_page.add_child(_make_back_button())

	# Stats app: days passed and everything else we count
	_stats_page = VBoxContainer.new()
	_stats_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_child(_stats_page)
	_make_label(_stats_page, "STATS", 22)
	_stats_label = _make_label(_stats_page, "", 13)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_spacer(_stats_page)
	_stats_page.add_child(_make_back_button())

	# Quests app: the quest log with descriptions
	_quests_page = VBoxContainer.new()
	_quests_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_child(_quests_page)
	_make_label(_quests_page, "QUESTS", 22)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_quests_page.add_child(scroll)
	_quests_list = VBoxContainer.new()
	_quests_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quests_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_quests_list)
	_quests_page.add_child(_make_back_button())

	# Places app: where to go, and when it is open
	_places_page = VBoxContainer.new()
	_places_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_child(_places_page)
	_make_label(_places_page, "PLACES", 22)
	_places_label = _make_label(_places_page, "", 14)
	_places_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_spacer(_places_page)
	_places_page.add_child(_make_back_button())


## Rebuilds the quest list: every quest with its title and (if it has one) description.
func _refresh_quests() -> void:
	for child in _quests_list.get_children():
		_quests_list.remove_child(child)
		child.queue_free()
	if Quests.quests.is_empty():
		var none := _make_label(_quests_list, "No active quests.", 15)
		none.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
		return
	for quest in Quests.quests:
		var title := _make_label(_quests_list, "* " + quest.title, 17)
		title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if quest.description != "":
			var body := _make_label(_quests_list, quest.description, 13)
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88))


## The venues with opening hours (every TimedDoor registers its venue in a group).
func _places_text() -> String:
	var text := ""
	for node in get_tree().get_nodes_in_group("venues"):
		var door := node as TimedDoor
		text += "%s\n   %s\n   %s\n\n" % [door.venue_name, door.get_hours().describe(),
				"OPEN NOW" if door.get_hours().is_open_now() else "closed right now"]
	if text == "":
		text = "Nothing to see yet."
	return text


func _style(color: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


func _make_label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _add_spacer(parent: Control, min_height: float = 0.0) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, min_height)
	parent.add_child(spacer)


func _make_app_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(88, 68)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(on_pressed)
	return button


## Every app's Back button puts the phone away (the game never paused).
func _make_back_button() -> Button:
	var button := Button.new()
	button.text = "Back"
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(close)
	return button
