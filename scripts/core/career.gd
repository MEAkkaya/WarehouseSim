extends Node
## The "career" side of the game, registered as an AUTOLOAD named "Career" next to
## GameState: the fixed warehouse rules and being caught/banned, the boss's absurd
## daily EVENT, the best-employee ranking, home furniture and its perks, rent, and
## the ending when the bank reaches the goal.
##
## GameState holds the raw numbers (money, energy, the clock); Career decides what
## the bigger rules of the job do with them.

## The player was caught; WarehouseSite carries them out of the building.
## `by` is the supervisor who caught you (null if it was nobody in particular).
signal caught(reason: String, by: Node3D)
## Today's event changed (a new day began). `event` is null on a quiet day.
signal event_changed(event: EventData)
## The bank reached the goal for the first time.
signal retired

## How long the warehouse refuses you after being caught, in in-game hours.
const CAUGHT_BAN_HOURS: float = 3.0
## Chance that a day has a special event at all (one event at most per day). 0.32 means
## about two days in three are quiet, and an event comes roughly every third day.
const EVENT_CHANCE: float = 0.32
## A new game starts quietly: no events on the first this-many days.
const EVENT_FREE_DAYS: int = 3
const RENT_PER_DAY: int = 40
const BEST_EMPLOYEE_BONUS: int = 150
## You need at least this many correct orders in a day to count as "best employee".
const ORDERS_FOR_BONUS: int = 3
const DEFAULT_SLEEP_RESTORE: float = 60.0
const BASE_MAX_ENERGY: float = 100.0
## Co-workers get this many orders per in-game hour at skill 1.0.
const NPC_ORDERS_PER_HOUR: float = 0.45

## The rules that never change. A supervisor who SEES you break one throws you out.
const FIXED_RULES: Array[String] = [
	"No phones at work",
	"No smoking",
	"No gambling",
	"No snacking on the floor",
]

const NPC_NAMES: Array[String] = ["Greta", "Marcus", "Priya", "Tomasz", "Lena", "Dmitri", "Sandra"]

## The event of the current day (null = nothing special today).
var todays_event: EventData = null
## In-game total hours until which the warehouse refuses you (see GameState.get_total_hours).
var banned_until: float = -1.0
var orders_today: int = 0
## Co-workers: Dictionaries with name, skill, score (a float; shown rounded down).
var employees: Array[Dictionary] = []
var owned_furniture: Array[FurnitureData] = []
var sleep_restore: float = DEFAULT_SLEEP_RESTORE
## Multiplies off-shift energy regeneration (from furniture).
var regen_multiplier: float = 1.0
## After the ending the game goes on as free play.
var free_play: bool = false

var _event_pool: Array[EventData] = []
var _furniture_pool: Array[FurnitureData] = []
var _rng := RandomNumberGenerator.new()
var _caught_pending: bool = false
var _retired: bool = false


func _ready() -> void:
	for resource in _load_folder("res://data/events/"):
		if resource is EventData:
			_event_pool.append(resource)
	for resource in _load_folder("res://data/furniture/"):
		if resource is FurnitureData:
			_furniture_pool.append(resource)
	_furniture_pool.sort_custom(func(a: FurnitureData, b: FurnitureData) -> bool: return a.price < b.price)
	GameState.day_started.connect(_on_new_day)
	GameState.time_changed.connect(_on_minute)
	GameState.shift_changed.connect(_on_shift_changed)
	reset()


## Loads every .tres resource of a folder.
func _load_folder(path: String) -> Array:
	var result: Array = []
	for file in DirAccess.get_files_at(path):
		# Exported games list resources as "name.tres.remap".
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres"):
			result.append(load(path + name))
	return result


## A fresh game: nothing owned, no ban.
func reset() -> void:
	banned_until = -1.0
	orders_today = 0
	owned_furniture.clear()
	free_play = false
	_retired = false
	_caught_pending = false
	_recompute_perks()
	_reset_employees()
	pick_event()


# ---- The daily event -----------------------------------------------------------------

## The boss decides what madness today brings: nothing at all on the first
## EVENT_FREE_DAYS days and on about two days in three after that, otherwise exactly one
## random event (the same for the same day number).
func pick_event() -> void:
	_rng.seed = GameState.day * 7919 + 13
	todays_event = null
	if GameState.day <= EVENT_FREE_DAYS:
		event_changed.emit(null)
		return  # the first days of a new game are always quiet
	if not _event_pool.is_empty() and _rng.randf() < EVENT_CHANCE:
		todays_event = _event_pool[_rng.randi() % _event_pool.size()]
	event_changed.emit(todays_event)


## Text for the phone's notice board: the fixed rules and today's event.
func get_notice_text() -> String:
	var text := ""
	if is_banned():
		text += "BANNED from the warehouse until %s\n\n" % get_ban_end_text()
	text += "RULES\n"
	for rule in FIXED_RULES:
		text += "- %s\n" % rule
	text += "\nTODAY\n"
	if todays_event == null:
		text += "A normal day. (Suspicious.)"
	else:
		text += "%s\n%s" % [todays_event.title.to_upper(), todays_event.description]
	return text


# ---- Getting caught ----------------------------------------------------------------

## The boss' men have had enough: the multiplier is halved, you are thrown out and
## banned for a few hours.
func catch(reason: String, by: Node3D = null) -> void:
	if _caught_pending or not GameState.on_shift:
		return
	_caught_pending = true
	GameState.multiplier = maxf(1.0, GameState.multiplier / 2.0)
	GameState.multiplier_changed.emit(GameState.multiplier, GameState.shift_earnings)
	banned_until = GameState.get_total_hours() + CAUGHT_BAN_HOURS
	caught.emit(reason, by)


