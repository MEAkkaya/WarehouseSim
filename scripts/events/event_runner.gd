class_name EventRunner
extends Node
## Lives in the warehouse interior and runs today's event for as long as the player is
## inside. If a new day begins while you work, the old event ends and the new one
## (if any) starts. The runner makes the announcement.

var _active: WarehouseEvent = null


func _ready() -> void:
	Career.event_changed.connect(_on_event_changed)
	# Events (dementia shuffles the shelves, earthquakes drop their items...) need the
	# stocked shelves, so wait until the warehouse has finished filling up.
	var queue := get_parent().get_node_or_null("LoadQueue") as LoadQueue
	if queue != null and queue.busy:
		await queue.finished
	if is_inside_tree() and not get_parent().has_meta(&"warmup"):
		_begin(Career.todays_event)


func _exit_tree() -> void:
	_end()


func _on_event_changed(event: EventData) -> void:
	_end()
	_begin(event)


func _begin(event: EventData) -> void:
	if event == null or event.effect_script == null:
		return
	var effect := event.effect_script.new() as WarehouseEvent
	if effect == null:
		push_warning("Event %s has no valid effect script" % event.id)
		return
	effect.data = event
	effect.interior = get_parent() as Node3D
	effect.player = get_tree().get_first_node_in_group("players") as Player
	add_child(effect)
	effect.start()
	_active = effect
	GameState.notice.emit("BOSS ANNOUNCEMENT - %s: %s" % [event.title.to_upper(), event.description])


func _end() -> void:
	if is_instance_valid(_active):
		_active.stop()
	_active = null
