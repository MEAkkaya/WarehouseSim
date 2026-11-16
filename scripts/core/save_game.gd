extends Node
## Saving and loading the game, registered as an AUTOLOAD named "SaveGame".
##
## ONE save slot (user://savegame.json) plus a BACKUP of the previous good save
## (user://savegame.bak). A save is written to a temp file first and only then replaces
## the real one, and the old file is copied to the backup only if it is still readable -
## so a crash while saving, or a damaged file, never costs more than the last few seconds.
## Loading falls back to the backup when the main file cannot be read.
##
## What is saved: the bank, health, energy, the date, the furniture you own, a ban,
## the Stats - and where you stand (position, which way you look) and your hotbar.
##
## THE WAREHOUSE IS NOT SAVED. If you are inside it (clocked in, or in its lobby), you are
## saved as CLOCKED OUT: standing in front of the warehouse, with an empty hotbar (leaving
## drops everything anyway). Closing the game while inside asks first, then clocks you out
## (paying the shift as usual). A crash during a shift loses that shift's unpaid earnings.
##
## The game saves by itself: a second after money changes, when a shift ends, at midnight,
## every 30 seconds and when the window is closed - only while a game is running (`active`,
## set by the main menu), not while the main menu is showing.

const PATH := "user://savegame.json"
const BACKUP_PATH := "user://savegame.bak"
const TEMP_PATH := "user://savegame.tmp"
const VERSION := 1

## True while a game is running (set by the main menu when a game starts). While it is
## true the game window asks us before closing (see _notification).
var active: bool = false:
	set(value):
		active = value
		if is_inside_tree():
			get_tree().auto_accept_quit = not value

## The player's saved position and hotbar, waiting for the Player node of the world scene
## to pick them up (Player._ready calls take_pending_player()).
var pending_player: Dictionary = {}

var _timer: Timer
var _quit_dialog: ConfirmationDialog = null


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 1.0
	_timer.timeout.connect(save)
	add_child(_timer)
	var periodic := Timer.new()
	periodic.wait_time = 30.0
	periodic.autostart = true
	periodic.timeout.connect(save)
	add_child(periodic)
	GameState.bank_changed.connect(func(_b: int) -> void: _queue_save())
	GameState.day_started.connect(func(_d: int) -> void: _queue_save())
	GameState.shift_changed.connect(func(on: bool) -> void:
		if not on:
			_queue_save())
	Career.retired.connect(_queue_save)
	get_tree().auto_accept_quit = not active


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST or not active:
		return
	if _in_warehouse():
		_ask_before_quitting()
	else:
		save()
		get_tree().quit()


func _queue_save() -> void:
	if active and _timer.is_stopped():
		_timer.start()


# ---- Closing the game inside the warehouse ---------------------------------------------

func _in_warehouse() -> bool:
	var site := get_tree().get_first_node_in_group("warehouse_site") as WarehouseSite
	return GameState.on_shift or (site != null and site.is_open())


func _ask_before_quitting() -> void:
	if _quit_dialog == null:
		_quit_dialog = ConfirmationDialog.new()
		_quit_dialog.title = "Leave the game?"
		_quit_dialog.dialog_text = "You are in the warehouse.\n\nIf you quit now you are saved as CLOCKED OUT " \
				+ "(your shift is paid), and when you load the game again you will appear in front of the warehouse."
		_quit_dialog.ok_button_text = "Clock out and quit"
		_quit_dialog.cancel_button_text = "Stay"
		_quit_dialog.confirmed.connect(_check_out_and_quit)
		add_child(_quit_dialog)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_quit_dialog.popup_centered()


func _check_out_and_quit() -> void:
	var player := get_tree().get_first_node_in_group("players") as Player
	if player != null:
		player.drop_everything()
	GameState.clock_out()  # pays the shift, like walking out would
	save()
	get_tree().quit()


# ---- Reading ---------------------------------------------------------------------------

