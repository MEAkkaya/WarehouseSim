class_name OpeningHours
extends RefCounted
## When a place is open: on which weekdays (0 = Monday ... 6 = Sunday) and between
## which hours. `to_hour` smaller than `from_hour` means "until the next morning"
## (a night club that opens on Friday at 20:00 is open until Saturday 06:00).
##
##   OpeningHours.make([0, 1, 2, 3, 4])             # Monday to Friday, all day
##   OpeningHours.make([4, 5, 6], 20.0, 6.0)        # Friday to Sunday nights

var days: Array[int] = []
var from_hour: float = 0.0
var to_hour: float = 24.0


static func make(open_days: Array[int], from_h: float = 0.0, to_h: float = 24.0) -> OpeningHours:
	var hours := OpeningHours.new()
	hours.days = open_days
	hours.from_hour = from_h
	hours.to_hour = to_h
	return hours


func is_open_at(weekday: int, hour: float) -> bool:
	if from_hour <= to_hour:
		return days.has(weekday) and hour >= from_hour and hour < to_hour
	# Past midnight: the evening belongs to `weekday`, the early morning to the day before.
	if hour >= from_hour:
		return days.has(weekday)
	if hour < to_hour:
		return days.has((weekday + 6) % 7)
	return false


func is_open_now() -> bool:
	return is_open_at(GameState.weekday, GameState.hour)


## "Mon-Fri, all day" / "Fri-Sun, 20:00-06:00"
func describe() -> String:
	var parts: PackedStringArray = []
	var i := 0
	while i < 7:
		if not days.has(i):
			i += 1
			continue
		var j := i
		while j + 1 < 7 and days.has(j + 1):
			j += 1
		var first: String = GameState.WEEKDAYS[i].left(3)
		parts.append(first if i == j else "%s-%s" % [first, GameState.WEEKDAYS[j].left(3)])
		i = j + 1
	var when := "all day" if from_hour <= 0.0 and to_hour >= 24.0 \
			else "%02d:00-%02d:00" % [int(from_hour), int(to_hour) % 24]
	return "%s, %s" % [", ".join(parts), when]
