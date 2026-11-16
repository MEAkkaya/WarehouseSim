extends Node
## The quest log, registered as an AUTOLOAD named "Quests". A quest is a short title
## ("Banned until Mon 11:00") with an optional longer description. The HUD shows the
## titles at the top right; the phone's Quests app shows titles and descriptions.
##
## Anything can add one: `Quests.add(&"ban", "Banned until Mon 11:00", "You were caught...")`
## (adding the same id again just updates it) and finish it with `Quests.complete(&"ban")`.

## Something in the list changed (the HUD and phone redraw).
signal changed
## A quest that was not there before was added.
signal quest_added(id: StringName)

## Each quest: {id: StringName, title: String, description: String}.
var quests: Array[Dictionary] = []


func add(id: StringName, title: String, description: String = "") -> void:
	for quest in quests:
		if quest.id == id:
			quest.title = title
			quest.description = description
			changed.emit()
			return
	quests.append({"id": id, "title": title, "description": description})
	quest_added.emit(id)
	changed.emit()


## Removes a quest (it is done). Does nothing if it is not in the list.
func complete(id: StringName) -> void:
	for i in quests.size():
		if quests[i].id == id:
			quests.remove_at(i)
			changed.emit()
			return


func has(id: StringName) -> bool:
	for quest in quests:
		if quest.id == id:
			return true
	return false


func get_quest(id: StringName) -> Dictionary:
	for quest in quests:
		if quest.id == id:
			return quest
	return {}


func reset() -> void:
	quests.clear()
	changed.emit()


func get_save_data() -> Array:
	var data: Array = []
	for quest in quests:
		data.append({"id": String(quest.id), "title": quest.title, "description": quest.description})
	return data


func load_save_data(data: Array) -> void:
	quests.clear()
	for entry in data:
		quests.append({"id": StringName(entry.get("id", "")), "title": str(entry.get("title", "")),
				"description": str(entry.get("description", ""))})
	changed.emit()
