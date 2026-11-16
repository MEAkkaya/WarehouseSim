class_name PurchaseCounter
extends Interactable
## A counter where you pay a little money for a little energy (the corner shop's
## overpriced sandwich, the club's bar). Builds its own box and sign.

@export var title: String = "Corner shop"
@export var product: String = "sandwich"
@export var price: int = 8
@export var energy: float = 12.0
## Stats key to count (&"snacks" or &"drinks").
@export var stat_key: StringName = &"snacks"
@export var size: Vector3 = Vector3(2.4, 1.1, 0.8)
@export var color: Color = Color(0.55, 0.4, 0.25)


func _ready() -> void:
	ApartmentKit.body_box(self, size, color)
	ApartmentKit.label(self, title, Vector3(0, size.y + 0.5, 0), 0.006, Color.WHITE, true)


func can_interact(who: Node) -> bool:
	return not GameState.on_shift and not (who as Player).busy


func get_prompt(_who: Node) -> String:
	if GameState.bank < price:
		return "%s: %s costs $%d (you cannot afford it)" % [title, product, price]
	return "Buy a %s - $%d (+%d energy)" % [product, price, roundi(energy)]


func interact(who: Node) -> void:
	if not GameState.spend_money(price):
		GameState.notice.emit("You cannot afford the %s ($%d)." % [product, price])
		return
	GameState.restore_energy(energy)
	Stats.add(stat_key)
	GameState.notice.emit("You bought a %s. +%d energy." % [product, roundi(energy)])
	super(who)
