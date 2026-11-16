extends Node
## Global game state, registered as an AUTOLOAD named "GameState"
## (Project Settings > Globals > Autoload), so any script can write
## `GameState.bank` without finding a node - like a static/singleton in C#.
##
## It owns the things that exist once for the whole game: the bank account, the
## energy bar and the in-game clock. It knows nothing about the scene (the
## warehouse, the player) - those read it and react to its signals.

## Emitted when the bank balance changes.
signal bank_changed(bank: int)
## Emitted when energy changes.
signal energy_changed(energy: float, max_energy: float)
## Emitted every time the in-game MINUTE changes (not every frame).
signal time_changed
## Emitted when a new day starts (at midnight).
signal day_started(day: int)
## Emitted when the player clocks in (true) or out (false).
signal shift_changed(on_shift: bool)
## Emitted when health changes.
signal health_changed(health: float, max_health: float)
## Emitted when the shift multiplier or the unpaid shift earnings change.
signal multiplier_changed(multiplier: float, unpaid: int)
## Emitted when a shift is paid out on clocking out.
signal payout_made(amount: int, multiplier: float)
## Emitted when the phone is opened or put away (supervisors will care later).
signal phone_toggled(open: bool)
## A message for the player (rent paid, new rules, bonuses...). The HUD shows it.
signal notice(text: String)
## Something at work knocked the player out (wrecking ball, burning floor...). The
## warehouse carries them outside, like passing out but without the energy loss.
signal knocked_out(reason: String)
## Emitted once when energy runs out while on shift (the warehouse then carries
## the player out - see WarehouseSite).
signal passed_out

## The goal: this much in the bank account and you can retire.
const GOAL: int = 1_000_000
## Hour of day the first day starts at.
const START_HOUR: float = 8.0
## The week: the first day of the game is a Monday.
const WEEKDAYS: Array[String] = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const START_WEEKDAY: int = 0

## Pay for one correctly shipped order (flat, before the multiplier).
const BASE_ORDER_PAY: int = 7
## Each correct order raises the multiplier by this much (it starts at 1.0).
const MULTIPLIER_STEP: float = 0.05

## Energy lost per IN-GAME hour while on shift (at normal effort), and regained per
## hour while off shift. A day lasts 24 real minutes, so one in-game hour = 1 minute.
const WORK_DRAIN_PER_HOUR: float = 12.0
const REST_REGEN_PER_HOUR: float = 6.0
## Passing out: the pay for that shift is cut to this fraction, the player wakes up
## outside with this much energy, and this many hours have gone by.
const PASSED_OUT_PAY_FACTOR: float = 0.5
const WAKE_UP_ENERGY: float = 30.0
const PASSED_OUT_HOURS: float = 2.0

## Money in the bank. Money earned during a shift is only paid out when you
## leave the warehouse; until then it is "unpaid" (see `shift_earnings`).
var bank: int = 0
var max_health: float = 100.0
var health: float = 100.0
var max_energy: float = 100.0
var energy: float = 100.0
## Base pay earned this shift and not yet paid, and the multiplier it will be
## paid with. The payout when you clock out is `shift_earnings * multiplier`.
var shift_earnings: int = 0
var multiplier: float = 1.0
var orders_this_shift: int = 0
## Multiplies the payout of the shift that is about to end (1.0 normally, lower after
## passing out). Reset after every payout.
var shift_pay_factor: float = 1.0
## True while the phone is out. The game keeps running, so a supervisor can
## catch you using it.
var phone_open: bool = false
## Gravity for loose items and the player (1.0 normal; the Low Gravity event lowers it).
var gravity_scale: float = 1.0
## The Power Outage event: the warehouse is dark while this is set (and on shift).
var blackout: bool = false
## Days passed counter (1 = the first day). It is internal (seeds, bans, timers): the
## game only SHOWS weekdays (see `weekday`); the Stats app shows `get_days_passed()`.
var day: int = 1
## Hour of the day as a decimal: 0.0 = midnight, 12.5 = 12:30.
var hour: float = START_HOUR
## How many in-game minutes pass per real second (1.0 = a day lasts 24 minutes).
var minutes_per_second: float = 1.0
## Set false to freeze the clock (menus, cinematics).
var clock_running: bool = true
## True while the player is inside the warehouse (between clocking in and out).
var on_shift: bool = false
## Hour of the day the current shift started (only meaningful while on_shift).
var shift_start_hour: float = 0.0

