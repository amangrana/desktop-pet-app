class_name ActivityCenterSessionLog
extends RefCounted

signal changed

const MAX_EVENTS := 5

const FOCUS_STARTED := &"focus_started"
const BREAK_STARTED := &"break_started"
const TIMER_PAUSED := &"timer_paused"
const TIMER_RESUMED := &"timer_resumed"
const TIMER_CANCELLED := &"timer_cancelled"
const FOCUS_COMPLETED := &"focus_completed"
const BREAK_COMPLETED := &"break_completed"
const REMINDER_DUE := &"reminder_due"
const REMINDER_TURNED_ON := &"reminder_turned_on"
const REMINDER_DONE := &"reminder_done"
const REMINDER_SNOOZED := &"reminder_snoozed"
const REMINDER_TURNED_OFF := &"reminder_turned_off"

const _VALID_CODES := [
	FOCUS_STARTED,
	BREAK_STARTED,
	TIMER_PAUSED,
	TIMER_RESUMED,
	TIMER_CANCELLED,
	FOCUS_COMPLETED,
	BREAK_COMPLETED,
	REMINDER_DUE,
	REMINDER_TURNED_ON,
	REMINDER_DONE,
	REMINDER_SNOOZED,
	REMINDER_TURNED_OFF,
]
const _VALID_SUBJECTS := [
	&"focus",
	&"break",
	&"water",
	&"stand",
]

var time_source := Callable()
var _events: Array[Dictionary] = []


func add_event(code: StringName, subject: StringName) -> bool:
	if (
		code not in _VALID_CODES
		or subject not in _VALID_SUBJECTS
		or not _is_valid_pair(code, subject)
	):
		return false
	var clock := _current_clock()
	_events.push_front({
		"code": code,
		"subject": subject,
		"hour": clampi(int(clock.get("hour", 0)), 0, 23),
		"minute": clampi(int(clock.get("minute", 0)), 0, 59),
	})
	if _events.size() > MAX_EVENTS:
		_events.resize(MAX_EVENTS)
	changed.emit()
	return true


func entries() -> Array[Dictionary]:
	return _events.duplicate(true)


func clear() -> bool:
	if _events.is_empty():
		return false
	_events.clear()
	changed.emit()
	return true


func _current_clock() -> Dictionary:
	if time_source.is_valid():
		var supplied = time_source.call()
		if supplied is Dictionary:
			return supplied
	return Time.get_time_dict_from_system()


func _is_valid_pair(code: StringName, subject: StringName) -> bool:
	if code in [
		FOCUS_STARTED,
		FOCUS_COMPLETED,
	]:
		return subject == &"focus"
	if code in [
		BREAK_STARTED,
		BREAK_COMPLETED,
	]:
		return subject == &"break"
	if code in [
		TIMER_PAUSED,
		TIMER_RESUMED,
		TIMER_CANCELLED,
	]:
		return subject == &"focus" or subject == &"break"
	return subject == &"water" or subject == &"stand"
