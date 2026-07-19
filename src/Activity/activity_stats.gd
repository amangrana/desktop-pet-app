class_name ActivityStats
extends RefCounted

signal changed

var keyboard_count := 0
var mouse_count := 0


func record(batch) -> void:
	if batch == null or batch.is_empty():
		return

	keyboard_count += batch.keyboard_count
	mouse_count += batch.mouse_count
	changed.emit()


func clear() -> void:
	if keyboard_count == 0 and mouse_count == 0:
		return

	keyboard_count = 0
	mouse_count = 0
	changed.emit()


func is_empty() -> bool:
	return keyboard_count == 0 and mouse_count == 0


func summary() -> String:
	return "Session activity: keyboard %d | mouse %d" % [
		keyboard_count,
		mouse_count,
	]
