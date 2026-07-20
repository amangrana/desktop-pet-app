class_name CalendarCheckInSource
extends Node

signal event_ready(event_data: Dictionary)

const DEFAULT_LEAD_SECONDS := 60 * 60

var time_source := Callable()
var lead_seconds := DEFAULT_LEAD_SECONDS

var _events: Array[Dictionary] = []
var _emitted_ids: Dictionary = {}


func replace_events(events: Array[Dictionary]) -> void:
	_events = events.duplicate(true)


func poll() -> void:
	var now := _now()
	for event_data in _events:
		var event_id := str(event_data.get("id", "")).strip_edges()
		var title := str(event_data.get("title", "")).strip_edges()
		var start_unix := float(event_data.get("start_unix", 0.0))
		var is_all_day := bool(event_data.get("is_all_day", false))
		var end_unix := float(event_data.get("end_unix", 0.0))
		if (
			event_id.is_empty()
			or title.is_empty()
			or _emitted_ids.has(event_id)
		):
			continue
		var expires_unix := start_unix
		var is_ready := (
			start_unix > now
			and start_unix - now <= lead_seconds
		)
		if is_all_day:
			expires_unix = end_unix
			is_ready = (
				start_unix <= now
				and end_unix > now
			)
		if not is_ready or expires_unix <= now:
			continue
		_emitted_ids[event_id] = true
		var ready_event: Dictionary = event_data.duplicate(true)
		ready_event["expires_unix"] = expires_unix
		event_ready.emit(ready_event)


func _now() -> float:
	if time_source.is_valid():
		return float(time_source.call())
	return Time.get_unix_time_from_system()
