class_name Player
extends CharacterBody3D
## First-person player: WASD movement, mouse look, interact key.
##
## Node layout (see scenes/player/player.tscn):
##   Player (CharacterBody3D)      <- moves in _physics_process (60 Hz)
##   ├─ CollisionShape3D
##   ├─ Head (Node3D)              <- top_level + interpolation OFF, see below
##   │  └─ Camera3D
##   │     └─ Interactor (RayCast3D)
##   └─ HUD (CanvasLayer)
##
## Smooth camera on any monitor: physics runs at a fixed 60 Hz but the screen
## may refresh at 144/200 Hz. Godot's physics interpolation smooths the BODY
## between physics ticks, but mouse look must not wait for a physics tick (that
## feels laggy). So Head is `top_level` (ignores the body's transform) with
## interpolation OFF, and every rendered frame `_process` places it at the
## body's interpolated position plus our own yaw/pitch from the mouse.
## Co-op note: nothing here is a singleton or reads a global "the player".
## `player_index` is reserved for choosing input devices/viewports later.

@export var player_index: int = 0

@export_group("Movement")
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 6.5
## How quickly velocity approaches the target speed while a key is held
## (metres/second per second; higher = snappier).
@export var acceleration: float = 45.0
## How quickly you stop when no key is held. Higher = less "walking on ice".
@export var deceleration: float = 70.0

@export_group("Look")
## Radians of rotation per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.0025
@export_range(0.0, 89.0) var max_pitch_degrees: float = 85.0
## Camera height above the player's feet, in metres.
@export var eye_height: float = 1.6

@export_group("Jump and crouch")
## How high a jump goes, in metres.
@export var jump_height: float = 0.9
## Body (capsule) height standing and crouching, in metres. The camera sits 0.2 m
## below the top of the body, so crouching lowers the eyes too.
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.0
## Walking speed while crouched, as a fraction of walk_speed.
@export var crouch_speed_factor: float = 0.5
## How fast the camera moves between standing and crouching height (higher = snappier).
@export var crouch_camera_speed: float = 12.0

# `@onready` runs when the node enters the scene tree (after children exist),
# the GDScript equivalent of grabbing child references in a C# constructor/Start().
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interactor: Interactor = $Head/Camera3D/Interactor
@onready var hud: PlayerHUD = $HUD
## Where a carried box is attached (in front of the camera, lower centre).
@onready var hold_point: Marker3D = $Head/Camera3D/HoldPoint

## How far in front of the player a dropped box is placed.
@export var drop_distance: float = 1.0

@export_group("Carry feel")
## Walking bob of the carried box: sideways/vertical travel in metres and roll in degrees.
@export var carry_bob_sideways: float = 0.03
@export var carry_bob_vertical: float = 0.025
@export var carry_bob_roll_degrees: float = 3.0
## Box slides backwards a little while you move forward (and sideways when strafing).
@export var carry_lag: float = 0.01
## Radians of bob cycle per metre walked.
@export var carry_bob_frequency: float = 3.0

## How many hotbar slots (small items and bills live there).
@export var hotbar_size: int = 5
## Where the selected hotbar item is shown in your hand: in front of the camera, low
## right (x right, y up, -z forward, in metres), and how big it appears (the longest side
## of the item is scaled to this many metres, so even a small bar is easy to see).
@export var hand_position: Vector3 = Vector3(0.3, -0.27, -0.66)
@export var hand_item_size: float = 0.22

const BILL_SCENE := preload("res://scenes/props/bill.tscn")
## Throwing (hold the right mouse button to charge): speed in m/s for a tap and for a
## fully charged throw, and the seconds a full charge takes.
const THROW_MIN_SPEED := 3.0
const THROW_MAX_SPEED := 15.0
const THROW_CHARGE_SECONDS := 1.2
## How far you can place something with a left click.
const PLACE_REACH := 2.5
## Eating takes this long (you stand still - and a supervisor can catch you at it).
const EAT_SECONDS := 3.0

## The BIG thing in the hands: a box (null = hands free). Stored on the PLAYER,
## not in a global. Small things go in the hotbar `inventory` instead.
var held: Carryable = null
## Convenience view of `held` (null when nothing is held).
var carried: Box:
	get:
		return held as Box
## The hotbar: small items and bills.
var inventory: Inventory

# What the selected-item model in the hand currently shows.
var _hand_entry: InventoryEntry = null
var _hand_visual: Node3D = null
var _last_use_prompt: String = ""
var _charging_throw: bool = false
var _throw_charge: float = 0.0

# Look angles in radians, updated straight from mouse events.
var _yaw: float = 0.0
var _pitch: float = 0.0

# Carry sway state. `_hold_rest` is HoldPoint's transform from the scene (the
# tilt toward the player is set there in the editor); the sway is added on top.
var _hold_rest: Transform3D
## The hand that shows the selected hotbar item (it sways like the box, and shakes while
## a throw is charged).
var _hand_anchor: Node3D = null
var _hand_rest: Transform3D
var _bob_phase: float = 0.0
var _bob_strength: float = 0.0
var _local_velocity: Vector3 = Vector3.ZERO

# Crouch state: `_crouching` follows the key (and headroom); `_eye` is the camera
# height, smoothed every rendered frame so crouching looks fluid.
var _crouching: bool = false

