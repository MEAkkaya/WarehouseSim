class_name WarehouseSite
extends Node3D
## The warehouse building and its entrance - the LOADING BOUNDARY between the town
## and the job.
##
##   town --[outer door]--> LOBBY --[inner door]--> WAREHOUSE FLOOR
##
## The lobby is part of the building shell and is ALWAYS loaded, so stepping through
## the outer door never shows an empty or half-built room. The warehouse interior is
## created while you stand in the lobby; the inner door stays shut until it is fully
## ready and then slides down into the floor. Leaving the lobby back to town deletes the interior, so
## nothing inside is updated or drawn while you are outside.
##
##   - LobbyZone: standing in the lobby (or on the floor) keeps the interior loaded.
##   - WorkZone:  being on the warehouse floor means you are clocked in. Stepping
##                back into the lobby clocks you out; what you carry stays behind.
##
## Both zones are Area3D nodes that detect the player.

## The interior to create on entry (scenes/levels/warehouse.tscn).
@export var interior_scene: PackedScene
## Where the interior is added (a Node3D at the world origin).
@export var interior_parent: Node3D
## The door between lobby and warehouse floor (a CSGBox3D). It is shut while the
## interior is loading or absent.
@export var inner_door: CSGBox3D
## Where the player wakes up after passing out (just outside the door).
@export var wake_position: Vector3 = Vector3(0, 0.1, 17)

## Seconds the door takes to open or close fully, and how far it slides (negative =
## down into the floor, which keeps it hidden).
@export var door_open_seconds: float = 0.8
@export var door_close_seconds: float = 0.8
@export var door_slide: float = -3.1

## The currently loaded interior (null while the player is outside).
var interior: Node = null

var _in_lobby: bool = false
var _in_work: bool = false
var _player: Player = null
var _loading: bool = false
## True during the warm-up at the start of the game (see _warm_up).
var _warming_up: bool = false
## True while the old interior is being taken apart (a new one waits for that).
var _destroying: bool = false
## Interior nodes that are made but not yet added to the building (see _load_interior).
var _staged: Array[Node] = []
## True while the door is sliding shut before the interior is deleted.
var _closing: bool = false
var _door_closed_y: float = 0.0
var _door_tween: Tween = null

@onready var _lobby_zone: Area3D = $LobbyZone
@onready var _work_zone: Area3D = $WorkZone


func _ready() -> void:
	add_to_group("warehouse_site")  # SaveGame finds us through this
	ItemCatalog.get_all()  # load every item (and model) now, not at the first entry
	_door_closed_y = inner_door.position.y
	_lobby_zone.body_entered.connect(_on_zone_changed.bind(true, true))
	_lobby_zone.body_exited.connect(_on_zone_changed.bind(true, false))
	_work_zone.body_entered.connect(_on_zone_changed.bind(false, true))
	_work_zone.body_exited.connect(_on_zone_changed.bind(false, false))
	GameState.passed_out.connect(_on_passed_out)
	Career.caught.connect(_on_caught)
	GameState.knocked_out.connect(_on_knocked_out)
	if not OS.has_environment("NO_WARMUP"):
		_warm_up.call_deferred()


## The very first time anything is drawn (shaders and pipelines compiled, meshes sent to
## the graphics card, CSG built...) costs far more than later times, so the first entry
## into the warehouse would hitch. To avoid that, the game builds the warehouse once at
## the start, behind a black screen, looks through a camera at all of it, and throws it
## away again (sliced, like any exit). Takes about a second; every real entry after
## that is as smooth as the second one.
func _warm_up() -> void:
	var player := get_tree().get_first_node_in_group("players") as Player
	if player == null or interior != null or _loading or _destroying or _in_lobby or _in_work:
		return
	_warming_up = true
	player.frozen = true
	await player.hud.fade_to(1.0, 0.01)
	var camera := Camera3D.new()
	camera.far = 400.0
	add_child(camera)
	camera.make_current()
	_load_interior()
	# Wait until the whole warehouse stands (walls, furniture, shelves, stock).
	var waited := 0.0
	while waited < 10.0 and (interior == null or _loading or (interior.get_node_or_null("LoadQueue") as LoadQueue).busy):
		await get_tree().process_frame
		waited += get_process_delta_time()
	# Look at all of it, so everything gets drawn once.
	var poses := [
		[Vector3(0, 1.7, 6.0), Vector3(0, 1.2, -10.0)],
		[Vector3(0, 2.0, 2.0), Vector3(-20, 1.0, -3.0)],
		[Vector3(0, 2.0, 2.0), Vector3(20, 1.0, -3.0)],
		[Vector3(-6, 4.5, 4.0), Vector3(6, 3.0, -8.0)],
	]
	for pose in poses:
		camera.global_position = pose[0]
		camera.look_at(pose[1])
		for i in 3:
			await get_tree().process_frame
	camera.queue_free()
	player.camera.make_current()
	_warming_up = false
	player.hud.fade_to(0.0, 0.6)
	player.frozen = false
	call_deferred("_sync")  # nobody is here: the warm-up warehouse goes away again


