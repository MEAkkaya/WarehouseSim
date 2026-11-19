class_name DevPage
extends ScrollContainer
## ============================================================================================
##  DEVELOPMENT ONLY - DELETE BEFORE PUBLISHING THE GAME.
##  To remove the dev tools completely:
##    1. delete the folder scripts/dev/ (this file and its .uid),
##    2. in scripts/ui/phone.gd delete the lines marked "DEV-ONLY" (the call in _build_ui and the
##       function _build_dev_app at the end of the file).
##  (docs/DEV_TOOLS.md repeats this. Until then the app only exists in debug builds: exported
##  release builds have OS.is_debug_build() == false, so it never shows there.)
## ============================================================================================
##
## The phone's "Dev" app: cheats for testing - skip time, change the clock speed, money,
## energy, clock in/out, blackout, and teleport to the places of the town.

## False in a release export: the phone then does not even build the app.
static var AVAILABLE: bool = OS.is_debug_build()

## Emitted after a teleport, so the phone can be put away and you see where you are.
signal teleported

const FONT := 13

## The places to teleport to: where to stand and which point to look at (x, z of the world).
## The height comes from the ground below. Tunnels and lakes are added from the town layout.
const PLACES := [
	{"name": "Start (neighbourhood)", "at": Vector2(4, 100), "look": Vector2(30, 100)},
	{"name": "Warehouse entrance", "at": Vector2(0, 17), "look": Vector2(0, 0)},
	{"name": "Home", "at": Vector2(24, 98), "look": Vector2(31.4, 98)},
	{"name": "Gambling apartment", "at": Vector2(42, 136), "look": Vector2(42, 130)},
	{"name": "Club apartment", "at": Vector2(60, 136), "look": Vector2(60, 130)},
	{"name": "Park", "at": Vector2(-46, 128), "look": Vector2(-46, 110)},
]

var player: Player = null

var _position_label: Label
var _clock_label: Label
var _infinite_energy: bool = false


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	add_child(column)

	var warning := _label(column, "DEVELOPMENT ONLY - remove before release (see docs/DEV_TOOLS.md)")
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_clock_label = _label(column, "")
	_position_label = _label(column, "")

	_section(column, "Time")
	var time := _grid(column)
	_button(time, "+1 hour", func() -> void: GameState.advance_hours(1.0))
	_button(time, "+6 hours", func() -> void: GameState.advance_hours(6.0))
	_button(time, "To 06:00", func() -> void: _skip_to(6.0))
	_button(time, "To 08:00 (next day)", func() -> void: _skip_to(8.0))
	_button(time, "To noon", func() -> void: _skip_to(12.0))
	_button(time, "To 18:00", func() -> void: _skip_to(18.0))
	_button(time, "To 23:00", func() -> void: _skip_to(23.0))
	_button(time, "To midnight", func() -> void: _skip_to(0.0))
	var speed := _grid(column)
	_button(speed, "Speed x1", func() -> void: _set_speed(1.0))
	_button(speed, "x5", func() -> void: _set_speed(5.0))
	_button(speed, "x20", func() -> void: _set_speed(20.0))
	_button(speed, "x60", func() -> void: _set_speed(60.0))
	var freeze := CheckBox.new()
	freeze.text = "Freeze the clock"
	freeze.add_theme_font_size_override("font_size", FONT)
	freeze.toggled.connect(func(on: bool) -> void: GameState.clock_running = not on)
	column.add_child(freeze)

	_section(column, "Money and shift")
	var money := _grid(column)
	_button(money, "+$1,000", func() -> void: GameState.add_money(1_000))
	_button(money, "+$100,000", func() -> void: GameState.add_money(100_000))
	_button(money, "Clock in", func() -> void: GameState.clock_in())
	_button(money, "Clock out", func() -> void: GameState.clock_out())
	_button(money, "Multiplier +0.5", func() -> void: _add_multiplier(0.5))
	var blackout := CheckBox.new()
	blackout.text = "Power outage (blackout, on shift)"
	blackout.add_theme_font_size_override("font_size", FONT)
	blackout.toggled.connect(func(on: bool) -> void: GameState.blackout = on)
	column.add_child(blackout)

	_section(column, "Body")
	var body := _grid(column)
	_button(body, "Refill energy", func() -> void: GameState.restore_energy(GameState.max_energy))
	_button(body, "Refill health", func() -> void: GameState.heal(GameState.max_health))
	var infinite := CheckBox.new()
	infinite.text = "Infinite energy"
	infinite.add_theme_font_size_override("font_size", FONT)
	infinite.toggled.connect(func(on: bool) -> void: _infinite_energy = on)
	column.add_child(infinite)

	_section(column, "Teleport")
	var places := _grid(column)
	for place: Dictionary in _all_places():
		_button(places, place.name as String, func() -> void: _teleport(place))
	_button(places, "Copy my position", func() -> void:
		if player != null:
			DisplayServer.clipboard_set("Vector2(%d, %d)" % [roundi(player.global_position.x), roundi(player.global_position.z)]))