## True while the player is knocked out (passing out): no movement or actions.
var frozen: bool = false

## A timed action in progress ("smoking", "gambling"...): you cannot walk or use
## things, but you can look around. Empty when idle.
var activity: StringName = &""
var _activity_left: float = 0.0
var _activity_energy_rate: float = 0.0
var _activity_done: Callable = Callable()
## Seconds left in which the player counts as "eating" (for rules).
var _eating_left: float = 0.0
## How long the player has been standing still.
var _idle_time: float = 0.0

## How well feet grip (1.0 normal; the floor-waxing event makes it tiny) and how
## strongly gravity pulls the player (the low-gravity event lowers it).
var friction_factor: float = 1.0
var gravity_factor: float = 1.0
## Wind this frame (horizontal = extra walking speed, vertical = acceleration).
var _wind: Vector3 = Vector3.ZERO
var _wind_next: Vector3 = Vector3.ZERO
## Hot floor event: how long the feet have touched the burning floor in a row.
var hot_floor_active: bool = false
var hot_floor_time: float = 0.0
const HOT_FLOOR_LIMIT := 2.0
## Earthquake event: camera shake, fades out.
var shake: float = 0.0
var _flashlight: SpotLight3D = null

## Cycling: speed factor outside, and the bike prop that was picked up.
@export var bike_speed_factor: float = 3.0
var riding_bike: bool = false
var _bike: Node3D = null

var busy: bool:
	get:
		return activity != &""
var _eye: float = 1.6

## Lying in bed: 0 = the normal camera, 1 = the camera lies at `sleep_eye` (world position)
## looking `sleep_pitch` up. The bed (HomeBed) blends it in and out.
var sleep_blend: float = 0.0
var sleep_eye: Vector3 = Vector3.ZERO
var sleep_pitch: float = 1.1

# Pulled from Project Settings so it matches the physics engine's default gravity.
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("players")
	GameSettings.load_settings()
	mouse_sensitivity = GameSettings.mouse_sensitivity
	inventory = Inventory.new(hotbar_size)
	hud.bind_inventory(inventory)
	inventory.changed.connect(_refresh_carry_hud)
	interactor.user = self
	interactor.prompt_changed.connect(hud.set_prompt)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_yaw = global_rotation.y  # respect however the level placed/rotated us
	_hold_rest = hold_point.transform
	_hand_anchor = Node3D.new()
	camera.add_child(_hand_anchor)
	_hand_rest = Transform3D(Basis.from_euler(Vector3(deg_to_rad(8.0), deg_to_rad(-28.0), deg_to_rad(6.0))), hand_position)
	_hand_anchor.transform = _hand_rest
	# Our own copy of the capsule, so resizing it can't affect other players.
	var collision := $CollisionShape3D as CollisionShape3D
	collision.shape = (collision.shape as CapsuleShape3D).duplicate()
	_eye = eye_height
	# The flashlight for power outages (off until needed).
	_flashlight = SpotLight3D.new()
	_flashlight.spot_range = 18.0
	_flashlight.spot_angle = 30.0
	_flashlight.light_energy = 4.0
	_flashlight.visible = false
	camera.add_child(_flashlight)
	_update_camera()
	# "Continue": stand where the save says and hold what it says.
	var saved := SaveGame.take_pending_player()
	if not saved.is_empty():
		apply_save_data(saved)


# `_process` runs once per rendered frame (200 Hz on a 200 Hz monitor).
func _process(delta: float) -> void:
	_update_throw(delta)
	shake = maxf(0.0, shake - delta * 0.6)
	_flashlight.visible = GameState.blackout and GameState.on_shift
	var target_eye := (crouch_height - (stand_height - eye_height)) if _crouching else eye_height
	_eye = lerpf(_eye, target_eye, 1.0 - exp(-crouch_camera_speed * delta))
	_update_camera()
	_update_carry_sway(delta)
	# Nothing is held up in front of the face while lying down.
	_hand_anchor.visible = sleep_blend < 0.05
	hold_point.visible = sleep_blend < 0.05


