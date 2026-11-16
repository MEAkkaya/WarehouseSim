class_name EventData
extends Resource
## A special event the crazy boss can order for a day (data/events/*.tres). At most
## ONE event runs per day and many days have none. The behaviour lives in the effect
## script, a script that extends WarehouseEvent.
##
## To add an event: write scripts/events/my_event.gd (extends WarehouseEvent), then
## right-click data/events -> New Resource -> EventData and point `effect_script` at it.

@export var id: StringName = &""
## Name shown on the announcement and the phone's notice board.
@export var title: String = "Event"
## What the boss tells the employees (and what the player must do).
@export_multiline var description: String = ""
## The script that makes it happen (extends WarehouseEvent).
@export var effect_script: Script