func _process(_delta: float) -> void:
	if _infinite_energy:
		GameState.restore_energy(GameState.max_energy)
	if not is_visible_in_tree():
		return
	_clock_label.text = "%s   day %d   speed x%.0f" % [GameState.get_clock_text(), GameState.day, GameState.minutes_per_second]
	if player != null:
		var p := player.global_position
		_position_label.text = "You are at x %.1f   y %.1f   z %.1f" % [p.x, p.y, p.z]


# ---- Cheats --------------------------------------------------------------------------------

## Moves the clock forward to the next time it is `hour` (a whole day when it already is).
func _skip_to(hour: float) -> void:
	var wait := fposmod(hour - GameState.hour, 24.0)
	if wait < 0.01:
		wait = 24.0
	GameState.advance_hours(wait)


func _set_speed(minutes_per_second: float) -> void:
	GameState.minutes_per_second = minutes_per_second


func _add_multiplier(amount: float) -> void:
	GameState.multiplier += amount
	GameState.multiplier_changed.emit(GameState.multiplier, GameState.shift_earnings)


## The fixed places plus the tunnels and lakes of the current town layout.
func _all_places() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for place: Dictionary in PLACES:
		list.append(place)
	list.append({"name": "Station", "at": TownLayout.STATION_SPOT + Vector2(0, 14), "look": TownLayout.STATION_SPOT})
	var number := 1
	for tunnel in TownLayout.TUNNELS:
		var spot: Vector2 = tunnel.spot
		var dir: Vector2 = tunnel.dir
		list.append({"name": "Tunnel %d" % number, "at": spot - dir * 14.0, "look": spot})
		number += 1
	for lake in TownLayout.LAKES:
		var center: Vector2 = lake.center
		var radius: Vector2 = lake.radius
		list.append({"name": "Lake " + String(lake.name).capitalize(), "at": center + Vector2(radius.x + 8.0, 0), "look": center,
				"dry": true})   # (the shore is uneven: step away from the water until the ground is dry)
	return list


func _teleport(place: Dictionary) -> void:
	if player == null:
		return
	var at: Vector2 = place.at
	var look: Vector2 = place.look
	var ground := _ground_at(at)
	if place.get("dry", false) and ground < 0.0:
		at = _nearest_shore(look)
		ground = _ground_at(at)
	var forward := look - at
	var yaw := atan2(-forward.x, -forward.y)
	player.teleport_to(Vector3(at.x, ground + 0.05, at.y), yaw)
	teleported.emit()


## The nearest dry spot to a lake's centre (the shore is uneven and lakes overlap, so eight
## directions are tried and the shortest walk out of the water wins; plus a few metres of beach).
func _nearest_shore(center: Vector2) -> Vector2:
	var best := center
	var best_distance := INF
	for k in 8:
		var dir := Vector2.from_angle(TAU * k / 8.0)
		var d := 6.0
		var dry_run := 0   # (a thin strip of dry ground in the water, a road for instance, does not count)
		while d < 130.0 and dry_run < 4:
			dry_run = dry_run + 1 if _ground_at(center + dir * d) >= 0.0 else 0
			d += 3.0
		d -= 3.0 * dry_run   # back to where the dry stretch began
		if d < best_distance:
			best_distance = d
			best = center + dir * (d + 4.0)
	return best


## The height of the ground at (x, z): a ray from high above (the player itself is ignored).
## A hit above 6 m is a roof or a tree, so it is not used.
func _ground_at(at: Vector2) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, 60.0, at.y), Vector3(at.x, -5.0, at.y))
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit.position as Vector3).y > 6.0:
		return 0.09
	return (hit.position as Vector3).y


# ---- Building the rows ---------------------------------------------------------------------

func _label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT)
	parent.add_child(label)
	return label


func _section(parent: Control, text: String) -> void:
	var label := _label(parent, text.to_upper())
	label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.35))


func _grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)
	return grid


func _button(parent: Control, text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", FONT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.pressed.connect(on_pressed)
	parent.add_child(button)
