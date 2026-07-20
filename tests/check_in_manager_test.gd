extends SceneTree

const CheckInManagerScript := preload(
	"res://src/checkins/check_in_manager.gd"
)
const CalendarCheckInSourceScript := preload(
	"res://src/checkins/calendar_check_in_source.gd"
)

var _fake_now := 1000.0
var _calendar_events: Array[Dictionary] = []
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manager = CheckInManagerScript.new()
	manager.time_source = func() -> float: return _fake_now
	manager.set_cooldown_seconds(60)
	root.add_child(manager)

	_expect(
		manager.enqueue_card("card-1", "calendar", "Upcoming event", 10),
		"a valid card must enter the pending queue"
	)
	_expect(
		manager.take_next().is_empty(),
		"cards must not surface while the feature is disabled"
	)
	manager.set_enabled(true)
	var first_card: Dictionary = manager.take_next()
	_expect(
		first_card.get("message", "") == "Upcoming event"
		and int(first_card.get("display_seconds", 0)) == 10,
		"enabling must allow the first pending card to surface"
	)
	_expect(
		not manager.enqueue_card(
			"card-1",
			"calendar",
			"Duplicate event",
			10
		),
		"the same source card must not surface twice"
	)
	manager.enqueue_card("card-2", "calendar", "Another event", 100)
	_expect(
		manager.take_next().is_empty(),
		"cooldown must keep consecutive cards from appearing"
	)
	_fake_now += 60.0
	var second_card: Dictionary = manager.take_next()
	_expect(
		int(second_card.get("display_seconds", 0))
		== CheckInManagerScript.MAX_DISPLAY_SECONDS,
		"display duration must stay within the passive-card limit"
	)

	var calendar_source = CalendarCheckInSourceScript.new()
	calendar_source.time_source = func() -> float: return _fake_now
	calendar_source.event_ready.connect(_calendar_events.append)
	root.add_child(calendar_source)
	var upcoming_events: Array[Dictionary] = [{
		"id": "event-1",
		"title": "Design review",
		"start_unix": _fake_now + 90 * 60,
		"is_all_day": false,
	}]
	calendar_source.replace_events(upcoming_events)
	calendar_source.poll()
	_expect(
		_calendar_events.is_empty(),
		"timed events more than one hour away must stay quiet"
	)
	_fake_now += 30 * 60
	calendar_source.poll()
	calendar_source.poll()
	_expect(
		_calendar_events.size() == 1
		and _calendar_events[0].get("title", "") == "Design review"
		and float(_calendar_events[0].get("expires_unix", 0.0))
		== float(upcoming_events[0].start_unix),
		(
			"timed event must emit once at the one-hour boundary "
			+ "and expire when it starts"
		)
	)

	var all_day_end := _fake_now + 12 * 60 * 60
	var current_day_events: Array[Dictionary] = [{
		"id": "event-day",
		"title": "Company holiday",
		"start_unix": _fake_now - 6 * 60 * 60,
		"end_unix": all_day_end,
		"is_all_day": true,
	}]
	calendar_source.replace_events(current_day_events)
	calendar_source.poll()
	calendar_source.poll()
	_expect(
		_calendar_events.size() == 2
		and _calendar_events[1].get("title", "") == "Company holiday"
		and float(_calendar_events[1].get("expires_unix", 0.0))
		== all_day_end,
		(
			"an all-day event active at startup must emit once "
			+ "and expire at the date boundary"
		)
	)

	manager.clear_cooldown()
	manager.enqueue_card(
		"expiring-card",
		"calendar",
		"Event has not started yet",
		10,
		_fake_now + 10.0
	)
	_expect(manager.has_pending(), "an unexpired calendar card must queue")
	_fake_now += 10.1
	_expect(
		not manager.has_pending(),
		"calendar card must leave the queue when its event starts"
	)

	manager.enqueue_card("card-3", "news", "Old news", 10)
	manager.set_enabled(false)
	manager.set_enabled(true)
	manager.clear_cooldown()
	_expect(
		manager.take_next().is_empty(),
		"turning passive cards off must clear pending content"
	)

	if _failed:
		quit(1)
		return
	print("Check-in manager self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Check-in manager self-test failed: %s" % message)