var _last_minute: int = -1
var _passing_out: bool = false


func _process(delta: float) -> void:
	if clock_running:
		advance_hours(minutes_per_second * delta / 60.0)


# ---- Clock ------------------------------------------------------------------

## Moves the clock forward (negative values are not supported).
func advance_hours(hours: float) -> void:
	hour += hours
	while hour >= 24.0:
		hour -= 24.0
		day += 1
		day_started.emit(day)
	var minute := int(hour * 60.0)
	if minute != _last_minute:
		_last_minute = minute
		time_changed.emit()


## Today as a weekday: 0 = Monday ... 6 = Sunday.
var weekday: int:
	get:
		return (day - 1 + START_WEEKDAY) % 7


func get_weekday_name(short: bool = false) -> String:
	var weekday_name := WEEKDAYS[weekday]
	return weekday_name.left(3) if short else weekday_name


## Whole days since the start (0 on the first day).
func get_days_passed() -> int:
	return day - 1


## The weekday (0-6) of a moment given in total hours since the start.
func weekday_of_total_hours(total_hours: float) -> int:
	return (int(floor(total_hours / 24.0)) + START_WEEKDAY) % 7


## "Mon 08:30"
func get_clock_text() -> String:
	var total_minutes := int(hour * 60.0)
	return "%s %02d:%02d" % [get_weekday_name(true), total_minutes / 60, total_minutes % 60]


## Sun height: 1.0 at noon, 0.0 at 06:00 and 18:00, -1.0 at midnight.
func get_sun_height() -> float:
	return sin((hour - 6.0) / 24.0 * TAU)


func is_night() -> bool:
	return get_sun_height() < 0.0


# ---- Money ------------------------------------------------------------------

func add_money(amount: int) -> void:
	bank += amount
	bank_changed.emit(bank)
	Career.check_retirement()


## Pays `amount` out of the bank if there is enough. Returns whether it worked.
func spend_money(amount: int) -> bool:
	if bank < amount:
		return false
	add_money(-amount)
	return true


## Hours since the very start of day 1 (always grows; used for bans and timers).
func get_total_hours() -> float:
	return (day - 1) * 24.0 + hour


## True once the retirement goal is reached.
func has_won() -> bool:
	return bank >= GOAL


# ---- Energy -----------------------------------------------------------------

## Removes energy (clamped at 0). Returns true if there is still energy left.
## Running out of energy on shift makes the player pass out.
func spend_energy(amount: float) -> bool:
	energy = clampf(energy - amount, 0.0, max_energy)
	energy_changed.emit(energy, max_energy)
	if energy <= 0.0 and on_shift and not _passing_out:
		_passing_out = true
		passed_out.emit()
	return energy > 0.0


func restore_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, max_energy)
	energy_changed.emit(energy, max_energy)


## Called every physics frame by the player. On shift energy drains in proportion
## to `activity` (1.0 = walking about, more when sprinting or carrying, less when
## standing still); off shift it slowly comes back.
func tick_energy(delta: float, activity: float) -> void:
	if not clock_running:
		return
	var hours := minutes_per_second * delta / 60.0
	if on_shift:
		spend_energy(WORK_DRAIN_PER_HOUR * activity * hours)
	elif energy < max_energy:
		restore_energy(REST_REGEN_PER_HOUR * Career.regen_multiplier * hours)


## The player has been carried outside after passing out: some rest, some time lost.
func wake_up() -> void:
	_passing_out = false
	energy = WAKE_UP_ENERGY
	energy_changed.emit(energy, max_energy)
	advance_hours(PASSED_OUT_HOURS)


