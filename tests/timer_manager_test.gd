extends SceneTree

const TimerManagerScript := preload("res://src/timers/timer_manager.gd")

var _timer
var _fake_now := 1000.0
var _completed_kinds: Array[int] = []
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_timer = _new_timer()
	_expect(
		_timer.start_timer(TimerManagerScript.Kind.FOCUS, 10.0),
		"focus timer must start"
	)
	_expect(_timer.remaining_seconds() == 10, "focus timer starts at 10 seconds")

	_fake_now += 3.2
	_expect(
		_timer.remaining_seconds() == 7,
		"running timer uses absolute wall-clock time"
	)
	_expect(_timer.pause(), "running timer must pause")
	_fake_now += 20.0
	_expect(
		_timer.remaining_seconds() == 7,
		"paused timer must not advance"
	)
	_expect(_timer.resume(), "paused timer must resume")

	_fake_now += 6.8
	_timer._process(0.0)
	_expect(
		_completed_kinds == [TimerManagerScript.Kind.FOCUS],
		"focus timer must complete once"
	)
	_expect(
		_timer.state == TimerManagerScript.State.WAITING_NEXT,
		"completed timer waits for the next stage"
	)
	_expect(
		_timer.next_kind == TimerManagerScript.Kind.BREAK,
		"completed focus timer points to a break"
	)
	var waiting_snapshot: Dictionary = _timer.snapshot()
	var restored_waiting_timer = _new_timer()
	var completion_count_before_restore := _completed_kinds.size()
	_expect(
		restored_waiting_timer.restore(waiting_snapshot),
		"waiting-next snapshot must restore"
	)
	_expect(
		restored_waiting_timer.state
		== TimerManagerScript.State.WAITING_NEXT,
		"restored timer must remain waiting for the next stage"
	)
	_expect(
		restored_waiting_timer.next_kind
		== TimerManagerScript.Kind.BREAK,
		"restored waiting timer must preserve the next stage"
	)
	_expect(
		_completed_kinds.size() == completion_count_before_restore,
		"restoring a waiting state must not complete the stage twice"
	)

	_expect(
		_timer.start_timer(TimerManagerScript.Kind.BREAK, 5.0),
		"break timer must start"
	)
	var running_snapshot: Dictionary = _timer.snapshot()
	_fake_now += 2.0

	var restored_timer = _new_timer()
	_expect(
		restored_timer.restore(running_snapshot),
		"running timer snapshot must restore"
	)
	_expect(
		restored_timer.remaining_seconds() == 3,
		"restored timer keeps its original deadline"
	)
	_expect(restored_timer.cancel(), "restored timer must cancel")

	var expired_snapshot := {
		"state": TimerManagerScript.State.RUNNING,
		"kind": TimerManagerScript.Kind.FOCUS,
		"end_unix": _fake_now - 1.0,
		"paused_remaining": 0.0,
	}
	var expired_timer = _new_timer()
	_expect(
		expired_timer.restore(expired_snapshot),
		"expired snapshot must be handled"
	)
	_expect(
		_completed_kinds.count(TimerManagerScript.Kind.FOCUS) == 2,
		"expired timer must emit completion after restart"
	)
	_expect(
		expired_timer.state == TimerManagerScript.State.WAITING_NEXT,
		"expired restored timer must wait instead of chaining stages"
	)

	var one_second_timer = _new_timer()
	_expect(
		one_second_timer.start_timer(TimerManagerScript.Kind.FOCUS, 1.0),
		"one-second development timer must start"
	)
	_fake_now += 1.1
	one_second_timer._process(0.0)
	_expect(
		_completed_kinds.count(TimerManagerScript.Kind.FOCUS) == 3,
		"one-second development timer must complete"
	)
	_expect(
		one_second_timer.next_kind == TimerManagerScript.Kind.BREAK,
		"one-second focus completion must point to a break"
	)

	var health_timer = _new_timer()
	_expect(
		health_timer.start_timer(TimerManagerScript.Kind.WATER, 1.0),
		"generic timer must accept a health reminder kind"
	)
	_fake_now += 1.1
	health_timer._process(0.0)
	_expect(
		health_timer.next_kind == TimerManagerScript.Kind.WATER,
		"completed health timer must wait on the same reminder kind"
	)

	if _failed:
		quit(1)
		return
	print("Timer manager self-test passed.")
	quit(0)


func _new_timer():
	var timer = TimerManagerScript.new()
	timer.time_source = func() -> float: return _fake_now
	timer.completed.connect(_completed_kinds.append)
	root.add_child(timer)
	return timer


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Timer manager self-test failed: %s" % message)
