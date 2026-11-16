class_name Box
extends Carryable
## A cardboard box: can be picked up, carried, dropped, and its flaps can be
## folded shut / opened with an animation.
##
## There is ONE model (cardboardbox_open.glb, flaps pointing up). The closed look
## is made at runtime by rotating the four flap bones of its Skeleton3D, so no
## second "closed" model is needed.
##
## GDScript concept: a Skeleton3D lets you set each bone's local transform from
## code (`set_bone_pose_rotation`). The skinned mesh follows automatically.

signal open_changed(is_open: bool)
## Emitted whenever an item is added to (or later removed from) the box.
signal contents_changed
## Emitted when a bill gets attached to the box.
signal bill_changed

@export_group("Size and capacity")
## Name shown on the HUD ("box", "small box", "big box").
@export var box_name: String = "box"
## Resizes the whole box (model, collision and packing area). The standard box is
## (1, 1, 1); the small/big variants in scenes/props/ just change these numbers.
@export var box_scale: Vector3 = Vector3.ONE
## The packing grid inside the box: columns (left-right) x rows (front-back) x
## layers (stacked). Capacity = columns * rows * layers. The slot markers are
## generated from these numbers when the box is created.
@export var slot_columns: int = 4
@export var slot_rows: int = 2
@export var slot_layers: int = 1
## Footprint (width, depth in metres) each packed item is fitted into. Items are
## shrunk/turned to fit, so any item or model works in any slot.
@export var slot_cell_size: Vector2 = Vector2(0.1, 0.19)
## Height between packing layers, in metres (before `box_scale`).
@export var slot_layer_height: float = 0.3
@export_group("")

## Spawn with the flaps closed (no animation at startup).
@export var start_open: bool = true
## Spawn flat-packed and wait for `play_form()` (only if the model has a `form`
## animation, otherwise this is ignored).
@export var start_flat: bool = false
## Blender animation that turns the flat blank box into the open box.
@export var form_animation: StringName = &"form"
## If the model has an AnimationPlayer containing animations with these names
## (made in Blender, exported in the .glb), they are played. Otherwise the flaps
## are folded from code (see FLAPS below).
@export var open_animation: StringName = &"open"
@export var close_animation: StringName = &"close"
## Seconds for a full open <-> close animation.
@export var fold_duration: float = 0.7
## Tiny extra height (in model units, before scaling) for the long flaps so they
## sit ON TOP of the short ones instead of intersecting them.
@export var top_flap_lift: float = 0.03

# One entry per flap bone. Bone rest rotations in the .glb are identity, so the
# hinge axes below are plain model-space axes:
#   left/right hinge along Z, front/back hinge along X.
# `stage` 0 = short flaps fold first, stage 1 = long flaps fold on top.
const FLAPS: Array[Dictionary] = [
	{"bone": "left", "axis": Vector3(0, 0, 1), "angle": -90.0, "stage": 0},
	{"bone": "right", "axis": Vector3(0, 0, 1), "angle": 90.0, "stage": 0},
	{"bone": "back", "axis": Vector3(1, 0, 0), "angle": 90.0, "stage": 1},
	{"bone": "front", "axis": Vector3(1, 0, 0), "angle": -90.0, "stage": 1},
]

var is_open: bool = true
## What is packed inside (data). `_slot_visuals[i]` is the model shown for item i
## and `_spans[i]` the slot numbers it occupies.
var contents: Array[ItemData] = []

## How many PACKING SPACES the box has = how many slots the grid has. An item takes
## `item.size` spaces (a toothbrush 1, toilet paper 4), so a medium box (8 spaces)
## holds 8 toothbrushes or 2 rolls of toilet paper.
var capacity: int:
	get:
		return _slots.size()

## Empty weight of the cardboard itself, in kg (scaled with the box size).
const EMPTY_WEIGHT := 0.6

## Height of the box in metres - the pallet uses it to stack boxes on top.
var stack_height: float = 0.425

var _slots: Array[Marker3D] = []
var _slot_visuals: Array[Node3D] = []
var _slot_used: Array[bool] = []
var _spans: Array[PackedInt32Array] = []

var _fold: float = 0.0  # 0 = fully open, 1 = fully closed
var _tween: Tween = null
var _bone_ids: Array[int] = []
var _anim_player: AnimationPlayer = null  # only set if the .glb ships open/close animations
var _form_player: AnimationPlayer = null  # only set if the .glb ships a form animation

