class_name ActivitySpot
extends Interactable
## A mischief spot hidden in a corner of the warehouse. Use it while no supervisor
## is looking - being seen doing it gets you caught (thrown out, multiplier halved,
## banned for a few hours).
##
##   SMOKE:  a few seconds of smoking gives energy back.
##   GAMBLE: bet some money on a coin flip with the other workers.

enum Kind { SMOKE, GAMBLE }

@export var kind: Kind = Kind.SMOKE
## How long the activity takes, in seconds.
@export var duration: float = 7.0
## Energy gained per second while smoking.
@export var energy_per_second: float = 4.0
## Gambling: the stake and the chance of doubling it.
@export var bet: int = 50
@export_range(0.0, 1.0) var win_chance: float = 0.45

@onready var _label: Label3D = $Label


func _ready() -> void:
	_label.text = "SMOKE BREAK" if kind == Kind.SMOKE else "POKER (bets: $%d)" % bet


func can_interact(who: Node) -> bool:
	var player := who as Player
	return GameState.on_shift and not player.busy and not player.frozen


func get_prompt(_who: Node) -> String:
	if kind == Kind.SMOKE:
		return "Take a smoke break (+%d energy)" % roundi(energy_per_second * duration)
	if GameState.bank < bet:
		return "Not enough money to bet ($%d)" % bet
	return "Gamble $%d (%d%% to double it)" % [bet, roundi(win_chance * 100.0)]


func interact(who: Node) -> void:
	var player := who as Player
	if kind == Kind.SMOKE:
		player.start_activity(&"smoking", duration, energy_per_second)
		GameState.notice.emit("Smoking... hope nobody is watching.")
	else:
		if not GameState.spend_money(bet):
			return
		player.start_activity(&"gambling", duration, 0.0, _resolve_bet)
		GameState.notice.emit("Cards are dealt... hope nobody is watching.")
	super(who)


func _resolve_bet() -> void:
	if randf() < win_chance:
		GameState.add_money(bet * 2)
		GameState.notice.emit("You won! +$%d" % bet)
	else:
		GameState.notice.emit("You lost $%d." % bet)
