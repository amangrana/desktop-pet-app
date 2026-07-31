class_name CheckInManager
extends Node

signal changed

const PetNoteCardScript := preload(
	"res://src/checkins/pet_note_card.gd"
)

const DEFAULT_DISPLAY_SECONDS := (
	PetNoteCardScript.DEFAULT_DISPLAY_SECONDS
)
const DEFAULT_COOLDOWN_SECONDS := 60 * 60
const MIN_DISPLAY_SECONDS := PetNoteCardScript.MIN_DISPLAY_SECONDS
const MAX_DISPLAY_SECONDS := PetNoteCardScript.MAX_DISPLAY_SECONDS

var time_source := Callable()

var _enabled := false
var _cooldown_seconds := DEFAULT_COOLDOWN_SECONDS
var _next_allowed_unix := 0.0
var _pending_cards: Array[Dictionary] = []
var _seen_ids: Dictionary = {}
var _queue_sequence := 0


func set_enabled(enabled: bool) -> bool:
	if _enabled == enabled:
		return false
	_enabled = enabled
	if not enabled:
		_pending_cards.clear()
	changed.emit()
	return true


func is_enabled() -> bool:
	return _enabled


func set_cooldown_seconds(duration_seconds: int) -> bool:
	var safe_duration := maxi(0, duration_seconds)
	if _cooldown_seconds == safe_duration:
		return false
	_cooldown_seconds = safe_duration
	changed.emit()
	return true


func enqueue_card(
	card_id: String,
	source: String,
	message: String,
	display_seconds := DEFAULT_DISPLAY_SECONDS,
	expires_unix := 0.0
) -> bool:
	return enqueue_card_data({
		"id": card_id,
		"source": source,
		"message": message,
		"display_seconds": display_seconds,
		"expires_unix": expires_unix,
	})


func enqueue_card_data(data: Dictionary) -> bool:
	_prune_expired()
	var card := PetNoteCardScript.normalize(data)
	if card.is_empty():
		return false
	var safe_id := str(card.get("id", ""))
	var expires_unix := float(card.get("expires_unix", 0.0))
	if expires_unix > 0.0 and expires_unix <= _now():
		return false
	if _seen_ids.has(safe_id):
		return false
	for pending_card in _pending_cards:
		if str(pending_card.get("id", "")) == safe_id:
			return false
	_queue_sequence += 1
	card["_queue_sequence"] = _queue_sequence
	_pending_cards.append(card)
	_pending_cards.sort_custom(_card_precedes)
	changed.emit()
	return true


func has_pending() -> bool:
	_prune_expired()
	return not _pending_cards.is_empty()


func take_next(
	ignore_cooldown := false,
	apply_cooldown := true
) -> Dictionary:
	_prune_expired()
	if (
		not _enabled
		or _pending_cards.is_empty()
		or (
			not ignore_cooldown
			and _now() < _next_allowed_unix
		)
	):
		return {}
	var card: Dictionary = _pending_cards.pop_front()
	var card_id := str(card.get("id", ""))
	if not card_id.is_empty():
		_seen_ids[card_id] = true
	if apply_cooldown:
		_next_allowed_unix = _now() + _cooldown_seconds
	changed.emit()
	return card


func clear_cooldown() -> void:
	_next_allowed_unix = 0.0


func remove_source(source: String) -> void:
	var kept_cards: Array[Dictionary] = []
	for card in _pending_cards:
		if str(card.get("source", "")) != source:
			kept_cards.append(card)
	if kept_cards.size() == _pending_cards.size():
		return
	_pending_cards = kept_cards
	changed.emit()


func _prune_expired() -> void:
	var now := _now()
	var kept_cards: Array[Dictionary] = []
	for card in _pending_cards:
		var expires_unix := float(card.get("expires_unix", 0.0))
		if expires_unix <= 0.0 or expires_unix > now:
			kept_cards.append(card)
	if kept_cards.size() == _pending_cards.size():
		return
	_pending_cards = kept_cards
	changed.emit()


func _card_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_priority := int(left.get("priority", 0))
	var right_priority := int(right.get("priority", 0))
	if left_priority != right_priority:
		return left_priority > right_priority
	return (
		int(left.get("_queue_sequence", 0))
		< int(right.get("_queue_sequence", 0))
	)


func _now() -> float:
	if time_source.is_valid():
		return float(time_source.call())
	return Time.get_unix_time_from_system()
