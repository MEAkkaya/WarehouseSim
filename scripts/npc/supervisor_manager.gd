class_name SupervisorManager
extends Node
## Creates the supervisors of this visit and turns the player's "heat" into how many
## watch the floor. Heat comes from the multiplier: the better you do, the more the
## company looks at you. It also turns what supervisors report into game events:
## strikes, being caught, scoldings.
##
## The patrol route is a fixed loop through the warehouse (it follows the aisle
## centres of the storeroom layout); supervisors start at different points of it.

@export var supervisor_scene: PackedScene = preload("res://scenes/npc/supervisor.tscn")
## Multiplier at which heat tier 1 / tier 2 begin.
@export var tier1_multiplier: float = 1.5
@export var tier2_multiplier: float = 2.5

## The patrol loop (see WarehouseLayout.SUPERVISOR_ROUTE): the corridor, the Z room, the
## Y room, the X room and back.
const ROUTE: Array[Vector3] = WarehouseLayout.SUPERVISOR_ROUTE

var supervisors: Array[Supervisor] = []
var _player: Player = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("players") as Player
	GameState.multiplier_changed.connect(_on_multiplier_changed)
	GameState.passed_out.connect(_release_player)
	Career.caught.connect(_on_caught)
	_update_count()


## 0 = calm, 1 = warnings, 2 = lots of attention.
func get_heat_tier() -> int:
	if GameState.multiplier >= tier2_multiplier:
		return 2
	if GameState.multiplier >= tier1_multiplier:
		return 1
	return 0


func _on_multiplier_changed(_multiplier: float, _unpaid: int) -> void:
	_update_count()


## Tier 0: one supervisor, tier 1: two, tier 2: three.
func _update_count() -> void:
	var tier := get_heat_tier()
	while supervisors.size() < tier + 1:
		_spawn()
	for supervisor in supervisors:
		supervisor.heat_tier = tier


func _spawn() -> void:
	var supervisor := supervisor_scene.instantiate() as Supervisor
	supervisor.route = PackedVector3Array(ROUTE)
	supervisor.player = _player
	supervisor.heat_tier = get_heat_tier()
	# Spread them over the route; the first one starts deep in the building.
	var start_index := (4 + supervisors.size() * 6) % ROUTE.size()
	add_child(supervisor)
	supervisor.global_position = ROUTE[start_index]
	supervisor._target_index = (start_index + 1) % ROUTE.size()
	supervisor.caught_core_violation.connect(_on_core_violation.bind(supervisor))
	supervisors.append(supervisor)


func _on_core_violation(kind: StringName, supervisor: Supervisor) -> void:
	var reasons := {
		&"phone": "using your phone at work",
		&"smoking": "smoking on the job",
		&"gambling": "gambling at work",
		&"eating": "snacking on the floor",
	}
	Career.catch("caught " + reasons.get(kind, "breaking the rules"), supervisor)


func _on_caught(_reason: String, _by: Node3D) -> void:
	_release_player()


## An alarm: every supervisor comes running.
func alert_all() -> void:
	for supervisor in supervisors:
		supervisor.alert()


## The player is being carried out: nobody keeps them frozen or watched.
func _release_player() -> void:
	for supervisor in supervisors:
		supervisor.finish_lecture()
		supervisor.state = Supervisor.State.PATROL
