class_name CrateStack
extends StaticBody3D
## A pallet of bulk crates in back storage. It is decoration: the game assumes the
## warehouse crew refills the shelves from these between shifts (every time you
## clock in the shelves are stocked again - see VisitGenerator).

@export var label_text: String = "RESTOCK PALLET"

@onready var _label: PaperLabel = $Label


func _ready() -> void:
	_label.set_paper_text(label_text)
