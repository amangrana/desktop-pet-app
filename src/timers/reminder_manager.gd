class_name ReminderManager
extends Node

signal changed
signal tick(kind: int, remaining_seconds: int)
signal reminder_due(kind: int)
signal quiet_state_changed(is_quiet: bool)

const TimerManagerScript := preload("res://src/timers/timer_manager.gd")

const WATER_INTERVAL_SECONDS := 60 * 60
const STAND_INTERVAL_SECONDS := 45 * 60
const SNOOZE_SECONDS := 10 * 60
const MIN_INTERVAL_SECONDS := 5 * 60
const MAX_INTERVAL_SECONDS := 4 * 60 * 60
const MIN_SNOOZE_SECONDS := 60
const MAX_SNOOZE_SECONDS := 60 * 60

var time_source := Callable()
var local_hour_source := Callable()

var _timers: Dictionary = {}
var _enabled := {
	TimerManagerScript.Kind.WATER: false,
	TimerManagerScript.Kind.STAND: false,
}
var _paused_until := {
	TimerManagerScript.Kind.WATER: 0.0,
	TimerManagerScript.Kind.STAND: 0.0,
}
var _intervals := {
	TimerManagerScript.Kind.WATER: WATER_INTERVAL_SECONDS,
	TimerManagerScript.Kind.STAND: STAND_INTERVAL_SECONDS,
}
var _snooze_seconds := SNOOZE_SECONDS
var _quiet_enabled := false
var _quiet_start_hour := 22
var _quiet_end_hour := 8
var _last_quiet_state := false
var _next_boundary_check_unix := 0.0


func _ready() -> void:
	_ensure_timers()
	_last_quiet_state = is_quiet_now()
	_update_processing()


func _process(_delta: float) -> void:
	if _now() < _next_boundary_check_unix:
		return
	_next_boundary_check_unix = _now() + 1.0
	var resumed_any := false
	for kind in _reminder_kinds():
		if not is_enabled(kind):
			continue
		var resume_at := float(_paused_until.get(kind, 0.0))
		if resume_at <= 0.0 or _now() < resume_at:
			continue
		_paused_until[kind] = 0.0
		_timer_for(kind).start_timer(kind, interval_seconds(kind))
		resumed_any = true
	var quiet_now := is_quiet_now()
	if quiet_now != _last_quiet_state:
		_last_quiet_state = quiet_now
		quiet_state_changed.emit(quiet_now)
	_update_processing()
	if resumed_any:
		changed.emit()


func set_enabled(kind: int, enabled: bool) -> bool:
	if not _is_reminder_kind(kind):
		return false
	_ensure_timers()
	if is_enabled(kind) == enabled:
		return false

	_enabled[kind] = enabled
	_paused_until[kind] = 0.0
	var timer = _timer_for(kind)
	if enabled:
		timer.start_timer(kind, interval_seconds(kind))
	else:
		timer.cancel()
	_update_processing()
	changed.emit()
	return true


func is_enabled(kind: int) -> bool:
	return bool(_enabled.get(kind, false))


func is_due(kind: int) -> bool:
	if not is_enabled(kind):
		return false
	var timer = _timer_for(kind)
	return (
		timer != null
		and timer.state == TimerManagerScript.State.WAITING_NEXT
	)


func is_paused_today(kind: int) -> bool:
	return (
		is_enabled(kind)
		and float(_paused_until.get(kind, 0.0)) > _now()
	)


func remaining_seconds(kind: int) -> int:
	var timer = _timer_for(kind)
	if timer == null:
		return 0
	return timer.remaining_seconds()


func interval_seconds(kind: int) -> int:
	return int(_intervals.get(kind, 0))


func set_interval_seconds(kind: int, duration_seconds: int) -> bool:
	if not _is_reminder_kind(kind):
		return false
	var safe_duration := clampi(
		duration_seconds,
		MIN_INTERVAL_SECONDS,
		MAX_INTERVAL_SECONDS
	)
	if interval_seconds(kind) == safe_duration:
		return false
	_intervals[kind] = safe_duration
	changed.emit()
	return true


func snooze_seconds() -> int:
	return _snooze_seconds


func set_snooze_seconds(duration_seconds: int) -> bool:
	var safe_duration := clampi(
		duration_seconds,
		MIN_SNOOZE_SECONDS,
		MAX_SNOOZE_SECONDS
	)
	if _snooze_seconds == safe_duration:
		return false
	_snooze_seconds = safe_duration
	changed.emit()
	return true


