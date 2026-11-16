class_name LoadQueue
extends Node
## Builds the warehouse a little each frame instead of all in one go, so entering
## never freezes the game. Anything heavy (creating hundreds of shelves, putting
## thousands of items on them) is added as a small task with `enqueue()`. Every frame
## the queue runs tasks until `budget_ms` milliseconds are used up, then lets the
## frame be drawn. The tasks run in the order they were added, so "create the shelves"
## always finishes before "stock the shelves" starts.
##
## `busy` is true while tasks are waiting; `finished` fires when the queue empties.
##
## Debugging: start the game with the environment variable LOADQUEUE_LOG set (or set
## `log_slow_ms`) and the queue prints, when it is done, every task that took longer than
## that and every frame that was longer than 20 ms. A slow task is what to cut into
## smaller pieces. (The report is printed at the end: printing during the frames would
## slow them down.)

signal finished

## How many milliseconds of each frame may be spent building.
@export var budget_ms: float = 4.0
## Debugging: report tasks that take at least this long (0 = off).
@export var log_slow_ms: float = 0.0

var _tasks: Array[Callable] = []
var _next: int = 0
var _report: Array[String] = []
var _last_ran: int = 0

## True while there is still something to build.
var busy: bool:
	get:
		return _next < _tasks.size()


func _ready() -> void:
	if OS.has_environment("LOADQUEUE_LOG"):
		log_slow_ms = 1.5
	add_to_group("load_queue")
	set_process(busy)


## Adds a task (any Callable). Tasks may add more tasks.
func enqueue(task: Callable) -> void:
	_tasks.append(task)
	set_process(true)


func _process(delta: float) -> void:
	var start := Time.get_ticks_usec()
	var limit := budget_ms * 1000.0
	var ran := 0
	while _next < _tasks.size():
		var task := _tasks[_next]
		_next += 1
		if task.is_valid():
			var task_start := Time.get_ticks_usec()
			task.call()
			ran += 1
			if log_slow_ms > 0.0:
				var task_ms := (Time.get_ticks_usec() - task_start) / 1000.0
				if task_ms >= log_slow_ms:
					var arguments := task.get_bound_arguments()
					_report.append("slow task %.1f ms: %s %s" % [task_ms, task.get_method(),
							str(arguments.back() if not arguments.is_empty() else "").left(34)])
		if Time.get_ticks_usec() - start >= limit:
			break
	if log_slow_ms > 0.0 and delta > 0.022:
		# `delta` is how long the PREVIOUS frame took.
		_report.append("a frame took %.1f ms (it ran %d tasks)" % [delta * 1000.0, _last_ran])
	_last_ran = ran
	if not busy:
		_tasks.clear()
		_next = 0
		set_process(false)
		var emit_start := Time.get_ticks_usec()
		finished.emit()
		if log_slow_ms > 0.0:
			_report.append("finished signal handlers took %.1f ms" % ((Time.get_ticks_usec() - emit_start) / 1000.0))
		for line in _report:
			print("[LoadQueue] ", line)
		_report.clear()
