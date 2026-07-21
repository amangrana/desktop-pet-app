extends SceneTree

const SessionLogScript := preload(
	"res://src/Activity/activity_center_session_log.gd"
)

var _failed := false
var _changed_count := 0


func _initialize() -> void:
	var log = SessionLogScript.new()
	log.time_source = (
		func() -> Dictionary: return {"hour": 14, "minute": 5}
	)
	log.changed.connect(func() -> void: _changed_count += 1)

	_expect(
		not log.add_event(&"keyboard_pressed", &"focus")
		and not log.add_event(SessionLogScript.FOCUS_STARTED, &"mouse")
		and not log.add_event(
			SessionLogScript.REMINDER_DUE,
			&"focus"
		),
		(
			"session log must reject raw-input-like, unknown, or "
			+ "mismatched event data"
		)
	)

	for index in 7:
		var code := (
			SessionLogScript.FOCUS_STARTED
			if index % 2 == 0
			else SessionLogScript.TIMER_PAUSED
		)
		_expect(
			log.add_event(code, &"focus"),
			"whitelisted timer events must be accepted"
		)

	var entries: Array[Dictionary] = log.entries()
	_expect(
		entries.size() == SessionLogScript.MAX_EVENTS
		and int(entries[0].hour) == 14
		and int(entries[0].minute) == 5
		and not entries[0].has("key")
		and not entries[0].has("coordinates")
		and not entries[0].has("application"),
		(
			"session log must keep only the bounded structured event "
			+ "fields"
		)
	)
	entries[0]["code"] = &"tampered"
	_expect(
		log.entries()[0].code != &"tampered",
		"callers must receive a deep copy of session events"
	)
	_expect(
		log.clear()
		and log.entries().is_empty()
		and not log.clear()
		and _changed_count == 8,
		"clear must emit once and remain a no-op when already empty"
	)

	if _failed:
		quit(1)
		return
	print("Activity Center session log self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Activity Center session log test failed: %s" % message)