func has_save() -> bool:
	return not _read().is_empty()


## A short description of the save for the menu ("Fri, $1,200"), or "" without a save.
func describe() -> String:
	var data := _read()
	if data.is_empty():
		return ""
	var game: Dictionary = data.get("game", {})
	var weekday := (int(game.get("day", 1)) - 1 + GameState.START_WEEKDAY) % 7
	return "%s, $%d" % [GameState.WEEKDAYS[weekday], int(game.get("bank", 0))]


## Starts from the file: call GameState.reset() first (the menu does). False = no
## usable save (neither the main file nor the backup).
func load_game() -> bool:
	var data := _read()
	if data.is_empty():
		return false
	GameState.load_save_data(data.get("game", {}))
	Career.load_save_data(data.get("career", {}))
	Stats.load_save_data(data.get("stats", {}))
	Quests.load_save_data(data.get("quests", []))
	pending_player = data.get("player", {})
	return true


## The Player calls this when the world starts: its saved position and hotbar (once).
func take_pending_player() -> Dictionary:
	var data := pending_player
	pending_player = {}
	return data


## The main file if it is readable, otherwise the backup, otherwise {}.
func _read() -> Dictionary:
	var data := _read_file(PATH)
	if data.is_empty():
		data = _read_file(BACKUP_PATH)
	return data


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# (A JSON instance reports a broken file as an error code instead of printing errors.)
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = json.data
	if parsed is Dictionary and int(parsed.get("version", 0)) == VERSION \
			and parsed.get("game") is Dictionary and (parsed["game"] as Dictionary).has("bank"):
		return parsed
	return {}


# ---- Writing ---------------------------------------------------------------------------

func save() -> void:
	if not active:
		return
	var data := {
		"version": VERSION,
		"game": GameState.get_save_data(),
		"career": Career.get_save_data(),
		"stats": Stats.get_save_data(),
		"quests": Quests.get_save_data(),
	}
	var player_data := _get_player_data()
	if not player_data.is_empty():
		data["player"] = player_data
	_write(JSON.stringify(data, "\t"))


## Temp file first, then the old good file becomes the backup, then the temp file
## becomes the save.
func _write(text: String) -> void:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveGame: could not write %s" % TEMP_PATH)
		return
	file.store_string(text)
	file.close()
	if not _read_file(TEMP_PATH).is_empty():  # never replace a save with a broken one
		if not _read_file(PATH).is_empty():
			DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(BACKUP_PATH))
		if FileAccess.file_exists(PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(PATH))


func delete_save() -> void:
	for path in [PATH, BACKUP_PATH, TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ---- The player ------------------------------------------------------------------------

## Position, look direction and hotbar. Inside the warehouse: in front of its door, with
## nothing in the hotbar (see the top of this file). {} when there is no player (menu).
func _get_player_data() -> Dictionary:
	var player := get_tree().get_first_node_in_group("players") as Player
	if player == null:
		return {}
	var data := {}
	if _in_warehouse():
		var site := get_tree().get_first_node_in_group("warehouse_site") as WarehouseSite
		var front := site.wake_position if site != null else Vector3(0, 0.1, 17)
		data["position"] = [front.x, front.y, front.z]
		data["yaw"] = 0.0
		data["pitch"] = 0.0
		data["inventory"] = []
		data["selected"] = 0
		return data
	data["position"] = [player.global_position.x, player.global_position.y, player.global_position.z]
	data["yaw"] = player._yaw
	data["pitch"] = player._pitch
	var ids: Array = []
	for entry in player.inventory.slots:
		# (Bills only exist at work.) Empty slots stay empty so the layout is kept.
		ids.append(String(entry.item.id) if entry != null and entry.kind == InventoryEntry.Kind.ITEM else "")
	data["inventory"] = ids
	data["selected"] = player.inventory.selected
	return data


## The ItemData with this id (see ItemCatalog).
func find_item(id: String) -> ItemData:
	return ItemCatalog.find(id)
