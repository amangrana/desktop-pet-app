class_name PetNoteCard
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULT_DISPLAY_SECONDS := 10
const MIN_DISPLAY_SECONDS := 5
const MAX_DISPLAY_SECONDS := 30
const PRIORITY_MIN := -100
const PRIORITY_NORMAL := 0
const PRIORITY_MAX := 100


static func normalize(data: Dictionary) -> Dictionary:
	var card_id := str(data.get("id", "")).strip_edges()
	var source := str(data.get("source", "")).strip_edges()
	var message := str(data.get("message", "")).strip_edges()
	var message_key := str(data.get("message_key", "")).strip_edges()
	var localized_messages := _normalize_localized_messages(
		data.get("localized_messages", {})
	)
	if (
		card_id.is_empty()
		or source.is_empty()
		or (
			message.is_empty()
			and message_key.is_empty()
			and localized_messages.is_empty()
		)
	):
		return {}
	var expires_unix := float(data.get("expires_unix", 0.0))
	var format_args: Array = []
	var raw_format_args = data.get("format_args", [])
	if raw_format_args is Array:
		format_args = raw_format_args.duplicate(true)
	var metadata: Dictionary = {}
	var raw_metadata = data.get("metadata", {})
	if raw_metadata is Dictionary:
		metadata = raw_metadata.duplicate(true)
	return {
		"schema_version": SCHEMA_VERSION,
		"id": card_id,
		"source": source,
		"title": str(data.get("title", "")).strip_edges(),
		"message": message,
		"message_key": message_key,
		"format_args": format_args,
		"localized_messages": localized_messages,
		"display_seconds": clampi(
			int(
				data.get(
					"display_seconds",
					DEFAULT_DISPLAY_SECONDS
				)
			),
			MIN_DISPLAY_SECONDS,
			MAX_DISPLAY_SECONDS
		),
		"expires_unix": expires_unix,
		"priority": clampi(
			int(data.get("priority", PRIORITY_NORMAL)),
			PRIORITY_MIN,
			PRIORITY_MAX
		),
		"action_url": _normalize_action_url(
			str(data.get("action_url", ""))
		),
		"metadata": metadata,
	}


static func _normalize_localized_messages(value) -> Dictionary:
	if not value is Dictionary:
		return {}
	var normalized := {}
	for locale in value:
		var locale_code := str(locale).strip_edges()
		var localized_message := str(value[locale]).strip_edges()
		if locale_code.is_empty() or localized_message.is_empty():
			continue
		normalized[locale_code] = localized_message
	return normalized


static func _normalize_action_url(value: String) -> String:
	var url := value.strip_edges()
	if url.begins_with("https://") or url.begins_with("http://"):
		return url
	return ""