func is_open() -> bool:
	return interior != null


## A ban that ends while the player waits in the lobby lets them in.
func _process(_delta: float) -> void:
	if _in_lobby and interior == null and not _loading and not _destroying and not Career.is_banned():
		call_deferred("_sync")


# `.bind(is_lobby, inside)` appends two extra arguments after the body.
func _on_zone_changed(body: Node3D, is_lobby: bool, inside: bool) -> void:
	if not body is Player:
		return
	_player = body as Player
	if is_lobby:
		_in_lobby = inside
		if inside and _player.riding_bike:
			_player.dismount_bike()  # (the barrier outside normally stops bikes before this)
		if inside and Career.is_banned():
			_player.hud.show_message("You are banned from the warehouse until %s." % Career.get_ban_end_text(), 5.0)
	else:
		_in_work = inside
	# Physics callbacks must not add/remove physics nodes right away (the interior
	# is full of colliders), so the real work waits until the end of the frame.
	call_deferred("_sync")


## Brings the world in line with where the player is.
func _sync() -> void:
	var wanted := (_in_lobby or _in_work) and not Career.is_banned()
	if wanted:
		if interior == null:
			if not _loading and not _destroying:
				_load_interior()
		elif _closing:
			# Came back while the door was closing: just open it again.
			_closing = false
			_open_door()
	elif interior != null and not _loading and not _closing and not _warming_up:
		_begin_unload()
	_update_shift()


## Clock in while on the warehouse floor; clock out (dropping everything) when not.
func _update_shift() -> void:
	var should_work := _in_work and interior != null and not _loading and not _closing
	if should_work and not GameState.on_shift:
		GameState.clock_in()
	elif not should_work and GameState.on_shift:
		if _player != null:
			_player.drop_everything()
		GameState.clock_out()


## The interior is put together over several frames, never in one go. The scene is
## instantiated (that is cheap), then its children are taken out and added one by one
## through the interior's LoadQueue - in the order they are seen: walls and floor
## first, then the furniture, the second-floor slabs, the storage regions (whose
## shelves fill up afterwards) and last the "logic" nodes (stocking, events).
const STAGE_LOGIC: Array[String] = ["SupervisorManager", "VisitGenerator", "EventRunner"]


func _stage_of(node: Node) -> int:
	if node is StorageRegion:
		return 3
	if node.name in STAGE_LOGIC:
		return 4
	if node is CSGShape3D:
		return 2 if node.is_in_group("mezzanine") else 0
	if node is Label3D:
		return 0
	return 1


func _load_interior() -> void:
	_loading = true
	var root := interior_scene.instantiate()
	if _warming_up:
		root.set_meta(&"warmup", true)  # no event, nobody to see it
	interior = root
	var queue := root.get_node("LoadQueue") as LoadQueue
	var stages: Array = [[], [], [], [], []]
	for child in root.get_children():
		root.remove_child(child)
		# A node that remembers its scene owner is slow to re-add (~15 ms each); the
		# owner only matters for the editor, never at run time.
		child.owner = null
		if child == queue:
			continue
		stages[_stage_of(child)].append(child)
		_staged.append(child)
	root.add_child(queue)  # the queue must exist before anything else is added
	interior_parent.add_child(root)
	for stage in 5:
		for node: Node in stages[stage]:
			queue.enqueue(_add_staged.bind(root, node))
		if stage == 1:
			# Walls and furniture are in: give their colliders a couple of frames to
			# register and open the door while the shelves are still being built.
			queue.enqueue(_structure_ready.bind(root))


func _add_staged(root: Node, node: Node) -> void:
	_staged.erase(node)
	if is_instance_valid(root) and is_instance_valid(node):
		root.add_child(node)


func _structure_ready(root: Node) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if interior != root:
		return  # (cannot happen while loading, but be safe)
	_loading = false
	_open_door()
	_update_shift()
	if not (_in_lobby or _in_work) and not _warming_up:
		_begin_unload()  # the player already left while we were loading


## Leaving: clock out now, slide the door shut, and only then delete the interior
## (so the player never sees it vanish through a half-open door).
func _begin_unload() -> void:
	_closing = true
	_update_shift()
	_close_door()


func _finish_unload() -> void:
	var old := interior
	interior = null
	_closing = false
	_destroying = true
	_destroy_sliced(old)


## Takes the old interior apart a few milliseconds per frame instead of freeing
## ~20 000 nodes in one frame. A new interior waits until this is done.
func _destroy_sliced(root: Node) -> void:
	for node in _staged:  # made but never added
		if is_instance_valid(node):
			node.free()
	_staged.clear()
	root.set_meta(&"unloading", true)  # events skip their (pointless) clean-up of the room
	# Stop the builder and the event first, while everything still exists.
	for node_name in ["LoadQueue", "EventRunner", "VisitGenerator", "SupervisorManager"]:
		var node := root.get_node_or_null(node_name)
		if node != null:
			node.free()
	var todo: Array[Node] = [root]
	var expanded := {}
	var start := Time.get_ticks_usec()
	while not todo.is_empty():
		var node: Node = todo.back()
		if node.get_child_count() > 8 and not expanded.has(node.get_instance_id()):
			expanded[node.get_instance_id()] = true
			todo.append_array(node.get_children())  # free the children first
			continue
		todo.pop_back()
		node.free()
		if Time.get_ticks_usec() - start > 4000:
			await get_tree().process_frame
			start = Time.get_ticks_usec()
	_destroying = false
	call_deferred("_sync")  # in case the player walked back in meanwhile


