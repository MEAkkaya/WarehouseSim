class_name Phone
extends Control
## The player's phone: hidden at the bottom right of the screen, opened and put
## away with the Esc key. It slides up; the HOME page shows the day and time and a grid
## of apps, four to a row, that scrolls when there are more than fit. The apps show
## no name: hover one to read it below the grid. Put an icon file at
## assets/icons/phone/<app id>.png (ids: bank, map, notices, ranking, stats, places,
## quests, pause, settings, menu) and it replaces the letter on the button.
##
## Apps: Bank (balance and progress towards $1,000,000), Map, Notices, Ranking, Stats,
## Places, Quests, Pause (pauses the game; closing the phone resumes it), Settings
## (volume, fullscreen, mouse sensitivity) and Main Menu (saves and leaves).
##
## The game does NOT pause while the phone is out (unless you use the Pause app) -
## using it at work is a good way to get caught. Settings and Main Menu do not count as
## phone use for the supervisors. While it is open the mouse is free to tap the apps,
## so you cannot look around (you can still walk).
##
## The whole screen is built in code below, which keeps the scene file trivial.

const WIDTH := 340.0
const HEIGHT := 590.0
## Apps per row on the home screen, the size of an app button and the gap between them.
const APP_COLUMNS := 4
const APP_SIZE := 64.0
const APP_GAP := 12.0
const ICON_FOLDER := "res://assets/icons/phone/"
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
var _settings_page: Control
var _menu_page: Control
var _current_page: Control
var _paused_label: Label
var _app_caption: Label
var _volume_slider: HSlider
var _fullscreen_box: CheckBox
var _sensitivity_slider: HSlider
var _sensitivity_label: Label
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
	process_mode = Node.PROCESS_MODE_ALWAYS   # the phone works while the game is paused (Pause app)
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
	_refresh_paused_label()
	_refresh()
	# A free cursor so the apps can be tapped.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_phone_use()
	_slide_to(1.0)


func close() -> void:
	if not is_open:
		return
	is_open = false
	if _current_page == _settings_page:
		GameSettings.save_settings()
	if get_tree().paused:
		get_tree().paused = false   # putting the phone away resumes a paused game
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_phone_use()
	_slide_to(0.0)


## Settings and Main Menu are not "using the phone": the supervisors do not mind.
func counts_as_phone_use() -> bool:
	return is_open and _current_page != _settings_page and _current_page != _menu_page


