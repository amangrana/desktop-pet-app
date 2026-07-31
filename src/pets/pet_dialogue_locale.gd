class_name PetDialogueLocale
extends Resource

@export var locale_code := "en"
@export var translations: Dictionary = {}


func is_configured() -> bool:
	return not locale_code.strip_edges().is_empty() and not translations.is_empty()


func has_line(line_id: StringName) -> bool:
	return translations.has(str(line_id)) and not line_for_id(line_id).is_empty()


func line_for_id(line_id: StringName) -> String:
	return str(translations.get(str(line_id), "")).strip_edges()


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var display_locale := locale_code.strip_edges()
	if display_locale.is_empty():
		errors.append("Dialogue locale code is empty.")
		display_locale = "unknown"
	if translations.is_empty():
		errors.append("Dialogue locale %s has no translations." % display_locale)
	for raw_line_id in translations:
		var line_id := str(raw_line_id).strip_edges()
		var line := str(translations[raw_line_id]).strip_edges()
		if line_id.is_empty():
			errors.append("Dialogue locale %s has an empty line ID." % display_locale)
		elif line.is_empty():
			errors.append(
				"Dialogue locale %s has an empty value for %s."
				% [display_locale, line_id]
			)
		elif "\n" in line:
			errors.append(
				"Dialogue locale %s line %s must stay on one line."
				% [display_locale, line_id]
			)
		elif line.length() > 96:
			errors.append(
				"Dialogue locale %s line %s exceeds 96 characters."
				% [display_locale, line_id]
			)
	return errors