## How open the door is: 0 = shut, 1 = fully open.
func _door_openness() -> float:
	return clampf((inner_door.position.y - _door_closed_y) / door_slide, 0.0, 1.0)


func _open_door() -> void:
	if _door_tween != null:
		_door_tween.kill()
	var remaining := 1.0 - _door_openness()
	_door_tween = create_tween()
	_door_tween.tween_property(inner_door, "position:y", _door_closed_y + door_slide,
			maxf(door_open_seconds * remaining, 0.01))
	_door_tween.tween_callback(func() -> void: inner_door.use_collision = false)


func _close_door() -> void:
	if _door_tween != null:
		_door_tween.kill()
	inner_door.use_collision = true  # solid again from the first moment of closing
	_door_tween = create_tween()
	_door_tween.tween_property(inner_door, "position:y", _door_closed_y,
			maxf(door_close_seconds * _door_openness(), 0.01))
	_door_tween.tween_callback(_finish_unload)


# ---- Passing out ---------------------------------------------------------------------

## Energy hit zero at work: the screen fades out, the player is carried outside and
## wakes up there, with a reduced payout, a little energy, and two hours lost.
func _on_passed_out() -> void:
	if _player == null:
		GameState.wake_up()
		return
	var player := _player
	player.frozen = true
	player.hud.phone.close()
	await player.hud.fade_to(1.0, 1.2)
	var pay := roundi(GameState.get_pending_payout() * GameState.PASSED_OUT_PAY_FACTOR)
	GameState.shift_pay_factor = GameState.PASSED_OUT_PAY_FACTOR
	# Moving out of the zones makes the warehouse clock the player out and pay the
	# reduced amount.
	player.teleport_to(wake_position, 0.0)
	GameState.wake_up()
	await get_tree().create_timer(0.6).timeout
	await player.hud.fade_to(0.0, 1.0)
	player.frozen = false
	player.hud.show_message("You passed out at work and woke up outside. Half pay: $%d" % pay, 6.0)


## Caught breaking the rules (the multiplier is already halved, see Career.catch). The
## scene: the camera turns to the supervisor who caught you, he says why you are being
## kicked out, the screen fades out, and you wake up outside the warehouse with a quest
## entry telling you how long you are banned for.
func _on_caught(reason: String, by: Node3D) -> void:
	if _player == null:
		return
	var player := _player
	player.frozen = true
	player.hud.phone.close()
	player.start_activity_cancel()
	var has_supervisor := by != null and is_instance_valid(by)
	if has_supervisor:
		by.set_process(false)  # he stands still, facing you
		var flat := player.global_position - by.global_position
		by.rotation.y = atan2(-flat.x, -flat.z)
		await player.look_at_point(by.global_position + Vector3(0.0, 1.5, 0.0), 0.9)
	player.frozen = true  # (the supervisors let go of you when you were caught: hold on again)
	player.hud.show_message('SUPERVISOR: "You are kicked out! You were %s."' % reason, 3.4)
	await get_tree().create_timer(3.0).timeout
	player.frozen = true
	await player.hud.fade_to(1.0, 0.8)
	if has_supervisor and is_instance_valid(by):
		by.set_process(true)
	player.teleport_to(wake_position, 0.0)
	await get_tree().create_timer(0.6).timeout
	await player.hud.fade_to(0.0, 0.8)
	player.frozen = false
	var until := Career.get_ban_end_text()
	Quests.add(&"ban", "Banned until %s" % until,
			"You were %s and thrown out. The warehouse refuses you until %s." % [reason, until])


var _knocked_out_busy: bool = false


## Something at work knocked the player out (wrecking ball, burning floor...): they
## wake up outside after an hour, with half pay.
func _on_knocked_out(reason: String) -> void:
	if _player == null or _knocked_out_busy or not GameState.on_shift:
		return
	_knocked_out_busy = true
	var player := _player
	player.frozen = true
	player.hud.phone.close()
	player.start_activity_cancel()
	await player.hud.fade_to(1.0, 0.8)
	var pay := roundi(GameState.get_pending_payout() * GameState.PASSED_OUT_PAY_FACTOR)
	GameState.shift_pay_factor = GameState.PASSED_OUT_PAY_FACTOR
	player.teleport_to(wake_position, 0.0)
	GameState.advance_hours(1.0)
	await get_tree().create_timer(0.6).timeout
	await player.hud.fade_to(0.0, 0.8)
	player.frozen = false
	_knocked_out_busy = false
	player.hud.show_message("You %s and woke up outside an hour later. Half pay: $%d" % [reason, pay], 6.0)
