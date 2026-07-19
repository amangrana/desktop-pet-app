class_name InputActivityMonitor
extends Node

const ActivityBatchScript := preload("res://src/Activity/activity_batch.gd")

signal activity_batch_ready(batch)
signal listening_changed(enabled: bool)

@export_range(0.05, 1.0, 0.01)
var flush_interval_seconds := 0.10

var listening := false
var _keyboard_pending := 0
var _mouse_pending := 0
var _flush_remaining := 0.0


func _ready() -> void:
	set_process(listening)


func _process(delta: float) -> void:
	_flush_remaining -= delta
	if _flush_remaining > 0.0:
		return

	_flush_remaining = flush_interval_seconds
	_flush_pending_activity()


func set_listening(enabled: bool) -> void:
	if listening == enabled:
		return

	listening = enabled
	_clear_pending_activity()
	_flush_remaining = flush_interval_seconds
	set_process(enabled)
	listening_changed.emit(enabled)


func submit_aggregate(keyboard_events: int, mouse_events: int) -> void:
	if not listening:
		return

	_keyboard_pending += maxi(0, keyboard_events)
	_mouse_pending += maxi(0, mouse_events)


func _flush_pending_activity() -> void:
	var batch = ActivityBatchScript.new(_keyboard_pending, _mouse_pending)
	_clear_pending_activity()
	if not batch.is_empty():
		activity_batch_ready.emit(batch)


func _clear_pending_activity() -> void:
	_keyboard_pending = 0
	_mouse_pending = 0
