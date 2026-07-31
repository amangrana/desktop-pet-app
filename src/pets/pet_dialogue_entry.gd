class_name PetDialogueEntry
extends Resource

@export var context: StringName
@export var line_ids: Array[StringName] = []
@export_range(0.0, 3600.0, 1.0) var cooldown_seconds := 30.0


func is_configured() -> bool:
	return not context.is_empty() and not line_ids.is_empty()


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if context.is_empty():
		errors.append("Dialogue context is empty.")
	if line_ids.is_empty():
		errors.append("Dialogue context %s has no line IDs." % context)
	var seen_ids: Dictionary = {}
	for index in line_ids.size():
		var line_id := str(line_ids[index]).strip_edges()
		if line_id.is_empty():
			errors.append("Dialogue line ID %d in %s is empty." % [index, context])
		elif seen_ids.has(line_id):
			errors.append("Duplicate dialogue line ID in %s: %s" % [context, line_id])
		else:
			seen_ids[line_id] = true
	return errors
