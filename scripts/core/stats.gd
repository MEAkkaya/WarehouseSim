extends Node
## Statistics for the phone's Stats app, registered as an AUTOLOAD named "Stats".
## It only counts things (other scripts call `add()`), plus a few signals it listens
## to itself. Days are NOT shown anywhere else as a number - the game shows weekdays -
## so "days passed" lives here.

## key -> number. Keys used: shifts_worked, hours_worked, orders_correct, orders_wrong,
## money_earned, rent_paid, best_multiplier, best_employee_days, times_caught,
## times_passed_out, times_knocked_out, gambles, gambled_wagered, gambled_won, dances,
## drinks, snacks, play_seconds.
var counters: Dictionary = {}


func _ready() -> void:
	GameState.payout_made.connect(func(amount: int, _m: float) -> void: add(&"money_earned", amount))
	GameState.passed_out.connect(func() -> void: add(&"times_passed_out"))
	GameState.knocked_out.connect(func(_r: String) -> void: add(&"times_knocked_out"))
	GameState.shift_changed.connect(func(on: bool) -> void:
		if on:
			add(&"shifts_worked"))
	Career.caught.connect(func(_r: String, _by: Node3D) -> void: add(&"times_caught"))


func _process(delta: float) -> void:
	if GameState.clock_running:
		add(&"play_seconds", delta)
		if GameState.on_shift:
			add(&"hours_worked", GameState.minutes_per_second * delta / 60.0)


func get_save_data() -> Dictionary:
	var data := {}
	for key in counters:
		data[String(key)] = counters[key]
	return data


func load_save_data(data: Dictionary) -> void:
	counters.clear()
	for key in data:
		counters[StringName(key)] = float(data[key])


func reset() -> void:
	counters.clear()


func add(key: StringName, amount: float = 1.0) -> void:
	counters[key] = get_value(key) + amount


func set_max(key: StringName, value: float) -> void:
	counters[key] = maxf(get_value(key), value)


func get_value(key: StringName) -> float:
	return counters.get(key, 0.0)


## The lines of the Stats app.
func get_text() -> String:
	var lines: PackedStringArray = []
	lines.append("Days passed: %d" % GameState.get_days_passed())
	lines.append("Today: %s" % GameState.get_weekday_name())
	lines.append("Time played: %s" % _play_time())
	lines.append("")
	lines.append("Shifts worked: %d  (%.1f h)" % [int(get_value(&"shifts_worked")), get_value(&"hours_worked")])
	lines.append("Orders: %d correct, %d wrong" % [int(get_value(&"orders_correct")), int(get_value(&"orders_wrong"))])
	lines.append("Best multiplier: x%.2f" % maxf(1.0, get_value(&"best_multiplier")))
	lines.append("Earned at work: $%d" % int(get_value(&"money_earned")))
	lines.append("Rent paid: $%d" % int(get_value(&"rent_paid")))
	lines.append("Best employee: %d x   Trucks loaded: %d" % [int(get_value(&"best_employee_days")), int(get_value(&"trucks_loaded"))])
	lines.append("")
	lines.append("Caught: %d   Passed out: %d   Knocked out: %d" % [
			int(get_value(&"times_caught")), int(get_value(&"times_passed_out")), int(get_value(&"times_knocked_out"))])
	lines.append("Gambling: %d bets, $%d staked, $%d won back" % [
			int(get_value(&"gambles")), int(get_value(&"gambled_wagered")), int(get_value(&"gambled_won"))])
	lines.append("Dances: %d   Drinks: %d   Snacks: %d" % [
			int(get_value(&"dances")), int(get_value(&"drinks")), int(get_value(&"snacks"))])
	return "\n".join(lines)


func _play_time() -> String:
	var seconds := int(get_value(&"play_seconds"))
	return "%d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