func is_banned() -> bool:
	return GameState.get_total_hours() < banned_until


## "Tue 14:30"
func get_ban_end_text() -> String:
	var total := int(banned_until * 60.0)
	var minutes := total % (24 * 60)
	var weekday := GameState.weekday_of_total_hours(banned_until)
	return "%s %02d:%02d" % [GameState.WEEKDAYS[weekday].left(3), minutes / 60, minutes % 60]


func _on_shift_changed(on_shift: bool) -> void:
	if not on_shift:
		_caught_pending = false


# ---- Orders, ranking ------------------------------------------------------------------

func on_order_completed() -> void:
	orders_today += 1


## All employees including the player, best first: {name, score, is_player}.
func get_ranking() -> Array[Dictionary]:
	var list: Array[Dictionary] = [{"name": "You", "score": orders_today, "is_player": true}]
	for employee in employees:
		list.append({"name": employee.name, "score": int(employee.score), "is_player": false})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.score != b.score:
			return a.score > b.score
		return a.is_player and not b.is_player)  # ties: the player ranks first
	return list


func get_player_rank() -> int:
	var ranking := get_ranking()
	for i in ranking.size():
		if ranking[i].is_player:
			return i + 1
	return ranking.size()


func _reset_employees() -> void:
	employees.clear()
	var names := NPC_NAMES.duplicate()
	names.shuffle()
	for i in 6:
		employees.append({"name": names[i], "skill": randf_range(0.6, 1.5), "score": 0.0})


## Co-workers keep working while the clock runs (called every in-game minute).
func _on_minute() -> void:
	# A ban quest ends when the ban does.
	if Quests.has(&"ban") and not is_banned():
		Quests.complete(&"ban")
		GameState.notice.emit("Your ban is over. You can go back to work.")
	for employee in employees:
		employee.score += employee.skill * NPC_ORDERS_PER_HOUR / 60.0 * randf_range(0.4, 1.6)


## Midnight: best-employee bonus, rent, a new ranking and a new event (or none).
func _on_new_day(_day: int) -> void:
	if orders_today >= ORDERS_FOR_BONUS and get_player_rank() == 1:
		Stats.add(&"best_employee_days")
		GameState.add_money(BEST_EMPLOYEE_BONUS)
		GameState.notice.emit("Best employee of the day! Bonus: $%d" % BEST_EMPLOYEE_BONUS)
	GameState.add_money(-RENT_PER_DAY)
	Stats.add(&"rent_paid", RENT_PER_DAY)
	orders_today = 0
	_reset_employees()
	pick_event()
	var text := "%s. Rent: -$%d." % [GameState.get_weekday_name(), RENT_PER_DAY]
	if todays_event != null:
		text += "\nTODAY: %s - %s" % [todays_event.title, todays_event.description]
	GameState.notice.emit(text)


# ---- Home and furniture ---------------------------------------------------------------

## The cheapest piece of furniture you do not own yet (null when you own all).
func get_next_furniture() -> FurnitureData:
	for furniture in _furniture_pool:
		if not owned_furniture.has(furniture):
			return furniture
	return null


## Buys the next piece if the bank can pay for it. Returns the bought item or null.
func buy_next_furniture() -> FurnitureData:
	var furniture := get_next_furniture()
	if furniture == null or GameState.bank < furniture.price:
		return null
	GameState.add_money(-furniture.price)
	owned_furniture.append(furniture)
	_recompute_perks()
	return furniture


func _recompute_perks() -> void:
	sleep_restore = DEFAULT_SLEEP_RESTORE
	regen_multiplier = 1.0
	var bonus := 0.0
	for furniture in owned_furniture:
		sleep_restore = maxf(sleep_restore, furniture.sleep_restore)
		regen_multiplier *= furniture.regen_multiplier
		bonus += furniture.max_energy_bonus
	GameState.max_energy = BASE_MAX_ENERGY + bonus
	GameState.energy = minf(GameState.energy, GameState.max_energy)
	GameState.energy_changed.emit(GameState.energy, GameState.max_energy)


## Sleeping at home: time passes, energy comes back according to the best bed.
func sleep_for(hours: float) -> void:
	GameState.advance_hours(hours)
	GameState.restore_energy(sleep_restore)
	GameState.heal(GameState.max_health)


# ---- Saving ---------------------------------------------------------------------------

func get_save_data() -> Dictionary:
	var ids: Array = []
	for furniture in owned_furniture:
		ids.append(String(furniture.id))
	return {"furniture": ids, "banned_until": banned_until, "free_play": free_play, "retired": _retired}


## Call after GameState.load_save_data() (today's event depends on the date).
func load_save_data(data: Dictionary) -> void:
	owned_furniture.clear()
	for id in data.get("furniture", []):
		for furniture in _furniture_pool:
			if String(furniture.id) == str(id):
				owned_furniture.append(furniture)
	banned_until = float(data.get("banned_until", -1.0))
	free_play = bool(data.get("free_play", false))
	_retired = bool(data.get("retired", false))
	_recompute_perks()
	pick_event()


# ---- Ending ---------------------------------------------------------------------------

## Called whenever money arrives: the first time the bank reaches the goal, you retire.
func check_retirement() -> void:
	if _retired or free_play or GameState.bank < GameState.GOAL:
		return
	_retired = true
	retired.emit()


## "Keep playing" after the ending.
func continue_free_play() -> void:
	free_play = true