## Makes the carried box bob and lag a little while the player moves, so it feels
## held rather than glued to the screen.
func _update_carry_sway(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var target_strength := clampf(speed / sprint_speed, 0.0, 1.0)
	_bob_strength = lerpf(_bob_strength, target_strength, 1.0 - exp(-8.0 * delta))
	_bob_phase += speed * carry_bob_frequency * delta
	# Velocity in the player's own frame (x = right, z = back), smoothed.
	var local_target := global_transform.basis.inverse() * velocity
	_local_velocity = _local_velocity.lerp(local_target, 1.0 - exp(-6.0 * delta))

	var offset := Vector3(
			sin(_bob_phase) * carry_bob_sideways * _bob_strength - _local_velocity.x * carry_lag,
			absf(sin(_bob_phase)) * carry_bob_vertical * _bob_strength,
			-_local_velocity.z * carry_lag)
	var roll := deg_to_rad(carry_bob_roll_degrees) * sin(_bob_phase) * _bob_strength
	var sway := Transform3D(Basis(Vector3.BACK, roll), offset)
	hold_point.transform = _hold_rest * sway
	# The hand item sways with the same walk bob; while a throw is charged it is drawn back
	# and SHAKES - the harder the charge, the harder the shake.
	var charge := _throw_charge / THROW_CHARGE_SECONDS if _charging_throw else 0.0
	var hand_offset := Vector3.ZERO
	var hand_roll := 0.0
	if charge > 0.0:
		var t := Time.get_ticks_msec() / 1000.0
		var amount := 0.004 + 0.03 * charge
		hand_offset = Vector3(sin(t * 53.0), sin(t * 61.0 + 1.3), sin(t * 47.0 + 2.1)) * amount \
				+ Vector3(0.0, 0.03, 0.1) * charge  # drawn back for the throw
		hand_roll = sin(t * 43.0 + 0.7) * deg_to_rad(10.0) * charge
	if activity == &"eating":
		# Bring it to the mouth, nibble at it, and it shrinks as it is eaten.
		var eaten := clampf(1.0 - _activity_left / EAT_SECONDS, 0.0, 1.0)
		var t_now := Time.get_ticks_msec() / 1000.0
		hand_offset = Vector3(-0.3, 0.08, 0.28) * smoothstep(0.0, 0.2, eaten) \
				+ Vector3(0.0, sin(t_now * 17.0) * 0.012, 0.0)
		if _hand_visual != null:
			_hand_visual.scale = Vector3.ONE * (1.0 - 0.7 * eaten)
	elif _hand_visual != null and _hand_visual.scale != Vector3.ONE:
		_hand_visual.scale = Vector3.ONE
	_hand_anchor.transform = _hand_rest * sway * Transform3D(Basis(Vector3.BACK, hand_roll), hand_offset)


func _update_camera() -> void:
	# The body's position smoothed between physics ticks, for this exact frame.
	var body_pos := get_global_transform_interpolated().origin
	# Basis.from_euler uses YXZ order: yaw first, then pitch - what an FPS needs.
	head.global_transform = Transform3D(
			Basis.from_euler(Vector3(_pitch, _yaw, 0.0)),
			body_pos + Vector3.UP * _eye)
	if sleep_blend > 0.0:
		var breath := sin(Time.get_ticks_msec() / 1000.0 * 1.3) * 0.012 * sleep_blend  # slow breathing
		var lying := Transform3D(Basis.from_euler(Vector3(sleep_pitch, _yaw, 0.0)), sleep_eye + Vector3.UP * breath)
		head.global_transform = head.global_transform.interpolate_with(lying, sleep_blend)
	if shake > 0.01:
		head.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.04


# `_unhandled_input` receives events that the UI didn't consume - the right
# place for gameplay input (as opposed to polling every frame).
func _unhandled_input(event: InputEvent) -> void:
	if frozen:
		return
	if busy and not event is InputEventMouseMotion:
		return  # smoking or gambling: only looking around is possible
	# While the phone is out the mouse belongs to its screen: clicks and the wheel
	# do nothing in the world (the apps handle their own clicks). Esc opens and puts
	# away the phone (Phone handles that key). The game keeps running and you can
	# still walk, unless you pressed the Pause app.
	if hud.phone.is_open and event is InputEventMouseButton:
		return
	# After the phone is put away the mouse may be free (e.g. after alt-tabbing): the
	# next click only recaptures it (it must not also count as an interaction).
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		var limit := deg_to_rad(max_pitch_degrees)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -limit, limit)
	elif event.is_action_pressed("interact"):  # left mouse button
		# With something selected in the hotbar a click puts it in a box or places it;
		# otherwise (or when you aim at something you can use) it is the normal "interact".
		if not _click_with_item():
			interactor.try_interact()
	elif event.is_action_pressed("attach_bill"):  # B
		attach_bill_to_box()
	elif event.is_action_pressed("use_item"):  # right mouse button: start charging a throw
		_begin_throw_charge()
	elif event.is_action_pressed("drop"):
		put_down()
	elif event.is_action_pressed("eat"):  # E
		if carried != null:
			_hotbar_locked_notice()
		else:
			eat_selected()
	elif event.is_action_pressed("box_take_item"):  # R
		take_item_from_box()
	elif event.is_action_pressed("box_detach_bill"):  # T
		detach_bill_from_box()
	elif event.is_action_pressed("box_close") and carried != null:
		carried.toggle_open()  # F: fold the carried box shut / open again
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if carried == null:
			inventory.cycle(-1)
		else:
			_hotbar_locked_notice()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if carried == null:
			inventory.cycle(1)
		else:
			_hotbar_locked_notice()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode >= KEY_1 and event.physical_keycode < KEY_1 + inventory.size():
		if carried == null:
			inventory.select(event.physical_keycode - KEY_1)  # number keys 1..n
		else:
			_hotbar_locked_notice()


## True when no box is in the hands.
func hands_empty() -> bool:
	return held == null


func pick_up(thing: Carryable) -> void:
	if not hands_empty():
		return
	held = thing
	thing.on_picked_up(hold_point)
	var box := thing as Box
	if box != null:
		# Keep the HUD readout in sync while this box is in our hands.
		box.contents_changed.connect(_refresh_carry_hud)
		box.open_changed.connect(_refresh_carry_hud)
		box.bill_changed.connect(_refresh_carry_hud)
	_refresh_carry_hud()