## True while the box is flat or still forming: it can't be filled or closed yet.
var forming: bool = false
## The order printed on the bill attached to this box (null = no bill). At
## shipping, the box contents are compared to this order.
var attached_order: Order = null

# `find_child` searches the imported .glb's node tree for the Skeleton3D.
@onready var _skeleton: Skeleton3D = $Model.find_child("Skeleton3D", true, false)


func _ready() -> void:
	add_to_group("boxes")  # rats and other events look for boxes through this group
	_apply_size()
	_build_slots()
	for flap in FLAPS:
		_bone_ids.append(_skeleton.find_bone(flap["bone"]))
	var player := $Model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and player.has_animation(open_animation) and player.has_animation(close_animation):
		_anim_player = player
	if player != null and player.has_animation(form_animation):
		_form_player = player
		if start_flat:
			forming = true  # stays flat (the model's rest pose) until play_form()
		else:
			# The rest pose is flat: jump to the end of the form animation = the open box.
			player.play(form_animation)
			player.seek(player.get_animation(form_animation).length, true)
	if not start_open and not forming:
		set_open(false, false)


## Resizes the model and the collision shape by `box_scale`.
func _apply_size() -> void:
	$Model.scale *= box_scale
	var collision := $CollisionShape3D as CollisionShape3D
	var shape := (collision.shape as BoxShape3D).duplicate() as BoxShape3D  # don't resize other boxes
	shape.size *= box_scale
	collision.shape = shape
	collision.position.y *= box_scale.y
	stack_height = 0.425 * box_scale.y


## Creates the packing slots (Marker3D nodes) from the grid settings.
func _build_slots() -> void:
	for child in $Slots.get_children():
		$Slots.remove_child(child)
		child.free()
	for layer in slot_layers:
		for row in slot_rows:
			for column in slot_columns:
				var marker := Marker3D.new()
				marker.position = Vector3(
						(column - (slot_columns - 1) * 0.5) * slot_cell_size.x,
						0.02 * box_scale.y + layer * slot_layer_height * box_scale.y,
						(row - (slot_rows - 1) * 0.5) * slot_cell_size.y)
				$Slots.add_child(marker)
				_slots.append(marker)
				_slot_used.append(false)


## Plays the flat -> open box animation (if the model has one).
func play_form() -> void:
	if _form_player == null or not forming:
		return
	_form_player.play(form_animation)
	while true:
		var finished: StringName = await _form_player.animation_finished
		if finished == form_animation:
			break
	forming = false
	contents_changed.emit()


# ---- Open / close -----------------------------------------------------------

func set_open(open: bool, animate: bool = true) -> void:
	if forming:
		return
	if open == is_open and (animate or is_equal_approx(_fold, 0.0 if open else 1.0)):
		return
	is_open = open
	var target := 0.0 if open else 1.0
	if _anim_player != null:
		# Blender-authored animation path.
		var anim := open_animation if open else close_animation
		_anim_player.play(anim)
		if not animate:
			_anim_player.seek(_anim_player.current_animation_length, true)  # jump to last frame
		_fold = target
		open_changed.emit(is_open)
		return
	if _tween != null:
		_tween.kill()
	if animate:
		# tween_method calls _apply_fold(value) every frame while interpolating.
		_tween = create_tween()
		_tween.tween_method(_apply_fold, _fold, target, fold_duration * absf(target - _fold))
	else:
		_apply_fold(target)
	open_changed.emit(is_open)


func toggle_open() -> void:
	set_open(not is_open)


## Poses the flap bones for fold amount `t` (0 open .. 1 closed).
func _apply_fold(t: float) -> void:
	_fold = t
	for i in FLAPS.size():
		var flap := FLAPS[i]
		var stage: int = flap["stage"]
		# Stage 0 flaps use the first half of the animation, stage 1 the second.
		var local_t := smoothstep(0.0, 1.0, clampf(t * 2.0 - float(stage), 0.0, 1.0))
		var rest := _skeleton.get_bone_rest(_bone_ids[i])
		var fold_rot := Quaternion(flap["axis"], deg_to_rad(flap["angle"]) * local_t)
		_skeleton.set_bone_pose_rotation(_bone_ids[i], fold_rot * rest.basis.get_rotation_quaternion())
		var lift := top_flap_lift * local_t if stage == 1 else 0.0
		_skeleton.set_bone_pose_position(_bone_ids[i], rest.origin + Vector3(0.0, lift, 0.0))


