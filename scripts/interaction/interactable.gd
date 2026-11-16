class_name Interactable
extends StaticBody3D
## Base class for everything the player can interact with (shelves, boxes,
## pallets, the order printer...).
##
## GDScript concept: `class_name` registers this script as a global type, so you
## can write `var x: Interactable` anywhere and add it from the "Create Node"
## dialog. Think of it like a public C# class with no namespace.
##
## It extends StaticBody3D because the Interactor finds targets with a physics
## raycast, and rays only hit physics bodies. Subclasses override the three
## "virtual" methods below (GDScript has no `virtual` keyword - any method can
## be overridden by redefining it in the child script).

## Emitted when someone interacts. Useful for wiring up simple behaviour from the
## editor (Node tab -> Signals) without writing a subclass.
signal interacted(who: Node)

## Text shown in the HUD, e.g. "Take box". The HUD adds the "[Click]" part.
@export var prompt_text: String = "Interact"
## Handy while prototyping: prints to the Output panel on every interaction.
@export var debug_log: bool = false


## Can `who` (normally a Player) interact right now? Return false to hide the prompt.
func can_interact(_who: Node) -> bool:
	return true


## Prompt text for `who`. Override to make it dynamic (e.g. "Place item" while
## carrying something, "Take item" while empty-handed).
func get_prompt(_who: Node) -> String:
	return prompt_text


## Called by the Interactor while the player aims at this object and can use it.
## Override to light the object up (see WorldItem).
func set_highlighted(_on: bool) -> void:
	pass


## Called by the Interactor when the interact key is pressed on this object.
## Override and call super(who) if you still want the signal + debug log.
func interact(who: Node) -> void:
	if debug_log:
		print("%s interacted with %s" % [who.name, name])
	interacted.emit(who)