func _update_phone_use() -> void:
	GameState.set_phone_open(counts_as_phone_use())


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
	if _current_page == _settings_page and page != _settings_page:
		GameSettings.save_settings()
	_current_page = page
	_refresh()
	for p in [_home_page, _bank_page, _map_page, _rules_page, _ranking_page, _stats_page, _places_page,
			_quests_page, _settings_page, _menu_page]:
		p.visible = p == page
	if page == _map_page:
		_map.player = _player
	if page == _settings_page:
		_volume_slider.set_value_no_signal(GameSettings.master_volume)
		_fullscreen_box.set_pressed_no_signal(GameSettings.fullscreen)
		_sensitivity_slider.set_value_no_signal(GameSettings.mouse_sensitivity)
		_update_sensitivity_label()
	if is_open:
		_update_phone_use()


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
	_paused_label = _make_label(_home_page, "GAME PAUSED", 16)
	_paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paused_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))
	_paused_label.custom_minimum_size = Vector2(0, 22)   # (keeps its room, so the grid does not jump)
	_paused_label.text = ""
	_add_gap(_home_page, 8)
	# the apps: a grid that scrolls when it is taller than the space
	var apps_scroll := ScrollContainer.new()
	apps_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	apps_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_home_page.add_child(apps_scroll)
	var apps := GridContainer.new()
	apps.columns = APP_COLUMNS
	apps.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	apps.add_theme_constant_override("h_separation", int(APP_GAP))
	apps.add_theme_constant_override("v_separation", int(APP_GAP))
	apps_scroll.add_child(apps)
	_add_app(apps, "bank", "$", func() -> void: _show_page(_bank_page))
	_add_app(apps, "map", "N", func() -> void: _show_page(_map_page))
	_add_app(apps, "notices", "!", func() -> void: _show_page(_rules_page))
	_add_app(apps, "ranking", "#", func() -> void: _show_page(_ranking_page))
	_add_app(apps, "stats", "%", func() -> void: _show_page(_stats_page))
	_add_app(apps, "places", "@", func() -> void: _show_page(_places_page))
	_add_app(apps, "quests", "?", func() -> void: _show_page(_quests_page))
	_add_app(apps, "pause", "II", _toggle_pause)
	_add_app(apps, "settings", "=", func() -> void: _show_page(_settings_page))
	_add_app(apps, "menu", "<", func() -> void: _show_page(_menu_page))
	# the name of the app under the mouse (the buttons themselves show no name)
	_app_caption = _make_label(_home_page, "", 18)
	_app_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_app_caption.custom_minimum_size = Vector2(0, 30)
	_add_gap(_home_page, 6)

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

	# Settings app: the same three settings as the main menu's, applied at once
	_settings_page = VBoxContainer.new()
	_settings_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_child(_settings_page)
	_make_label(_settings_page, "SETTINGS", 22)
	_add_spacer(_settings_page, 10)
	_make_label(_settings_page, "Master volume", 15)
	_volume_slider = _make_slider(_settings_page, 0.0, 1.0, 0.05)
	_volume_slider.value_changed.connect(func(v: float) -> void:
		GameSettings.master_volume = v
		GameSettings.apply())
	_add_spacer(_settings_page, 10)
	_fullscreen_box = CheckBox.new()
	_fullscreen_box.text = "Fullscreen"
	_fullscreen_box.toggled.connect(func(on: bool) -> void:
		GameSettings.fullscreen = on
		GameSettings.apply())
	_settings_page.add_child(_fullscreen_box)
	_add_spacer(_settings_page, 10)
	_sensitivity_label = _make_label(_settings_page, "", 15)
	_sensitivity_slider = _make_slider(_settings_page, 0.0008, 0.006, 0.0001)
	_sensitivity_slider.value_changed.connect(func(v: float) -> void:
		GameSettings.mouse_sensitivity = v
		if _player != null:
			_player.mouse_sensitivity = v
		_update_sensitivity_label())
	_add_spacer(_settings_page)
	_settings_page.add_child(_make_back_button())

	# Main Menu app: save and leave to the main menu
	_menu_page = VBoxContainer.new()
	_menu_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_child(_menu_page)
	_make_label(_menu_page, "MAIN MENU", 22)
	_add_spacer(_menu_page, 10)
	var menu_note := _make_label(_menu_page, "Leave to the main menu? The game is saved. If you are in the warehouse you are clocked out first (your shift is paid) and carried things stay behind.", 15)
	menu_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_spacer(_menu_page)
	var leave := Button.new()
	leave.text = "Exit to main menu"
	leave.custom_minimum_size = Vector2(0, 44)
	leave.pressed.connect(func() -> void: SaveGame.exit_to_main_menu())
	_menu_page.add_child(leave)
	_menu_page.add_child(_make_back_button())


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


## A fixed gap (a spacer takes all the space left over).
func _add_gap(parent: Control, height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	parent.add_child(gap)


func _add_spacer(parent: Control, min_height: float = 0.0) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, min_height)
	parent.add_child(spacer)


## An app button on the home screen: no name (it shows below the grid while the mouse is on it).
## It shows assets/icons/phone/<id>.png when that file exists, else the `glyph`.
func _add_app(grid: GridContainer, id: String, glyph: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(APP_SIZE, APP_SIZE)
	button.add_theme_font_size_override("font_size", 26)
	var icon_path := ICON_FOLDER + id + ".png"
	if ResourceLoader.exists(icon_path):
		button.icon = load(icon_path)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		button.text = glyph
	button.pressed.connect(on_pressed)
	button.mouse_entered.connect(func() -> void: _app_caption.text = _app_name(id))
	button.mouse_exited.connect(func() -> void: _app_caption.text = "")
	grid.add_child(button)


## What an app is called (the caption under the grid).
func _app_name(id: String) -> String:
	match id:
		"bank": return "Bank"
		"map": return "Map"
		"notices": return "Notices"
		"ranking": return "Ranking"
		"stats": return "Stats"
		"places": return "Places"
		"quests": return "Quests"
		"pause": return "Resume game" if get_tree().paused else "Pause game"
		"settings": return "Settings"
		"menu": return "Main menu"
	return id.capitalize()


## The Pause app: freezes (or resumes) the whole game. Putting the phone away resumes it.
func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_refresh_paused_label()
	_app_caption.text = _app_name("pause")


func _refresh_paused_label() -> void:
	_paused_label.text = "GAME PAUSED" if get_tree().paused else ""


## Every app's Back button returns to the home screen (Esc puts the phone away).
func _make_back_button() -> Button:
	var button := Button.new()
	button.text = "Back"
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(func() -> void: _show_page(_home_page))
	return button


func _make_slider(parent: Control, low: float, high: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size = Vector2(0, 26)
	parent.add_child(slider)
	return slider


func _update_sensitivity_label() -> void:
	_sensitivity_label.text = "Mouse sensitivity (%.1f)" % (GameSettings.mouse_sensitivity / 0.0025)