# The optional argument lets this one function serve every signal it is
# connected to (some pass a value, some pass nothing).
func _refresh_carry_hud(_unused: Variant = null) -> void:
	# A selected bill is read big in the middle of the screen.
	var entry := inventory.get_selected()
	if entry != null and entry.kind == InventoryEntry.Kind.BILL:
		hud.set_bill(entry.order)
	else:
		hud.set_bill(null)
	_refresh_hand_item()
	hud.set_hotbar_locked(carried != null)
	if carried != null:
		hud.set_carry_lines(carried.get_detail_lines())  # (the keys are listed in the hints on the left)
	else:
		hud.set_carry_lines(PackedStringArray())


## Shows the selected hotbar item in the hand (only while no box is carried -
## they would overlap).
func _refresh_hand_item() -> void:
	var entry := inventory.get_selected()
	var wanted: InventoryEntry = null
	if entry != null and entry.kind == InventoryEntry.Kind.ITEM and carried == null:
		wanted = entry
	if wanted == _hand_entry:
		return
	_hand_entry = wanted
	if _hand_visual != null:
		_hand_visual.queue_free()
		_hand_visual = null
	if wanted != null:
		# Scaled so its longest side is `hand_item_size`, and centred on the hand.
		var visual := wanted.item.create_visual()
		var bounds := wanted.item.measure_visual(visual)
		var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		var hand_scale := clampf(hand_item_size / maxf(longest, 0.01), 0.6, 2.5)
		visual.scale = Vector3.ONE * hand_scale
		visual.position = -bounds.get_center() * hand_scale
		_hand_visual = Node3D.new()
		_hand_visual.add_child(visual)
		_hand_anchor.add_child(_hand_visual)


## Gives up everything carried (the box in the hands and the whole hotbar). Used
## when clocking out: what you carry belongs to the job and stays behind.
func drop_everything() -> void:
	if held != null:
		var thing := release_held()
		thing.queue_free()
	inventory.clear()
	_refresh_carry_hud()


## Where dropped things go: the warehouse interior while you work (so they vanish
## when it is deleted), otherwise the world.
func _drop_parent() -> Node:
	var interior := get_tree().get_first_node_in_group("interior_root")
	if interior != null and GameState.on_shift:
		return interior
	return get_parent()


## Redraws what the HUD shows about the carried thing (after it changed).
func refresh_hud() -> void:
	_refresh_carry_hud()


## Lets go of the held box WITHOUT moving it (the caller - the floor drop or
## a pallet - decides where it goes) and returns it.
func release_held() -> Carryable:
	var thing := held
	held = null
	var box := thing as Box
	if box != null:
		box.contents_changed.disconnect(_refresh_carry_hud)
		box.open_changed.disconnect(_refresh_carry_hud)
		box.bill_changed.disconnect(_refresh_carry_hud)
	_refresh_carry_hud()
	return thing


## Left click with something selected in the hotbar. Returns true if the click was used up:
##   - aiming at a box: the item goes into it / the bill is attached to it,
##   - aiming at something else you can use (a shelf item, the order desk...): not used
##     here, that is the normal interact,
##   - carrying an open box and aiming at nothing usable: the item goes into your box,
##   - otherwise: the item is placed where you aim.
func _click_with_item() -> bool:
	var focus := interactor.focused
	# A box in the hands: the hotbar is locked. A click on something usable (the conveyor belt,
	# the order desk...) is the normal interact, anywhere else it puts the box down.
	if carried != null:
		if is_instance_valid(focus) and focus.can_interact(self):
			return false
		put_down()
		return true
	var entry := inventory.get_selected()
	if entry == null:
		return false
	if is_instance_valid(focus) and focus is Box:
		use_selected_item()
		return true
	if is_instance_valid(focus) and focus.can_interact(self):
		return false
	_place_selected()
	return true


## Puts the selected hotbar entry down gently where you aim (on the floor, a shelf, a
## crate...), or in front of you if you aim at nothing.
func _place_selected() -> void:
	var entry := inventory.get_selected()
	if entry == null:
		return
	var from := camera.global_position
	var direction := -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * PLACE_REACH)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var spot := from + direction * 1.2
	var on_floor := false
	if not hit.is_empty():
		spot = hit.position + hit.normal * 0.03
		on_floor = hit.normal.y > 0.7
	if entry.kind == InventoryEntry.Kind.BILL:
		# A bill is paper on a flat surface: where you aim if that is a floor, else at your feet.
		var bill := BILL_SCENE.instantiate() as Bill
		bill.order = entry.order
		bill.position = spot + Vector3.UP * 0.02 if on_floor else global_position - Basis(Vector3.UP, _yaw).z * drop_distance
		_drop_parent().add_child(bill)
		inventory.remove_selected()
	else:
		# An item is a real physics object: it settles where it is put.
		WorldItem.spawn_loose(entry.item, _drop_parent(), spot + Vector3.UP * 0.03)
		inventory.remove_selected()


## Right mouse button pressed: start charging a throw of the selected item.
func _begin_throw_charge() -> void:
	var entry := inventory.get_selected()
	if entry != null and entry.kind == InventoryEntry.Kind.ITEM and carried == null:
		_charging_throw = true
		_throw_charge = 0.0


