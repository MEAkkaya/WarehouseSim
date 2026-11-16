class_name BlackMarketNPC
extends Interactable
## A shady co-worker who sometimes sells edible goods out of his jacket. You have to
## ASK (click him): half the time he has something. His stock is rolled when the
## warehouse is entered and again every few in-game hours. Goods go to your hotbar;
## eat them with E for energy. Paid from your bank account (via the phone).

## How many in-game hours until he restocks (rolls again).
@export var restock_hours: float = 4.0
@export_range(0.0, 1.0) var has_goods_chance: float = 0.5
## Black market prices are the shelf price times this.
@export var markup: int = 4

var _edible_items: Array[ItemData] = []
var _offer: ItemData = null
var _asked: bool = false
var _next_restock: float = 0.0


func _ready() -> void:
	for item in ItemCatalog.get_all():
		if item.edible:
			_edible_items.append(item)
	_roll_stock()


func _process(_delta: float) -> void:
	if GameState.get_total_hours() >= _next_restock:
		_roll_stock()


## Decides what he has right now (nothing is known to the player until they ask).
func _roll_stock() -> void:
	_next_restock = GameState.get_total_hours() + restock_hours
	_asked = false
	_offer = null
	if not _edible_items.is_empty() and randf() < has_goods_chance:
		_offer = _edible_items[randi() % _edible_items.size()]


func _price() -> int:
	return maxi(5, _offer.price * markup)


func can_interact(_who: Node) -> bool:
	return GameState.on_shift


func get_prompt(who: Node) -> String:
	if not _asked:
		return "Ask about goods"
	if _offer == null:
		return "Nothing today. Come back later."
	if not (who as Player).inventory.has_room():
		return "Hotbar is full"
	return "Buy %s - $%d (+%d energy)" % [_offer.display_name, _price(), roundi(_offer.energy_restore)]


func interact(who: Node) -> void:
	var player := who as Player
	if not _asked:
		_asked = true
		if _offer == null:
			GameState.notice.emit("\"Nothing today. Come back later.\"")
		else:
			GameState.notice.emit("\"Psst... I've got %s. $%d.\"" % [_offer.display_name, _price()])
		return
	if _offer == null or not player.inventory.has_room():
		return
	if not GameState.spend_money(_price()):
		GameState.notice.emit("\"No money, no snack.\"")
		return
	player.inventory.add(InventoryEntry.make_item(_offer, null))
	GameState.notice.emit("Bought %s. Eat it with E." % _offer.display_name)
	_offer = null
	super(who)
