class_name ActivityBatch
extends RefCounted

var keyboard_count: int
var mouse_count: int


func _init(keyboard_events := 0, mouse_events := 0) -> void:
	keyboard_count = maxi(0, keyboard_events)
	mouse_count = maxi(0, mouse_events)


func is_empty() -> bool:
	return keyboard_count == 0 and mouse_count == 0


func total_count() -> int:
	return keyboard_count + mouse_count
