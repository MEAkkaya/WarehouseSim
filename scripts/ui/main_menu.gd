extends Control
## The main menu: the first scene the game shows. Continue loads the saved game, New Game
## starts a fresh one (asking first if there is a save), Settings opens the settings
## panel, Exit closes the game. (A placeholder menu - it will be redesigned later.)

const WORLD_SCENE := "res://scenes/levels/world.tscn"

@onready var _column: Control = $Center/Column
@onready var _continue_button: Button = $Center/Column/ContinueButton
@onready var _new_button: Button = $Center/Column/NewGameButton
@onready var _settings_button: Button = $Center/Column/SettingsButton
@onready var _exit_button: Button = $Center/Column/ExitButton

var _settings: SettingsMenu = null
var _confirm: ConfirmationDialog = null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SaveGame.active = false  # nothing is autosaved while the menu is showing
	GameSettings.load_settings()
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_button.pressed.connect(_on_new_game_pressed)
	_settings_button.pressed.connect(_open_settings)
	_exit_button.pressed.connect(get_tree().quit)
	var summary := SaveGame.describe()
	_continue_button.disabled = summary == ""
	if summary != "":
		_continue_button.text = "Continue  (%s)" % summary
		_continue_button.grab_focus()
	else:
		_new_button.grab_focus()
	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = "Start a new game? Your saved game will be overwritten."
	_confirm.ok_button_text = "New Game"
	_confirm.confirmed.connect(_start_new_game)
	add_child(_confirm)


func _on_continue_pressed() -> void:
	GameState.reset()
	if SaveGame.load_game():
		SaveGame.active = true
		get_tree().change_scene_to_file(WORLD_SCENE)
	else:
		_continue_button.disabled = true


func _on_new_game_pressed() -> void:
	if SaveGame.has_save():
		_confirm.popup_centered()
	else:
		_start_new_game()


func _start_new_game() -> void:
	GameState.reset()  # a fresh game: no money, Monday, 08:00
	SaveGame.pending_player = {}
	SaveGame.active = true
	SaveGame.save()
	get_tree().change_scene_to_file(WORLD_SCENE)


func _open_settings() -> void:
	_column.get_parent().visible = false
	_settings = SettingsMenu.new()
	_settings.closed.connect(_close_settings)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(_settings)
	add_child(center)
	_settings.set_meta("holder", center)


func _close_settings() -> void:
	var holder: Node = _settings.get_meta("holder")
	holder.queue_free()
	_settings = null
	_column.get_parent().visible = true
	_settings_button.grab_focus()