# ---- Shift (the warehouse entrance is the boundary) --------------------------

## The player walked into the warehouse.
func clock_in() -> void:
	if on_shift:
		return
	on_shift = true
	shift_start_hour = hour
	_reset_shift_pay()
	shift_changed.emit(true)


## The player walked out: whatever was earned is paid out now, times the
## multiplier, into the bank.
func clock_out() -> void:
	if not on_shift:
		return
	on_shift = false
	var payout := roundi(get_pending_payout() * shift_pay_factor)
	shift_pay_factor = 1.0
	var paid_multiplier := multiplier
	if payout > 0:
		add_money(payout)
	_reset_shift_pay()
	if payout > 0:
		payout_made.emit(payout, paid_multiplier)
	shift_changed.emit(false)


## Hours worked in the current shift (handles passing midnight).
func get_shift_hours() -> float:
	return fposmod(hour - shift_start_hour, 24.0) if on_shift else 0.0


# ---- Orders, pay and the multiplier (step 2.3) ---------------------------------

## Called when a shipped box has been checked. A correct box pays the order's base
## pay and raises the multiplier; a wrong box (or one with no bill - `order` may be
## null) throws the multiplier back to 1.0.
func order_shipped(order: Order, correct: bool) -> void:
	if not on_shift:
		return
	if correct and order != null:
		shift_earnings += BASE_ORDER_PAY
		orders_this_shift += 1
		Career.on_order_completed()
		multiplier += MULTIPLIER_STEP
		Stats.add(&"orders_correct")
		Stats.set_max(&"best_multiplier", multiplier)
	else:
		multiplier = 1.0
		Stats.add(&"orders_wrong")
	multiplier_changed.emit(multiplier, shift_earnings)


## What you would be paid if you clocked out right now.
func get_pending_payout() -> int:
	return roundi(shift_earnings * multiplier)


func _reset_shift_pay() -> void:
	shift_earnings = 0
	multiplier = 1.0
	orders_this_shift = 0
	multiplier_changed.emit(multiplier, shift_earnings)


# ---- Health ------------------------------------------------------------------

func damage(amount: float) -> void:
	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(health, max_health)


func heal(amount: float) -> void:
	health = clampf(health + amount, 0.0, max_health)
	health_changed.emit(health, max_health)


# ---- Phone -------------------------------------------------------------------

func set_phone_open(open: bool) -> void:
	if phone_open != open:
		phone_open = open
		phone_toggled.emit(open)


# ---- Saving --------------------------------------------------------------------

func get_save_data() -> Dictionary:
	return {"bank": bank, "health": health, "energy": energy, "day": day, "hour": hour}


## Call after reset(). Career.load_save_data() must follow (it fixes the energy limit).
func load_save_data(data: Dictionary) -> void:
	bank = int(data.get("bank", 0))
	health = clampf(float(data.get("health", max_health)), 1.0, max_health)
	energy = maxf(float(data.get("energy", max_energy)), 0.0)
	day = maxi(1, int(data.get("day", 1)))
	hour = clampf(float(data.get("hour", START_HOUR)), 0.0, 23.99)
	_last_minute = -1
	bank_changed.emit(bank)
	health_changed.emit(health, max_health)
	energy_changed.emit(energy, max_energy)
	time_changed.emit()


# ---- New game ----------------------------------------------------------------

## Back to the very start (the main menu's Play button calls this).
func reset() -> void:
	bank = 0
	health = max_health
	energy = max_energy
	day = 1
	hour = START_HOUR
	_last_minute = -1
	clock_running = true
	on_shift = false
	phone_open = false
	shift_pay_factor = 1.0
	_passing_out = false
	gravity_scale = 1.0
	blackout = false
	Stats.reset()
	Quests.reset()
	_reset_shift_pay()
	Career.reset()
	bank_changed.emit(bank)
	health_changed.emit(health, max_health)
	energy_changed.emit(energy, max_energy)
	time_changed.emit()
