class_name TimerManager
extends Node

signal changed
signal tick(remaining_seconds: int)
signal completed(kind: Kind)

enum Kind {
	NONE,
	FOCUS,
	BREAK,
}

enum State {
	IDLE,
	RUNNING,
	PAUSED,
	WAITING_NEXT,
}

var time_source := Callable()
var kind := Kind.NONE
var state := State.IDLE
var end_unix := 0.0
var paused_remaining := 0.0
var next_kind := Kind.NONE

var _last_reported_seconds := -1


func _ready() -> void:
	_update_processing()


func _process(_delta: float) -> void:
	if state != State.RUNNING:
		return

	var remaining := remaining_seconds()
	if remaining <= 0:
		var completed_kind := kind
		_enter_waiting_next(completed_kind)
		changed.emit()
		tick.emit(0)
		completed.emit(completed_kind)
		return

	if remaining != _last_reported_seconds:
		_last_reported_seconds = remaining
		tick.emit(remaining)


func start_timer(timer_kind: Kind, duration_seconds: float) -> bool:
	if (
		timer_kind == Kind.NONE
		or duration_seconds <= 0.0
	):
		return false

	kind = timer_kind
	state = State.RUNNING
	end_unix = _now() + duration_seconds
	paused_remaining = 0.0
	next_kind = Kind.NONE
	_last_reported_seconds = -1
	_update_processing()
	changed.emit()
	_emit_current_tick()
	return true


func pause() -> bool:
	if state != State.RUNNING:
		return false

	paused_remaining = maxf(0.0, end_unix - _now())
	end_unix = 0.0
	state = State.PAUSED
	_last_reported_seconds = -1
	_update_processing()
	changed.emit()
	_emit_current_tick()
	return true


func resume() -> bool:
	if state != State.PAUSED or paused_remaining <= 0.0:
		return false

	end_unix = _now() + paused_remaining
	paused_remaining = 0.0
	state = State.RUNNING
	_last_reported_seconds = -1
	_update_processing()
	changed.emit()
	_emit_current_tick()
	return true


func cancel() -> bool:
	if state == State.IDLE:
		return false

	_reset_state()
	changed.emit()
	return true


func remaining_seconds() -> int:
	match state:
		State.RUNNING:
			return maxi(0, ceili(end_unix - _now()))
		State.PAUSED:
			return maxi(0, ceili(paused_remaining))
		_:
			return 0


func snapshot() -> Dictionary:
	return {
		"state": state,
		"kind": kind,
		"end_unix": end_unix,
		"paused_remaining": paused_remaining,
		"next_kind": next_kind,
	}


func restore(snapshot_data: Dictionary) -> bool:
	_reset_state()
	if snapshot_data.is_empty():
		return false

	var saved_state := int(snapshot_data.get("state", State.IDLE))
	var saved_kind := int(snapshot_data.get("kind", Kind.NONE))
	if (
		saved_kind <= Kind.NONE
		or saved_kind > Kind.BREAK
		or saved_state <= State.IDLE
		or saved_state > State.WAITING_NEXT
	):
		return false

	if saved_state == State.RUNNING:
		var saved_end := float(snapshot_data.get("end_unix", 0.0))
		if saved_end <= _now():
			_enter_waiting_next(saved_kind)
			changed.emit()
			completed.emit(saved_kind)
			return true
		kind = saved_kind
		state = State.RUNNING
		end_unix = saved_end
	elif saved_state == State.PAUSED:
		var saved_remaining := maxf(
			0.0,
			float(snapshot_data.get("paused_remaining", 0.0))
		)
		if saved_remaining <= 0.0:
			return false
		kind = saved_kind
		state = State.PAUSED
		paused_remaining = saved_remaining
	elif saved_state == State.WAITING_NEXT:
		var saved_next_kind := int(
			snapshot_data.get(
				"next_kind",
				_next_kind_after(saved_kind)
			)
		)
		if saved_next_kind <= Kind.NONE or saved_next_kind > Kind.BREAK:
			saved_next_kind = _next_kind_after(saved_kind)
		kind = saved_kind
		next_kind = saved_next_kind
		state = State.WAITING_NEXT

	_last_reported_seconds = -1
	_update_processing()
	changed.emit()
	_emit_current_tick()
	return true


func _emit_current_tick() -> void:
	var remaining := remaining_seconds()
	_last_reported_seconds = remaining
	tick.emit(remaining)


func _reset_state() -> void:
	kind = Kind.NONE
	state = State.IDLE
	end_unix = 0.0
	paused_remaining = 0.0
	next_kind = Kind.NONE
	_last_reported_seconds = -1
	_update_processing()


func _enter_waiting_next(completed_kind: Kind) -> void:
	kind = completed_kind
	state = State.WAITING_NEXT
	end_unix = 0.0
	paused_remaining = 0.0
	next_kind = _next_kind_after(completed_kind)
	_last_reported_seconds = -1
	_update_processing()


func _next_kind_after(completed_kind: Kind) -> Kind:
	if completed_kind == Kind.FOCUS:
		return Kind.BREAK
	if completed_kind == Kind.BREAK:
		return Kind.FOCUS
	return Kind.NONE


func _update_processing() -> void:
	set_process(state == State.RUNNING)


func _now() -> float:
	if time_source.is_valid():
		return float(time_source.call())
	return Time.get_unix_time_from_system()
