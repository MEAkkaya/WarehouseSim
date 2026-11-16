class_name Bill
extends Interactable
## A paper bill lying on the floor (e.g. after you put it down with Q). Click it
## to put it in your hotbar; select it there to read it, and right-click a box to
## attach it.

var order: Order = null


func can_interact(who: Node) -> bool:
	return (who as Player).inventory.has_room()


func get_prompt(_who: Node) -> String:
	return "Pick up bill #%d" % order.number if order != null else "Pick up bill"


func interact(who: Node) -> void:
	if order == null:
		return
	if (who as Player).inventory.add(InventoryEntry.make_bill(order)):
		queue_free()
		super(who)