func quiet_hours_enabled() -> bool:
	return _quiet_enabled


func quiet_start_hour() -> int:
	return _quiet_start_hour


func quiet_end_hour() -> int:
	return _quiet_end_hour


func set_quiet_hours(enabled: bool, start_hour: int, end_hour: int) -> bool:
	var safe_start := clampi(start_hour, 0, 23)
	var safe_end := clampi(end_hour, 0, 23)
	if safe_start == safe_end:
		return false
	if (
		_quiet_enabled == enabled
		and _quiet_start_hour == safe_start
		and _quiet_end_hour == safe_end
	):
		return false
	var was_quiet := is_quiet_now()
	_quiet_enabled = enabled
	_quiet_start_hour = safe_start
	_quiet_end_hour = safe_end
	var quiet_now := is_quiet_now()
	_last_quiet_state = quiet_now
	_next_boundary_check_unix = 0.0
	_update_processing()
	changed.emit()
	if quiet_now != was_quiet:
		quiet_state_changed.emit(quiet_now)
	return true


func is_quiet_now() -> bool:
	if not _quiet_enabled:
		return false
	var hour := _local_hour()
	if _quiet_start_hour < _quiet_end_hour:
		return hour >= _quiet_start_hour and hour < _quiet_end_hour
	return hour >= _quiet_start_hour or hour < _quiet_end_hour


func current_due_kind() -> int:
	for kind in _reminder_kinds():
		if is_due(kind):
			return kind
	return TimerManagerScript.Kind.NONE


func complete_due() -> int:
	return complete_due_kind(current_due_kind())


func complete_due_kind(kind: int) -> int:
	return _reschedule_due_kind(kind, interval_seconds(kind))


func disable_due() -> int:
	return disable_due_kind(current_due_kind())


func disable_due_kind(kind: int) -> int:
	if kind == TimerManagerScript.Kind.NONE:
		return TimerManagerScript.Kind.NONE
	if not is_due(kind):
		return TimerManagerScript.Kind.NONE
	if not set_enabled(kind, false):
		return TimerManagerScript.Kind.NONE
	return kind


func snooze_due(duration_seconds := -1) -> int:
	return snooze_due_kind(current_due_kind(), duration_seconds)


func snooze_due_kind(kind: int, duration_seconds := -1) -> int:
	var duration := (
		_snooze_seconds
		if duration_seconds <= 0
		else duration_seconds
	)
	return _reschedule_due_kind(kind, duration)


func pause_kind_until(kind: int, resume_unix: float) -> int:
	if not is_due(kind) or resume_unix <= _now():
		return TimerManagerScript.Kind.NONE
	_paused_until[kind] = resume_unix
	_timer_for(kind).cancel()
	_update_processing()
	changed.emit()
	return kind


func start_test_reminder(kind: int, duration_seconds: float) -> bool:
	if not _is_reminder_kind(kind) or duration_seconds <= 0.0:
		return false
	_ensure_timers()
	_enabled[kind] = true
	_paused_until[kind] = 0.0
	var started: bool = _timer_for(kind).start_timer(
		kind,
		duration_seconds
	)
	_update_processing()
	changed.emit()
	return started


func snapshot() -> Dictionary:
	_ensure_timers()
	var result := {
		"preferences": {
			"water_interval_seconds": interval_seconds(
				TimerManagerScript.Kind.WATER
			),
			"stand_interval_seconds": interval_seconds(
				TimerManagerScript.Kind.STAND
			),
			"snooze_seconds": _snooze_seconds,
			"quiet_enabled": _quiet_enabled,
			"quiet_start_hour": _quiet_start_hour,
			"quiet_end_hour": _quiet_end_hour,
		},
	}
	for kind in _reminder_kinds():
		result[_snapshot_key(kind)] = {
			"enabled": is_enabled(kind),
			"paused_until": float(_paused_until.get(kind, 0.0)),
			"timer": _timer_for(kind).snapshot(),
		}
	return result