# ---- Contents ---------------------------------------------------------------

## Packing spaces taken so far.
func used_space() -> int:
	var total := 0
	for item in contents:
		total += item.size
	return total


## Total weight in kg: the cardboard plus everything inside.
func get_weight() -> float:
	var total := EMPTY_WEIGHT * box_scale.x * box_scale.y * box_scale.z
	for item in contents:
		total += item.weight
	return total


## Is there a free run of `size` spaces?
func has_room(size: int = 1) -> bool:
	return _find_run(size) != -1


## First slot number of a free run of `size` slots in the same layer (-1 = none).
func _find_run(size: int) -> int:
	var per_layer := slot_columns * slot_rows
	for start in range(0, _slots.size() - size + 1):
		if start / per_layer != (start + size - 1) / per_layer:
			continue  # would cross from one layer into the next
		var free := true
		for k in size:
			if _slot_used[start + k]:
				free = false
				break
		if free:
			return start
	return -1


## Packs one item into a free run of slots. Fails (returns false) if the box is
## closed or has no room for that item's size.
func add_item(item: ItemData) -> bool:
	if forming or not is_open:
		return false
	var start := _find_run(item.size)
	if start == -1:
		return false
	# The item is shown over the middle of the slots it takes (no physics: it just
	# appears there).
	var span := PackedInt32Array()
	var centre := Vector3.ZERO
	for k in item.size:
		_slot_used[start + k] = true
		span.append(start + k)
		centre += _slots[start + k].position
	centre /= item.size
	var cell := Vector2(slot_cell_size.x * mini(item.size, slot_columns),
			slot_cell_size.y * ceili(float(item.size) / slot_columns))
	var visual := item.create_packed_visual(cell)
	_slots[start].add_child(visual)
	visual.position = centre - _slots[start].position
	_slot_visuals.append(visual)
	_spans.append(span)
	contents.append(item)
	contents_changed.emit()
	return true


## Takes the item at index `index` out of the box (rats steal items this way).
func remove_item_at(index: int) -> ItemData:
	if index < 0 or index >= contents.size():
		return null
	for slot_number in _spans[index]:
		_slot_used[slot_number] = false
	_slot_visuals[index].queue_free()
	_slot_visuals.remove_at(index)
	_spans.remove_at(index)
	var item := contents[index]
	contents.remove_at(index)
	contents_changed.emit()
	return item


## Takes the LAST packed item out again (R). Null when the box is closed or empty.
func take_last_item() -> ItemData:
	if forming or not is_open or contents.is_empty():
		return null
	return remove_item_at(contents.size() - 1)


## Peels the bill off the box (T) and returns its order (null = there was no bill).
func detach_order() -> Order:
	var order := attached_order
	attached_order = null
	if is_instance_valid(_bill_paper):
		_bill_paper.queue_free()
	_bill_paper = null
	if order != null:
		bill_changed.emit()
	return order


## The second prompt line: what R and T would do right now ("" = nothing).
func get_take_hint() -> String:
	var parts: PackedStringArray = []
	if not forming and is_open and not contents.is_empty():
		parts.append("[R] Take an item out")
	if attached_order != null:
		parts.append("[T] Take the bill off")
	return "   ".join(parts)


## The box described line by line (the panel on the right side of the screen).
func get_detail_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("%s - %s" % [box_name.capitalize(), "OPEN" if is_open else "CLOSED"])
	lines.append("Space: %d / %d" % [used_space(), capacity])
	lines.append("Weight: %.1f kg" % get_weight())
	var counts := {}
	for item in contents:
		counts[item.display_name] = int(counts.get(item.display_name, 0)) + 1
	if counts.is_empty():
		lines.append("Empty")
	for item_name in counts:
		lines.append("%d x %s" % [counts[item_name], item_name])
	lines.append("Bill #%d attached" % attached_order.number if attached_order != null else "No bill")
	return lines


