class_name ItemCatalog
extends RefCounted
## Every ItemData in data/items, loaded ONCE and kept for the whole game. The warehouse is
## deleted every time you leave it, and with it every resource nobody else holds - so
## without this catalog all the item files and their models were read from disk again on
## every entry (that was a 30 ms hitch). Holding them here keeps them in memory.
## The world calls `get_all()` when it starts, so the first entry is as smooth as the rest.

static var _items: Array[ItemData] = []
static var _by_id: Dictionary = {}
static var _loaded: bool = false


static func get_all() -> Array[ItemData]:
	_load()
	return _items


static func find(id: String) -> ItemData:
	_load()
	return _by_id.get(id)


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for file in DirAccess.get_files_at("res://data/items/"):
		# Exported games list resources as "name.tres.remap".
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres"):
			var item := load("res://data/items/" + name) as ItemData
			if item != null:
				_items.append(item)
				_by_id[String(item.id)] = item
