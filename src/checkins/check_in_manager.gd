class_name CheckInManager
extends Node

signal changed

const DEFAULT_DISPLAY_SECONDS := 10
const DEFAULT_COOLDOWN_SECONDS := 60 * 60
const MIN_DISPLAY_SECONDS := 5
const MAX_DISPLAY_SECONDS := 30

var time_source := Callable()

var _enabled := false
var _cooldown_seconds := DEFAULT_COOLDOWN_SECONDS
var _next_allowed_unix := 0.0
var _pending_cards: Array[Dictionary] = []
var _seen_ids: Dictionary = {}


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
	_prune_expired()
	var safe_id := card_id.strip_edges()
	var safe_message := message.strip_edges()
	if safe_id.is_empty() or safe_message.is_empty():
		return false
	if expires_unix > 0.0 and expires_unix <= _now():
		return false
	if _seen_ids.has(safe_id):
		return false
	for pending_card in _pending_cards:
		if str(pending_card.get("id", "")) == safe_id:
			return false
	_pending_cards.append({
		"id": safe_id,
		"source": source,
		"message": safe_message,
		"display_seconds": clampi(
			display_seconds,
			MIN_DISPLAY_SECONDS,
			MAX_DISPLAY_SECONDS
		),
		"expires_unix": expires_unix,
	})
	changed.emit()
	return true


func has_pending() -> bool:
	_prune_expired()
	return not _pending_cards.is_empty()


func take_next() -> Dictionary:
	_prune_expired()
	if (
		not _enabled
		or _pending_cards.is_empty()
		or _now() < _next_allowed_unix
	):
		return {}
	var card: Dictionary = _pending_cards.pop_front()
	var card_id := str(card.get("id", ""))
	if not card_id.is_empty():
		_seen_ids[card_id] = true
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


func _now() -> float:
	if time_source.is_valid():
		return float(time_source.call())
	return Time.get_unix_time_from_system()
