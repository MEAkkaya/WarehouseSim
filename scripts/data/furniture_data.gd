class_name FurnitureData
extends Resource
## A piece of furniture you can buy for your home. Owning it gives permanent perks.
## The shop sells them in order of price (cheapest first).
##
## To add one: right-click data/furniture -> New Resource -> FurnitureData.

@export var id: StringName = &""
@export var display_name: String = "Furniture"
@export var price: int = 100
## Energy gained from a full night's sleep. The best owned item counts.
@export var sleep_restore: float = 0.0
## Off-shift energy regeneration is multiplied by the product of these.
@export var regen_multiplier: float = 1.0
## Added to the maximum energy.
@export var max_energy_bonus: float = 0.0
