class_name Bike
extends Interactable
## Your bike (placeholder box). Click to get on: you move twice as fast outside. You
## cannot ride into work - the warehouse lobby makes you get off. Q gets you off the
## bike anywhere and leaves it where you stand.


func can_interact(who: Node) -> bool:
	return not (who as Player).riding_bike and not GameState.on_shift


func get_prompt(_who: Node) -> String:
	return "Ride the bike (twice as fast outside)"


func interact(who: Node) -> void:
	(who as Player).mount_bike(self)
	super(who)