## While the right mouse button is held the throw charges (the bar under the crosshair
## fills and the item in your hand shakes); let go to throw the selected item along where
## you look. A quick tap is a soft toss.
func _update_throw(delta: float) -> void:
	if not _charging_throw:
		return
	var entry := inventory.get_selected()
	var can_throw := not frozen and not busy and not hud.phone.is_open and carried == null and entry != null and entry.kind == InventoryEntry.Kind.ITEM
	if not can_throw:  # the selection changed, or something froze us: cancel
		_charging_throw = false
		hud.set_throw_power(-1.0)
		return
	if Input.is_action_pressed("use_item"):
		_throw_charge = minf(_throw_charge + delta, THROW_CHARGE_SECONDS)
		hud.set_throw_power(_throw_charge / THROW_CHARGE_SECONDS)
	else:
		_throw_selected(_throw_charge / THROW_CHARGE_SECONDS)
		_charging_throw = false
		hud.set_throw_power(-1.0)


## Throws the selected item; `power` is 0 (a toss) to 1 (full charge).
func _throw_selected(power: float) -> void:
	var entry := inventory.remove_selected()
	if entry == null or entry.kind != InventoryEntry.Kind.ITEM:
		return
	var forward := -camera.global_transform.basis.z
	var from := camera.global_position
	var origin := from + forward * 0.5
	# Not through a wall right in front of us.
	var query := PhysicsRayQueryParameters3D.create(from, origin)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		origin = hit.position - forward * 0.1
	var speed := lerpf(THROW_MIN_SPEED, THROW_MAX_SPEED, clampf(power, 0.0, 1.0))
	var thrown := WorldItem.spawn_loose(entry.item, _drop_parent(), origin,
			forward * speed + Vector3.UP * speed * 0.12 + Vector3(velocity.x, 0.0, velocity.z) * 0.5)
	thrown.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))


## Use the selected hotbar entry on the box you are aiming at - or,
## if you aim at none, on the box in your hands. Items go into an open box; a
## bill gets attached to it (that box is then checked against the bill).
func use_selected_item() -> void:
	var entry := inventory.get_selected()
	var box := _use_target_box()
	if entry == null or box == null:
		return
	if box.use_entry(entry):
		inventory.remove_selected()


## Turns the camera towards `point` over `seconds` (the caught scene). `await` it.
func look_at_point(point: Vector3, seconds: float = 0.9) -> void:
	var offset := point - head.global_position
	var target_yaw := atan2(-offset.x, -offset.z)
	var limit := deg_to_rad(max_pitch_degrees)
	var target_pitch := clampf(atan2(offset.y, Vector2(offset.x, offset.z).length()), -limit, limit)
	var start_yaw := _yaw
	var start_pitch := _pitch
	var turn := angle_difference(start_yaw, target_yaw)  # the short way round
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(t: float) -> void:
		_yaw = start_yaw + turn * t
		_pitch = lerpf(start_pitch, target_pitch, t), 0.0, 1.0, seconds)
	await tween.finished


## Puts the player where the save says (position, look direction, hotbar). Called once
## when the world starts after "Continue".
func apply_save_data(data: Dictionary) -> void:
	var p: Array = data.get("position", [])
	if p.size() == 3:
		teleport_to(Vector3(float(p[0]), float(p[1]), float(p[2])), float(data.get("yaw", 0.0)))
	var limit := deg_to_rad(max_pitch_degrees)
	_pitch = clampf(float(data.get("pitch", 0.0)), -limit, limit)
	var ids: Array = data.get("inventory", [])
	for i in mini(ids.size(), inventory.size()):
		var item := SaveGame.find_item(str(ids[i]))
		if item != null:
			inventory.slots[i] = InventoryEntry.make_item(item, null)
	inventory.select(clampi(int(data.get("selected", 0)), 0, inventory.size() - 1))
	inventory.changed.emit()
	_update_camera()


## B: stick a bill from the hotbar on the box you aim at, or on the box in your hands
## (the selected entry if it is a bill, otherwise the first bill in the hotbar - the hotbar
## itself is locked while you carry a box).
func attach_bill_to_box() -> void:
	var box := _use_target_box()
	if box == null:
		return
	if box.attached_order != null:
		GameState.notice.emit("This box already has a bill (T takes it off).")
		return
	var index := _bill_slot()
	if index == -1:
		GameState.notice.emit("You have no bill in your hotbar.")
		return
	box.attach_order(inventory.slots[index].order)
	inventory.slots[index] = null
	inventory.changed.emit()


## The hotbar slot of the bill to attach: the selected one if it is a bill, else the first
## bill (-1 = none).
func _bill_slot() -> int:
	var selected := inventory.get_selected()
	if selected != null and selected.kind == InventoryEntry.Kind.BILL:
		return inventory.selected
	for i in inventory.size():
		var entry := inventory.slots[i]
		if entry != null and entry.kind == InventoryEntry.Kind.BILL:
			return i
	return -1


func _hotbar_locked_notice() -> void:
	GameState.notice.emit("Put the box down to use your hotbar.")


