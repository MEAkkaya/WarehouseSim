class_name FurnitureShop
extends Interactable
## The furniture shop counter. Each click buys the cheapest piece of furniture you do
## not own yet, if you can afford it. Better beds mean more energy from sleeping;
## other pieces speed up resting or raise your maximum energy.


func get_prompt(_who: Node) -> String:
	var next := Career.get_next_furniture()
	if next == null:
		return "Everything bought - your home is perfect"
	return "Buy %s - $%s  (%s)" % [next.display_name, _money(next.price), _perk_text(next)]


func interact(who: Node) -> void:
	var next := Career.get_next_furniture()
	if next == null:
		return
	if Career.buy_next_furniture() == null:
		GameState.notice.emit("Not enough money for the %s ($%s)." % [next.display_name, _money(next.price)])
		return
	GameState.notice.emit("Bought %s! (%s)" % [next.display_name, _perk_text(next)])
	super(who)


func _perk_text(furniture: FurnitureData) -> String:
	var parts: PackedStringArray = []
	if furniture.sleep_restore > 0.0:
		parts.append("sleep gives +%d energy" % roundi(furniture.sleep_restore))
	if furniture.regen_multiplier != 1.0:
		parts.append("resting x%.1f" % furniture.regen_multiplier)
	if furniture.max_energy_bonus > 0.0:
		parts.append("max energy +%d" % roundi(furniture.max_energy_bonus))
	return ", ".join(parts)


func _money(amount: int) -> String:
	var digits := str(amount)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out
