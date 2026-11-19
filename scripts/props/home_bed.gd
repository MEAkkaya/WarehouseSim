class_name HomeBed
extends Interactable
## Your bed. Interact to lie down: the camera moves onto the mattress, the screen darkens
## and the clock runs fast, giving back energy (and health) as the hours go by. Interact
## again whenever you want to get up. The best bed you own decides how much energy a full
## night (`night_hours`) gives (see FurnitureData). The weekly rent is charged at Monday midnight, so sleeping
## through it costs money. Only possible when off shift.

## How many in-game hours a "full night" is: the energy of the bed is spread over this.
@export var night_hours: float = 8.0
## In-game minutes that pass per real second while sleeping (the normal clock is 1).
@export var sleep_minutes_per_second: float = 30.0
## Where on the bed your head rests (in the bed's own space) and how high above the bed.
@export var head_offset: Vector3 = Vector3(0.0, 0.85, -0.6)

var _sleeping: bool = false
## True once the camera is on the mattress: only then does a click get you up (the click that
## made you lie down must not).
var _lying: bool = false
var _player: Player = null
var _normal_speed: float = 1.0
var _hours_slept: float = 0.0
var _energy_before: float = 0.0
var _last_total_hours: float = 0.0


func can_interact(_who: Node) -> bool:
	return not GameState.on_shift and not _sleeping


func get_prompt(_who: Node) -> String:
	return "Lie down and sleep (a full night gives +%d energy)" % roundi(Career.sleep_restore)


func interact(who: Node) -> void:
	var player := who as Player
	if player.frozen or _sleeping:
		return
	_sleeping = true
	_player = player
	player.frozen = true
	player.hud.phone.close()
	_energy_before = GameState.energy
	_hours_slept = 0.0
	_normal_speed = GameState.minutes_per_second
	# Lie down: the camera glides onto the mattress and looks up at the ceiling.
	player.sleep_eye = global_transform * head_offset
	var down := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	down.tween_property(player, "sleep_blend", 1.0, 1.0)
	player.hud.fade_to(0.55, 1.2)
	player.hud.set_sleep_text("Sleeping...   [Left click] Get up")
	await down.finished
	_lying = true
	# Time runs fast from here on.
	GameState.minutes_per_second = sleep_minutes_per_second
	_last_total_hours = GameState.get_total_hours()
	super(who)


## While sleeping: energy and health come back with every hour that passes.
func _process(_delta: float) -> void:
	if not _sleeping or GameState.minutes_per_second != sleep_minutes_per_second:
		return
	var now := GameState.get_total_hours()
	var hours := now - _last_total_hours
	_last_total_hours = now
	if hours <= 0.0:
		return
	_hours_slept += hours
	# (the normal resting regeneration runs as well: the bed adds what is missing to its rate)
	var bed_rate := maxf(0.0, Career.sleep_restore / night_hours - GameState.REST_REGEN_PER_HOUR * Career.regen_multiplier)
	GameState.restore_energy(bed_rate * hours)
	GameState.heal(GameState.max_health / night_hours * hours)


## Left click while lying: get up.
func _unhandled_input(event: InputEvent) -> void:
	if _lying and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_get_up()


func _get_up() -> void:
	if not _sleeping:
		return
	_sleeping = false
	_lying = false
	GameState.minutes_per_second = _normal_speed
	var player := _player
	_player = null
	if not is_instance_valid(player):
		return
	player.hud.set_sleep_text("")
	player.hud.fade_to(0.0, 0.8)
	var up := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	up.tween_property(player, "sleep_blend", 0.0, 0.8)
	await up.finished
	player.frozen = false
	GameState.notice.emit("You slept %.1f hours. Energy %d -> %d." % [
			_hours_slept, roundi(_energy_before), roundi(GameState.energy)])


func _exit_tree() -> void:
	if _sleeping:
		GameState.minutes_per_second = _normal_speed