## R: take the last packed item out of the box you aim at (or carry) into your hotbar.
func take_item_from_box() -> void:
	var box := _use_target_box()
	if box == null:
		return
	if box.contents.is_empty():
		return
	if not box.is_open:
		GameState.notice.emit("The box is closed. Open it first (F while carrying it).")
		return
	if not inventory.has_room():
		GameState.notice.emit("Your hotbar is full.")
		return
	var item := box.take_last_item()
	if item != null:
		inventory.add(InventoryEntry.make_item(item, null))


## T: peel the bill off the box you aim at (or carry) - it goes to your hotbar, so you can
## stick it on another box.
func detach_bill_from_box() -> void:
	var box := _use_target_box()
	if box == null or box.attached_order == null:
		return
	if not inventory.has_room():
		GameState.notice.emit("Your hotbar is full.")
		return
	var order := box.detach_order()
	if order != null:
		inventory.add(InventoryEntry.make_bill(order))


## The player is much heavier than any item: walking into a loose item from the side
## pushes it along at our speed, in the direction we move - but never up or down, so
## you can still jump onto items and stand on them. (Items still on a shelf are fixed
## in place, so shelves can be climbed without knocking the stock off.)
##
## Instead of waiting for the capsule to bump into the item (which would lift us over
## low items), we look for loose items just in front of our feet every physics frame.
## Returns true if something was pushed.
func _push_items(move_velocity: Vector3) -> bool:
	var pushing := Vector3(move_velocity.x, 0.0, move_velocity.z)
	if pushing.length() < 0.1:
		return false
	var direction := pushing.normalized()
	var query := PhysicsShapeQueryParameters3D.new()
	var reach := SphereShape3D.new()
	reach.radius = 0.8
	query.shape = reach
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.3)
	query.exclude = [get_rid()]
	var pushed := false
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var item := hit.collider as WorldItem
		if item == null or item.freeze:
			continue
		var offset := item.global_position - global_position
		offset.y = 0.0
		if offset.length() < 0.01 or direction.dot(offset.normalized()) < 0.3:
			continue  # not in front of us
		var top := item.global_position.y + WorldItem._collision_size(item.item).y
		if global_position.y >= top - 0.02:
			continue  # we are standing on it
		var current := Vector3(item.linear_velocity.x, 0.0, item.linear_velocity.z)
		item.apply_central_impulse((pushing - current) * item.mass)  # it takes our speed
		item.sleeping = false
		pushed = true
	return pushed


func _use_target_box() -> Box:
	if is_instance_valid(interactor.focused) and interactor.focused is Box:
		return interactor.focused as Box
	return carried


## The hints on the left side of the screen: every action that is possible right now,
## EXCEPT the one you are aiming at (that one is shown under the crosshair).
func _update_use_prompt() -> void:
	var entry := inventory.get_selected()
	var box := _use_target_box()
	var focus := interactor.focused
	var focus_usable: bool = is_instance_valid(focus) and focus.can_interact(self)
	var lines: PackedStringArray = []
	if riding_bike:
		lines.append("[Q] Get off the bike")
	if carried != null:
		# Boxes: the hotbar is locked. Left click puts the box down (unless you aim at
		# something you can use); B sticks a bill from the hotbar on it.
		if not focus_usable:
			lines.append("[Left click] Put the box down")
		if carried.attached_order == null and _bill_slot() != -1:
			lines.append("[B] Attach the bill")
	elif entry != null:
		# Left click: into a box, or placed (unless you aim at something else to use).
		if is_instance_valid(focus) and focus is Box:
			lines.append("[Left click] " + (focus as Box).get_use_hint(entry))
		elif not focus_usable:
			lines.append("[Left click] Place")
		if entry.kind == InventoryEntry.Kind.ITEM:
			lines.append("[Hold right click] Throw (longer = harder)")
			if entry.item.edible:
				lines.append("[E] Eat (+%d energy)" % roundi(entry.item.energy_restore))
		if carried == null and not riding_bike:
			lines.append("[Q] Drop")
	if box != null:
		if carried == null and is_instance_valid(focus) and focus is Box and box.attached_order == null and _bill_slot() != -1:
			lines.append("[B] Attach the bill")
		for part in box.get_take_hint().split("   ", false):
			lines.append(part)
	if carried != null:
		lines.append("[F] " + ("Close the box" if carried.is_open else "Open the box"))
		if focus_usable:
			lines.append("[Q] Put the box down")
	var signature := "|".join(lines)
	if signature != _last_use_prompt:
		_last_use_prompt = signature
		hud.set_hints(lines)


## Q: a carried box goes on the floor in front of you. With free hands, the
## selected hotbar entry is put down instead: a bill lands on the floor, an item
## goes back on the shelf it came from. (Flat floor assumed for now.)
func put_down() -> void:
	var facing := Basis(Vector3.UP, _yaw)
	var spot := global_position - facing.z * drop_distance
	if riding_bike:
		dismount_bike()
		return
	if held != null:
		release_held().on_dropped(Transform3D(facing, spot))
		return
	var entry := inventory.get_selected()
	if entry == null:
		return
	if entry.kind == InventoryEntry.Kind.BILL:
		var bill := BILL_SCENE.instantiate() as Bill
		bill.order = entry.order
		bill.position = spot
		_drop_parent().add_child(bill)
		inventory.remove_selected()
	else:
		# An item is dropped as a real physics object: it falls, bounces and stays
		# where it lands (you can pick it up again, or use it as a stepping stone).
		var ahead := -facing.z
		WorldItem.spawn_loose(entry.item, _drop_parent(), global_position + ahead * 0.8 + Vector3.UP * 1.3, ahead * 1.5)
		inventory.remove_selected()


