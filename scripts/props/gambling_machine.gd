class_name GamblingMachine
extends Interactable
## A game in the back room: pay the bet, wait a few seconds, maybe win `payout` times
## the bet. The odds are (slightly) against you. Builds its own box and sign.

@export var title: String = "Slot machine"
@export var bet: int = 20
@export_range(0.0, 1.0) var win_chance: float = 0.3
## A win pays bet x payout.
@export var payout: float = 3.0
@export var duration: float = 2.5
@export var size: Vector3 = Vector3(0.8, 1.9, 0.7)
@export var color: Color = Color(0.7, 0.1, 0.35)


func _ready() -> void:
	ApartmentKit.body_box(self, size, color, 0.4)
	ApartmentKit.label(self, title, Vector3(0, size.y + 0.4, 0), 0.005, Color(1, 0.85, 0.3), true)


func can_interact(who: Node) -> bool:
	return not GameState.on_shift and not (who as Player).busy


func get_prompt(_who: Node) -> String:
	if GameState.bank < bet:
		return "%s: bet $%d (not enough money)" % [title, bet]
	return "%s: bet $%d (%d%% to win $%d)" % [title, bet, roundi(win_chance * 100.0), roundi(bet * payout)]


func interact(who: Node) -> void:
	if not GameState.spend_money(bet):
		GameState.notice.emit("Not enough money for the bet ($%d)." % bet)
		return
	Stats.add(&"gambles")
	Stats.add(&"gambled_wagered", bet)
	(who as Player).start_activity(&"gambling", duration, 0.0, _resolve)
	GameState.notice.emit("The reels spin...")
	super(who)


func _resolve() -> void:
	if randf() < win_chance:
		var win := roundi(bet * payout)
		GameState.add_money(win)
		Stats.add(&"gambled_won", win)
		GameState.notice.emit("WINNER! +$%d" % win)
	else:
		GameState.notice.emit("You lost $%d. The house thanks you." % bet)