func restore(snapshot_data: Dictionary) -> bool:
	_ensure_timers()
	var preferences = snapshot_data.get("preferences", {})
	if not preferences is Dictionary:
		preferences = {}
	_intervals[TimerManagerScript.Kind.WATER] = clampi(
		int(
			preferences.get(
				"water_interval_seconds",
				WATER_INTERVAL_SECONDS
			)
		),
		MIN_INTERVAL_SECONDS,
		MAX_INTERVAL_SECONDS
	)
	_intervals[TimerManagerScript.Kind.STAND] = clampi(
		int(
			preferences.get(
				"stand_interval_seconds",
				STAND_INTERVAL_SECONDS
			)
		),
		MIN_INTERVAL_SECONDS,
		MAX_INTERVAL_SECONDS
	)
	_snooze_seconds = clampi(
		int(preferences.get("snooze_seconds", SNOOZE_SECONDS)),
		MIN_SNOOZE_SECONDS,
		MAX_SNOOZE_SECONDS
	)
	_quiet_enabled = bool(preferences.get("quiet_enabled", false))
	_quiet_start_hour = clampi(
		int(preferences.get("quiet_start_hour", 22)),
		0,
		23
	)
	_quiet_end_hour = clampi(
		int(preferences.get("quiet_end_hour", 8)),
		0,
		23
	)
	if _quiet_start_hour == _quiet_end_hour:
		_quiet_start_hour = 22
		_quiet_end_hour = 8
	var restored_any := false
	for kind in _reminder_kinds():
		var entry = snapshot_data.get(_snapshot_key(kind), {})
		if not entry is Dictionary:
			entry = {}
		var enabled := bool(entry.get("enabled", false))
		_enabled[kind] = enabled
		_paused_until[kind] = maxf(
			0.0,
			float(entry.get("paused_until", 0.0))
		)
		var timer = _timer_for(kind)
		timer.cancel()
		if not enabled:
			_paused_until[kind] = 0.0
			continue
		restored_any = true
		if float(_paused_until[kind]) > _now():
			continue
		_paused_until[kind] = 0.0
		var timer_snapshot = entry.get("timer", {})
		if (
			timer_snapshot is Dictionary
			and timer.restore(timer_snapshot)
		):
			continue
		timer.start_timer(kind, interval_seconds(kind))
	_last_quiet_state = is_quiet_now()
	_next_boundary_check_unix = 0.0
	_update_processing()
	changed.emit()
	return restored_any


func _reschedule_due_kind(kind: int, duration_seconds: float) -> int:
	if (
		not _is_reminder_kind(kind)
		or not is_due(kind)
		or duration_seconds <= 0.0
	):
		return TimerManagerScript.Kind.NONE
	_paused_until[kind] = 0.0
	_timer_for(kind).start_timer(kind, duration_seconds)
	_update_processing()
	changed.emit()
	return kind


func _ensure_timers() -> void:
	for kind in _reminder_kinds():
		if _timers.has(kind):
			continue
		var timer = TimerManagerScript.new()
		timer.name = "%sReminderTimer" % _snapshot_key(kind).capitalize()
		timer.time_source = time_source
		timer.changed.connect(_handle_timer_changed)
		timer.tick.connect(_handle_timer_tick.bind(kind))
		timer.completed.connect(_handle_timer_completed)
		_timers[kind] = timer
		add_child(timer)


func _timer_for(kind: int):
	if not _timers.has(kind):
		return null
	return _timers[kind]


func _handle_timer_changed() -> void:
	changed.emit()


func _handle_timer_tick(remaining: int, kind: int) -> void:
	tick.emit(kind, remaining)


func _handle_timer_completed(kind: int) -> void:
	if not is_enabled(kind):
		return
	changed.emit()
	reminder_due.emit(kind)


func _reminder_kinds() -> Array[int]:
	return [
		TimerManagerScript.Kind.WATER,
		TimerManagerScript.Kind.STAND,
	]


func _is_reminder_kind(kind: int) -> bool:
	return (
		kind == TimerManagerScript.Kind.WATER
		or kind == TimerManagerScript.Kind.STAND
	)


func _snapshot_key(kind: int) -> String:
	if kind == TimerManagerScript.Kind.WATER:
		return "water"
	if kind == TimerManagerScript.Kind.STAND:
		return "stand"
	return "unknown"


func _update_processing() -> void:
	var has_daily_pause := false
	for kind in _reminder_kinds():
		if is_paused_today(kind):
			has_daily_pause = true
			break
	set_process(has_daily_pause or _quiet_enabled)


func _local_hour() -> int:
	if local_hour_source.is_valid():
		return clampi(int(local_hour_source.call()), 0, 23)
	var local_now := Time.get_datetime_dict_from_system(false)
	return int(local_now.hour)


func _now() -> float:
	if time_source.is_valid():
		return float(time_source.call())
	return Time.get_unix_time_from_system()