## Starts a timed action. For `seconds` you cannot walk; energy changes by
## `energy_rate` per second; `on_done` is called when it ends.
func start_activity(activity_name: StringName, seconds: float, energy_rate: float = 0.0,
		on_done: Callable = Callable()) -> void:
	if busy:
		return
	activity = activity_name
	_activity_left = seconds
	_activity_energy_rate = energy_rate
	_activity_done = on_done
	hud.phone.close()


## Stops an activity without finishing it (being carried out of the building).
func start_activity_cancel() -> void:
	if activity == &"eating":
		hud.set_throw_power(-1.0)  # (the progress bar)
	activity = &""
	_activity_done = Callable()


func _update_timers(delta: float) -> void:
	_eating_left = maxf(0.0, _eating_left - delta)
	if Vector2(velocity.x, velocity.z).length() < 0.2 and is_on_floor() and not busy:
		_idle_time += delta
	else:
		_idle_time = 0.0
	if busy:
		_activity_left -= delta
		if activity == &"eating":
			hud.set_throw_power(clampf(1.0 - _activity_left / EAT_SECONDS, 0.0, 1.0))  # the progress bar
		if _activity_energy_rate != 0.0:
			GameState.restore_energy(_activity_energy_rate * delta)
		if _activity_left <= 0.0:
			var done := _activity_done
			activity = &""
			_activity_done = Callable()
			if done.is_valid():
				done.call()


## E: eat the selected edible item from the hotbar.
func eat_selected() -> void:
	var entry := inventory.get_selected()
	if entry == null or entry.kind != InventoryEntry.Kind.ITEM or not entry.item.edible:
		return
	if busy or frozen or riding_bike:
		return
	# You eat for EAT_SECONDS: no walking, the item is brought to your mouth and gets smaller,
	# and anyone watching can see it (the "no snacking" rule). The energy comes at the end.
	start_activity(&"eating", EAT_SECONDS, 0.0, _finish_eating)


func _finish_eating() -> void:
	hud.set_throw_power(-1.0)
	var entry := inventory.get_selected()
	if entry == null or entry.kind != InventoryEntry.Kind.ITEM or not entry.item.edible:
		return
	inventory.remove_selected()
	GameState.restore_energy(entry.item.energy_restore)
	GameState.notice.emit("Ate %s: +%d energy" % [entry.item.display_name, roundi(entry.item.energy_restore)])


## Is the player doing this right now? (Used to check the boss' rules - see RuleData.)
func has_condition(condition: StringName) -> bool:
	match condition:
		&"sprinting":
			return is_on_floor() and Input.is_action_pressed("sprint") \
					and Vector2(velocity.x, velocity.z).length() > walk_speed + 0.5 and not riding_bike
		&"jumping":
			return not is_on_floor()
		&"crouching":
			return _crouching
		&"eating":
			return activity == &"eating" or _eating_left > 0.0
		&"idle":
			return _idle_time > 6.0
		&"phone":
			return hud.phone.counts_as_phone_use()
		&"smoking":
			return activity == &"smoking"
		&"gambling":
			return activity == &"gambling"
	return false


## Things that are ALWAYS forbidden at work (a supervisor who sees one throws you out):
## the phone, smoking, gambling and snacking.
func get_core_violations() -> Array[StringName]:
	var found: Array[StringName] = []
	for kind: StringName in [&"phone", &"smoking", &"gambling", &"eating"]:
		if has_condition(kind):
			found.append(kind)
	return found


## The heavier the box in your hands, the slower you walk (also less sprint).
func get_carry_speed_factor() -> float:
	if carried == null:
		return 1.0
	return 1.0 / (1.0 + 0.04 * carried.get_weight())


## Gets on a bike prop (it disappears while you ride).
func mount_bike(bike: Node3D) -> void:
	if riding_bike or GameState.on_shift:
		return
	riding_bike = true
	_bike = bike
	collision_mask = 1 | 8  # layer 8 = the "no bikes" barrier in front of the warehouse door
	bike.visible = false
	if bike is CollisionObject3D:
		(bike as CollisionObject3D).collision_layer = 0


func dismount_bike() -> void:
	if not riding_bike:
		return
	riding_bike = false
	collision_mask = 1
	if is_instance_valid(_bike):
		var facing := Basis(Vector3.UP, _yaw)
		_bike.global_position = global_position - facing.z * 1.0
		_bike.visible = true
		if _bike is CollisionObject3D:
			(_bike as CollisionObject3D).collision_layer = 1
	_bike = null


## Fans and conveyors call this every physics frame while the player is in them.
func add_wind(wind: Vector3) -> void:
	_wind_next += wind


## Pushes the player (a rotating barrier, a pendulum).
func knockback(impulse: Vector3) -> void:
	velocity += impulse


func add_shake(amount: float) -> void:
	shake = minf(3.0, shake + amount)