## One-line summary for the HUD, e.g. "Open box 3/8 - Cereal x2, Soup Can x1".
func get_status_text() -> String:
	var counts := {}  # display_name -> count (Dictionary keeps insertion order)
	for item in contents:
		counts[item.display_name] = int(counts.get(item.display_name, 0)) + 1
	var parts: PackedStringArray = []
	for item_name in counts:
		parts.append("%s x%d" % [item_name, counts[item_name]])
	var state := "Open" if is_open else "Closed"
	var text := "%s %s %d/%d spaces, %.1f kg" % [state, box_name, used_space(), capacity, get_weight()]
	if not parts.is_empty():
		text += " - " + ", ".join(parts)
	text += "   |   Bill #%d attached" % attached_order.number if attached_order != null else "   |   no bill"
	return text


# ---- Interaction (pick up) --------------------------------------------------

## Set while this box sits on a pallet.
var placed_on: Pallet = null


# A box on a pallet is also what the player's ray hits when aiming at "the
# pallet", so while carrying another box it just forwards to the pallet.
func can_interact(who: Node) -> bool:
	var player := who as Player
	if player.carried != null:
		return placed_on != null and placed_on.can_interact(who)
	return placed_on == null or placed_on.can_release(self)


func get_prompt(who: Node) -> String:
	if (who as Player).carried != null and placed_on != null:
		return placed_on.get_prompt(who)
	return super(who)


func interact(who: Node) -> void:
	if (who as Player).carried != null and placed_on != null:
		placed_on.interact(who)
		return
	super(who)  # pick the box up


# ---- Using hotbar entries on the box (right click) --------------------------

## Text for the "use" prompt (right click) when `entry` is selected. Empty = hide.
func get_use_prompt(entry: InventoryEntry) -> String:
	if entry.kind == InventoryEntry.Kind.BILL:
		if attached_order != null:
			return "This box already has a bill"
		return "Attach bill #%d to this box" % entry.order.number
	if forming:
		return "Box isn't formed yet"
	if not is_open:
		return "Box is closed"
	if not has_room(entry.item.size):
		return "No room for %s (needs %d spaces)" % [entry.item.display_name, entry.item.size]
	return "Put %s in the box (+%d spaces, %d/%d)" % [entry.item.display_name, entry.item.size,
			used_space() + entry.item.size, capacity]


## The same as get_use_prompt, but short and without names (for the hints on the left).
func get_use_hint(entry: InventoryEntry) -> String:
	if entry.kind == InventoryEntry.Kind.BILL:
		return "This box already has a bill" if attached_order != null else "Attach the bill"
	if forming:
		return "The box is not formed yet"
	if not is_open:
		return "The box is closed"
	if not has_room(entry.item.size):
		return "No room in the box (needs %d spaces)" % entry.item.size
	return "Put in the box"


## Uses `entry` on this box. Returns true if it was consumed.
func use_entry(entry: InventoryEntry) -> bool:
	if entry.kind == InventoryEntry.Kind.BILL:
		if attached_order != null:
			return false
		attach_order(entry.order)
		return true
	return add_item(entry.item)


var _bill_paper: MeshInstance3D = null


## Sticks a bill on the front of the box. The box will be checked against it.
func attach_order(order: Order) -> void:
	attached_order = order
	# A little paper sheet on the front face, with the order number on it.
	var paper := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.2, 0.14, 0.004)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.95, 0.88)
	mesh.material = mat
	paper.mesh = mesh
	paper.position = Vector3(0.0, 0.25, 0.22)
	add_child(paper)
	_bill_paper = paper
	var label := Label3D.new()
	label.text = "#%d" % order.number
	label.pixel_size = 0.0025
	label.font_size = 48
	label.modulate = Color(0.1, 0.1, 0.1)
	label.outline_size = 0
	label.position = Vector3(0.0, 0.0, 0.004)
	paper.add_child(label)
	bill_changed.emit()


# ---- Carry (called by Player.pick_up / Player.put_down) -----------------

func on_picked_up(hold_point: Node3D, home: Node = null) -> void:
	if placed_on != null:
		# Taken off a pallet: it goes back to the world (the pallet's parent) if dropped.
		var pallet := placed_on
		placed_on = null
		pallet.release(self)
		super(hold_point, pallet.get_parent())
	else:
		super(hold_point, home)


## Sit on a pallet slot. Collision comes back on so the box can be picked up again.
func on_placed(slot: Node3D, pallet: Pallet) -> void:
	placed_on = pallet
	reparent(slot, false)
	transform = Transform3D.IDENTITY
	reset_physics_interpolation()
	collision_layer = _saved_collision_layer
