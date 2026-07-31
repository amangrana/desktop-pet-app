class_name PetDialogueProfile
extends Resource

const PROFILE_VERSION := "desktop_pet_dialogue_v2"
const DEFAULT_LOCALE := "en"
const LOCALE_DIRECTORY := "dialogue/locales"

const CONTEXT_CLICK := &"click"
const CONTEXT_FOCUS_START := &"focus_start"
const CONTEXT_FOCUS_COMPLETE := &"focus_complete"
const CONTEXT_REMINDER_DONE := &"reminder_done"
const CONTEXT_IDLE := &"idle"

const STANDARD_CONTEXT_ORDER := [
	CONTEXT_CLICK,
	CONTEXT_FOCUS_START,
	CONTEXT_FOCUS_COMPLETE,
	CONTEXT_REMINDER_DONE,
	CONTEXT_IDLE,
]

@export var profile_version := PROFILE_VERSION
@export_range(0.0, 300.0, 1.0) var global_cooldown_seconds := 8.0
@export_range(30.0, 3600.0, 1.0) var idle_interval_min_seconds := 300.0
@export_range(30.0, 3600.0, 1.0) var idle_interval_max_seconds := 480.0
@export var entries: Array[PetDialogueEntry] = []

var _locale_packs: Dictionary = {}
var _locale_scan_errors := PackedStringArray()
var _locales_loaded := false


func is_configured() -> bool:
	return (
		profile_version == PROFILE_VERSION
		and not entries.is_empty()
		and validation_errors().is_empty()
	)


func entry_for_context(context: StringName) -> PetDialogueEntry:
	for entry in entries:
		if entry != null and entry.context == context and entry.is_configured():
			return entry
	return null


func configured_contexts() -> Array[StringName]:
	var contexts: Array[StringName] = []
	for expected_context in STANDARD_CONTEXT_ORDER:
		if entry_for_context(expected_context) != null:
			contexts.append(expected_context)
	for entry in entries:
		if (
			entry != null
			and entry.is_configured()
			and not contexts.has(entry.context)
		):
			contexts.append(entry.context)
	return contexts


func lines_for_context(
	context: StringName,
	language: String
) -> PackedStringArray:
	var entry := entry_for_context(context)
	if entry == null:
		return PackedStringArray()
	var lines := PackedStringArray()
	for line_id in entry.line_ids:
		var line := resolve_line(line_id, language)
		if not line.is_empty():
			lines.append(line)
	return lines


func resolve_line(line_id: StringName, language: String) -> String:
	_ensure_locales_loaded()
	for locale_key in _language_candidates(language):
		var locale_pack: PetDialogueLocale = _locale_packs.get(locale_key)
		if locale_pack != null and locale_pack.has_line(line_id):
			return locale_pack.line_for_id(line_id)
	return ""


func available_locales() -> PackedStringArray:
	_ensure_locales_loaded()
	var result := PackedStringArray()
	for locale_key in _locale_packs:
		result.append(str(locale_key))
	result.sort()
	return result


func reload_locales() -> void:
	_locale_packs.clear()
	_locale_scan_errors.clear()
	_locales_loaded = true
	if resource_path.is_empty():
		_locale_scan_errors.append(
			"Dialogue profile has no resource path for locale discovery."
		)
		return
	var locale_directory := resource_path.get_base_dir().path_join(
		LOCALE_DIRECTORY
	)
	var directory := DirAccess.open(locale_directory)
	if directory == null:
		_locale_scan_errors.append(
			"Dialogue locale directory is missing: %s" % locale_directory
		)
		return
	var files := directory.get_files()
	files.sort()
	for file_name in files:
		var resource_name := str(file_name)
		if resource_name.ends_with(".remap"):
			resource_name = resource_name.trim_suffix(".remap")
		if not (
			resource_name.ends_with(".tres")
			or resource_name.ends_with(".res")
		):
			continue
		var locale_path := locale_directory.path_join(resource_name)
		var loaded_resource := ResourceLoader.load(locale_path)
		if not loaded_resource is PetDialogueLocale:
			continue
		var locale_pack: PetDialogueLocale = loaded_resource
		var locale_key := _normalize_locale(locale_pack.locale_code)
		if locale_key.is_empty():
			_locale_scan_errors.append(
				"Dialogue locale file has no locale code: %s" % locale_path
			)
			continue
		if _locale_packs.has(locale_key):
			_locale_scan_errors.append(
				"Duplicate dialogue locale %s in %s"
				% [locale_pack.locale_code, locale_directory]
			)
			continue
		_locale_packs[locale_key] = locale_pack


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if profile_version != PROFILE_VERSION:
		errors.append(
			"Unsupported dialogue profile version: %s" % profile_version
		)
	if idle_interval_max_seconds < idle_interval_min_seconds:
		errors.append("Dialogue idle interval maximum is below its minimum.")
	var seen_contexts: Dictionary = {}
	var seen_line_ids: Dictionary = {}
	for index in entries.size():
		var entry := entries[index]
		if entry == null:
			errors.append("Dialogue entry %d is empty." % index)
			continue
		if seen_contexts.has(entry.context):
			errors.append("Duplicate dialogue context: %s" % entry.context)
			continue
		seen_contexts[entry.context] = true
		for entry_error in entry.validation_errors():
			errors.append(entry_error)
		for line_id in entry.line_ids:
			if seen_line_ids.has(line_id):
				errors.append("Duplicate dialogue line ID: %s" % line_id)
			else:
				seen_line_ids[line_id] = true
	_ensure_locales_loaded()
	for scan_error in _locale_scan_errors:
		errors.append(scan_error)
	for locale_key in _locale_packs:
		var locale_pack: PetDialogueLocale = _locale_packs[locale_key]
		for locale_error in locale_pack.validation_errors():
			errors.append(locale_error)
	var english_pack: PetDialogueLocale = _locale_packs.get(DEFAULT_LOCALE)
	if english_pack == null:
		errors.append("Dialogue profile has no English fallback locale.")
	else:
		for line_id in seen_line_ids:
			if not english_pack.has_line(line_id):
				errors.append(
					"English dialogue fallback is missing line ID: %s"
					% line_id
				)
	return errors


func _ensure_locales_loaded() -> void:
	if not _locales_loaded:
		reload_locales()


func _language_candidates(language: String) -> PackedStringArray:
	var candidates := PackedStringArray()
	var normalized := _normalize_locale(language)
	if not normalized.is_empty():
		candidates.append(normalized)
		var base_language := normalized.get_slice("_", 0)
		if base_language != normalized:
			candidates.append(base_language)
	if not candidates.has(DEFAULT_LOCALE):
		candidates.append(DEFAULT_LOCALE)
	return candidates


func _normalize_locale(locale_code: String) -> String:
	return locale_code.strip_edges().replace("-", "_").to_lower()
