class_name InventoryEntry
extends RefCounted
## One thing in a hotbar slot: either a single item taken from a shelf, or a bill.
## Plain data - what it looks like in the hand / on the HUD is decided elsewhere.

enum Kind { ITEM, BILL }

var kind: Kind
## Set when kind == ITEM. `source` is the shelf it came from (Q puts it back).
var item: ItemData = null
var source: Shelf = null
## Set when kind == BILL.
var order: Order = null


static func make_item(p_item: ItemData, p_source: Shelf) -> InventoryEntry:
	var entry := InventoryEntry.new()
	entry.kind = Kind.ITEM
	entry.item = p_item
	entry.source = p_source
	return entry


static func make_bill(p_order: Order) -> InventoryEntry:
	var entry := InventoryEntry.new()
	entry.kind = Kind.BILL
	entry.order = p_order
	return entry


## Short text for the hotbar slot.
func get_label() -> String:
	if kind == Kind.BILL:
		return "Bill #%d" % order.number
	return item.display_name
