class_name PetDialogueManager
extends Node

const NEVER_UNIX := -1.0e20

var time_source := Callable()
var profile: PetDialogueProfile
var pet_id := &""

var _enabled := true
var _last_global_unix := NEVER_UNIX
var _last_context_unix: Dictionary = {}
var _last_runtime_lines: Dictionary = {}
var _last_preview_lines: Dictionary = {}
var _next_idle_unix := NEVER_UNIX
var _random := RandomNumberGenerator.new()


func _init() -> void:
	_random.randomize()


func set_profile(
	next_profile: PetDialogueProfile,
	next_pet_id: StringName
) -> void:
	profile = (
		next_profile
		if next_profile != null and next_profile.is_configured()
		else null
	)
	pet_id = next_pet_id
	_last_global_unix = NEVER_UNIX
	_last_context_unix.clear()
	_last_runtime_lines.clear()
	_last_preview_lines.clear()
	_schedule_next_idle()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_next_idle_unix = NEVER_UNIX
	elif _next_idle_unix == NEVER_UNIX:
		_schedule_next_idle()


func is_enabled() -> bool:
	return _enabled


func has_context(context: StringName) -> bool:
	return (
		profile != null
		and profile.entry_for_context(context) != null
	)


func request_line(
	context: StringName,
	language: String,
	force_preview := false
) -> String:
	if (
		(not _enabled and not force_preview)
		or profile == null
		or not profile.is_configured()
	):
		return ""
	var entry := profile.entry_for_context(context)
	if entry == null:
		return ""
	var now := _now()
	if not force_preview:
		if now - _last_global_unix < profile.global_cooldown_seconds:
			return ""
		var last_context_unix := float(
			_last_context_unix.get(context, NEVER_UNIX)
		)
		if now - last_context_unix < entry.cooldown_seconds:
			return ""
	var line_ids := entry.line_ids
	if line_ids.is_empty():
		return ""
	var history := (
		_last_preview_lines if force_preview else _last_runtime_lines
	)
	var last_line_id := StringName(history.get(context, &""))
	var candidates: Array[StringName] = []
	for line_id in line_ids:
		if line_ids.size() == 1 or line_id != last_line_id:
			candidates.append(line_id)
	if candidates.is_empty():
		candidates = line_ids.duplicate()
	var selected_line_id: StringName = (
		candidates[_random.randi_range(0, candidates.size() - 1)]
	)
	var selected := profile.resolve_line(selected_line_id, language)
	if selected.is_empty():
		return ""
	history[context] = selected_line_id
	if not force_preview:
		_last_global_unix = now
		_last_context_unix[context] = now
		if context == PetDialogueProfile.CONTEXT_IDLE:
			_schedule_next_idle()
	return selected


func idle_is_due() -> bool:
	return (
		_enabled
		and has_context(PetDialogueProfile.CONTEXT_IDLE)
		and _next_idle_unix != NEVER_UNIX
		and _now() >= _next_idle_unix
	)


func defer_idle(seconds := 30.0) -> void:
	if profile == null:
		return
	_next_idle_unix = _now() + maxf(1.0, seconds)


func set_random_seed(seed: int) -> void:
	_random.seed = seed


func _schedule_next_idle() -> void:
	if (
		not _enabled
		or profile == null
		or not has_context(PetDialogueProfile.CONTEXT_IDLE)
	):
		_next_idle_unix = NEVER_UNIX
		return
	var minimum := profile.idle_interval_min_seconds
	var maximum := maxf(minimum, profile.idle_interval_max_seconds)
	_next_idle_unix = _now() + _random.randf_range(minimum, maximum)


func _now() -> float:
	if time_source.is_valid():
		return float(time_source.call())
	return Time.get_unix_time_from_system()