## Hot floor event: you may touch the burning floor for only 2 seconds in a row;
## standing on anything else (a shelf, a box, an item, a platform) resets the timer.
func _check_hot_floor(delta: float) -> void:
	if not hot_floor_active:
		return
	var on_hot_ground := false
	if is_on_floor():
		for i in get_slide_collision_count():
			var collision := get_slide_collision(i)
			if collision.get_normal().y > 0.7 and (collision.get_collider() as Node).is_in_group("hot_floor"):
				on_hot_ground = true
		if on_hot_ground:
			hot_floor_time += delta
		else:
			hot_floor_time = 0.0
	hud.set_heat(hot_floor_time / HOT_FLOOR_LIMIT)
	if hot_floor_time >= HOT_FLOOR_LIMIT:
		hot_floor_time = 0.0
		GameState.knocked_out.emit("burned your feet on the hot floor")


## Switches the hot-floor mechanic on or off (the event calls this).
func set_hot_floor(active: bool) -> void:
	hot_floor_active = active
	hot_floor_time = 0.0
	if not active:
		hud.set_heat(-1.0)


## Working costs energy (see GameState.tick_energy): standing still costs almost nothing,
## walking costs 1.0 and sprinting 2.6 - sprinting is 1.6 times faster, so a metre run costs
## about 1.6 times a metre walked. Carrying a box adds a little. Off shift energy slowly returns.
const IDLE_ACTIVITY := 0.05
const WALK_ACTIVITY := 1.0
const SPRINT_ACTIVITY := 2.6
func _use_energy(delta: float, moving: bool, sprinting: bool) -> void:
	var activity := IDLE_ACTIVITY
	if moving:
		activity = SPRINT_ACTIVITY if sprinting and not _crouching else WALK_ACTIVITY
	if carried != null:
		activity += 0.3 if moving else 0.05
	GameState.tick_energy(delta, activity)


## Puts the player somewhere else instantly (waking up outside after passing out).
func teleport_to(position: Vector3, yaw: float) -> void:
	global_position = position
	velocity = Vector3.ZERO
	_yaw = yaw
	reset_physics_interpolation()
	_update_camera()


## Crouch while the key is held; stand back up only when there is room above.
func _update_crouch() -> void:
	var wants := Input.is_action_pressed("crouch") and not riding_bike  # no crouching on a bike
	if wants and not _crouching:
		_crouching = true
		_set_body_height(crouch_height)
	elif not wants and _crouching:
		# Is there a ceiling in the way of growing back to full height?
		var growth := stand_height - crouch_height
		if not test_move(global_transform, Vector3.UP * growth):
			_crouching = false
			_set_body_height(stand_height)


## Resizes the collision capsule, keeping the feet where they are.
func _set_body_height(height: float) -> void:
	var collision := $CollisionShape3D as CollisionShape3D
	(collision.shape as CapsuleShape3D).height = height
	collision.position.y = height / 2.0


# `_physics_process` runs at a fixed rate (60 Hz default) - use it for anything
# involving physics bodies. `delta` is the time step in seconds.
func _physics_process(delta: float) -> void:
	# Turn the body to match where we look, so "forward" below follows the camera.
	rotation.y = _yaw
	_update_use_prompt()
	_update_crouch()

	# Gravity
	if not is_on_floor():
		velocity.y -= _gravity * gravity_factor * delta
	elif Input.is_action_just_pressed("jump") and not _crouching and not frozen and not riding_bike:
		# v = sqrt(2 * g * h) launches us exactly `jump_height` metres up.
		velocity.y = sqrt(2.0 * _gravity * jump_height)

	# Input.get_vector turns four actions into a normalised 2D direction.
	# "move_forward" is the negative-Y end, matching Godot's -Z = forward.
	_update_timers(delta)
	var input_dir := Vector2.ZERO
	if not frozen and not busy:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# `transform.basis` rotates the local direction into world space, so
	# "forward" follows where the body is facing.
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var sprinting := Input.is_action_pressed("sprint") and not frozen
	var speed := sprint_speed if sprinting else walk_speed
	if _crouching:
		speed = walk_speed * crouch_speed_factor
	if riding_bike:
		speed = walk_speed * bike_speed_factor
	speed *= get_carry_speed_factor()
	_use_energy(delta, input_dir != Vector2.ZERO, sprinting)
	var target := direction * speed
	# Stop faster than we start, so letting go of the keys halts you almost at once.
	var rate := acceleration if input_dir != Vector2.ZERO else deceleration
	if friction_factor < 1.0:
		# A waxed floor: little grip, and a heavy box makes it even worse.
		rate *= friction_factor / (1.0 + 0.08 * (carried.get_weight() if carried != null else 0.0))
	# Wind (fans) and conveyors add to where we want to go; updrafts push upwards.
	_wind = _wind_next
	_wind_next = Vector3.ZERO
	target += Vector3(_wind.x, 0.0, _wind.z)
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(
			Vector2(target.x, target.z), rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	velocity.y += _wind.y * delta

	var move_velocity := velocity  # (move_and_slide changes it when we bump into things)
	var height_before := global_position.y
	var was_on_floor := is_on_floor()
	move_and_slide()
	if _push_items(move_velocity) and was_on_floor and global_position.y > height_before:
		# Walking into a low item must push it, not lift us over it: undo the climb.
		global_position.y = height_before
		velocity.y = minf(velocity.y, 0.0)
	_check_hot_floor(delta)
