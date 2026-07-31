extends SceneTree

const PetNoteCardScript := preload(
	"res://src/checkins/pet_note_card.gd"
)
const PetNoteSourceScript := preload(
	"res://src/checkins/pet_note_source.gd"
)
const MockWeatherCheckInSourceScript := preload(
	"res://src/checkins/mock_weather_check_in_source.gd"
)
const CalendarCheckInSourceScript := preload(
	"res://src/checkins/calendar_check_in_source.gd"
)
const DailyBriefingSourceScript := preload(
	"res://src/checkins/daily_briefing_source.gd"
)
const CheckInManagerScript := preload(
	"res://src/checkins/check_in_manager.gd"
)

var _fake_now := 10_000.0
var _published_cards: Array[Dictionary] = []
var _calendar_events: Array[Dictionary] = []
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var invalid_card := PetNoteCardScript.normalize({
		"id": "missing-source",
		"message": "No source",
	})
	_expect(
		invalid_card.is_empty(),
		"standard cards must require an id, source, and display content"
	)
	var normalized_card := PetNoteCardScript.normalize({
		"id": "news:1",
		"source": "news",
		"message_key": "news_headline",
		"format_args": ["Example"],
		"display_seconds": 100,
		"priority": 500,
		"action_url": "file:///unsafe",
		"metadata": {"category": "technology"},
	})
	_expect(
		int(normalized_card.get("schema_version", 0))
		== PetNoteCardScript.SCHEMA_VERSION
		and int(normalized_card.get("display_seconds", 0))
		== PetNoteCardScript.MAX_DISPLAY_SECONDS
		and int(normalized_card.get("priority", 0))
		== PetNoteCardScript.PRIORITY_MAX
		and str(normalized_card.get("action_url", "")).is_empty()
		and normalized_card.get("format_args", []) == ["Example"],
		(
			"standard cards must normalize duration, priority, "
			+ "format arguments, metadata, and safe action URLs"
		)
	)

	var source = PetNoteSourceScript.new("news")
	source.card_ready.connect(_published_cards.append)
	root.add_child(source)
	_expect(
		source.publish_card({
			"id": "news:2",
			"message": "A short headline",
		}),
		"a source must fill its configured source id"
	)
	_expect(
		_published_cards.size() == 1
		and _published_cards[0].get("source", "") == "news"
		and not source.publish_card({
			"id": "weather:wrong-source",
			"source": "weather",
			"message": "Wrong source",
		}),
		"a source must publish normalized cards only under its own id"
	)

	var manager = CheckInManagerScript.new()
	manager.time_source = func() -> float: return _fake_now
	manager.set_enabled(true)
	manager.set_cooldown_seconds(60)
	root.add_child(manager)
	manager.enqueue_card(
		"normal-priority",
		"calendar",
		"Normal card",
		10
	)

	var weather_source = MockWeatherCheckInSourceScript.new()
	weather_source.time_source = func() -> float: return _fake_now
	weather_source.card_ready.connect(manager.enqueue_card_data)
	root.add_child(weather_source)
	_expect(
		weather_source.publish_sample(),
		"the mock weather source must publish without network access"
	)
	var weather_card: Dictionary = manager.take_next()
	var localized_messages = weather_card.get("localized_messages", {})
	var metadata = weather_card.get("metadata", {})
	_expect(
		weather_card.get("source", "") == "weather_mock"
		and int(weather_card.get("priority", 0))
		== PetNoteCardScript.PRIORITY_MAX
		and float(weather_card.get("expires_unix", 0.0))
		== _fake_now
		+ MockWeatherCheckInSourceScript.SAMPLE_LIFETIME_SECONDS
		and localized_messages is Dictionary
		and localized_messages.has("en")
		and localized_messages.has("zh_CN")
		and metadata is Dictionary
		and bool(metadata.get("is_mock", false)),
		(
			"mock weather must use the standard bilingual card model "
			+ "and outrank normal queued notes in developer tests"
		)
	)
	_expect(
		weather_source.publish_sample(),
		"the developer source must support repeat previews with unique ids"
	)
	var preview_card: Dictionary = manager.take_next(true, false)
	_expect(
		preview_card.get("source", "") == "weather_mock",
		"developer previews must be able to bypass an active cooldown"
	)
	manager.enqueue_card(
		"after-preview",
		"calendar",
		"Still cooling down",
		10
	)
	_expect(
		manager.take_next().is_empty(),
		(
			"a developer preview must not reset or replace the normal "
			+ "Pet Notes cooldown"
		)
	)

	var calendar_source = CalendarCheckInSourceScript.new()
	calendar_source.time_source = func() -> float: return _fake_now
	calendar_source.card_ready.connect(_published_cards.append)
	calendar_source.event_ready.connect(_calendar_events.append)
	root.add_child(calendar_source)
	calendar_source.replace_events([{
		"id": "calendar-contract",
		"title": "Design review",
		"start_unix": _fake_now + 30 * 60,
		"end_unix": _fake_now + 60 * 60,
		"is_all_day": false,
	}])
	calendar_source.poll()
	var calendar_card: Dictionary = _published_cards[-1]
	_expect(
		_calendar_events.size() == 1
		and calendar_card.get("id", "")
		== "calendar:calendar-contract"
		and calendar_card.get("source", "") == "calendar"
		and calendar_card.get("message_key", "")
		== "calendar_event_card"
		and calendar_card.get("format_args", [])
		== ["Design review", 30],
		(
			"Calendar must implement the common card contract while "
			+ "retaining its compatibility event signal"
		)
	)

	var briefing_source = DailyBriefingSourceScript.new()
	briefing_source.time_source = func() -> float: return _fake_now
	briefing_source.datetime_source = func() -> Dictionary:
		return {
			"year": 2026,
			"month": 7,
			"day": 31,
			"weekday": 5,
			"hour": 9,
			"minute": 30,
			"second": 0,
		}
	briefing_source.card_ready.connect(_published_cards.append)
	root.add_child(briefing_source)
	var briefing_weather := {
		"id": 6167865,
		"name": "Toronto",
		"temperature_c": 18.4,
		"weather_code": 2,
	}
	var briefing_events: Array[Dictionary] = [{
		"id": "briefing-event",
		"title": "Design review",
		"start_unix": _fake_now + 3 * 60 * 60,
		"end_unix": _fake_now + 4 * 60 * 60,
		"is_all_day": false,
	}]
	_expect(
		briefing_source.publish_today(
			briefing_weather,
			briefing_events,
			"weather:6167865:1"
		),
		"the daily briefing source must publish without network access"
	)
	var briefing_card: Dictionary = _published_cards[-1]
	var briefing_messages = briefing_card.get("localized_messages", {})
	var briefing_metadata = briefing_card.get("metadata", {})
	_expect(
		briefing_card.get("id", "")
		== "daily_briefing:2026-07-31"
		and briefing_card.get("source", "") == "daily_briefing"
		and int(briefing_card.get("priority", 0)) == -5
		and briefing_source.today_key() == "2026-07-31"
		and briefing_messages.get("en", "")
		== (
			"Good morning! Fri, Jul 31.\n"
			+ "Toronto · 18°C · partly cloudy\n"
			+ "Next · Design review · ~3 hr"
		)
		and briefing_messages.get("zh_CN", "")
		== (
			"早上好！7月31日，星期五。\n"
			+ "Toronto · 18°C · 多云\n"
			+ "下一项 · Design review · 约3小时后"
		)
		and briefing_metadata.get("date_key", "")
		== "2026-07-31"
		and bool(briefing_metadata.get("includes_weather", false))
		and briefing_metadata.get("weather_note_id", "")
		== "weather:6167865:1"
		and not bool(briefing_metadata.get("is_preview", true))
		and float(briefing_card.get("expires_unix", 0.0))
		== _fake_now + 14.5 * 60 * 60,
		(
			"daily briefings must stay within three bilingual lines, "
			+ "include a compact greeting, and expire at day end"
		)
	)
	var briefing_preview := briefing_source.create_briefing_card(
		{},
		briefing_weather,
		briefing_events,
		"",
		true
	)
	_expect(
		str(briefing_preview.get("id", "")).begins_with(
			"daily_briefing:2026-07-31:preview:"
		)
		and bool(
			briefing_preview.get("metadata", {}).get(
				"is_preview",
				false
			)
		),
		"developer briefing previews must use a unique card id"
	)
	var afternoon_datetime: Dictionary = {
		"year": 2026,
		"month": 7,
		"day": 31,
		"weekday": 5,
		"hour": 14,
		"minute": 0,
		"second": 0,
	}
	var evening_datetime := afternoon_datetime.duplicate(true)
	evening_datetime.hour = 20
	var afternoon_card := briefing_source.create_briefing_card(
		afternoon_datetime
	)
	var evening_card := briefing_source.create_briefing_card(
		evening_datetime
	)
	_expect(
		afternoon_card.get("localized_messages", {}).get("en", "")
		== "Good afternoon! Fri, Jul 31."
		and afternoon_card.get("localized_messages", {}).get(
			"zh_CN",
			""
		) == "下午好！7月31日，星期五。"
		and evening_card.get("localized_messages", {}).get("en", "")
		== "Good evening! Fri, Jul 31."
		and evening_card.get("localized_messages", {}).get(
			"zh_CN",
			""
		) == "晚上好！7月31日，星期五。",
		"briefing greetings must follow the local time of day"
	)

	if _failed:
		quit(1)
		return
	print("Pet Note source contract self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Pet Note source contract self-test failed: %s" % message)
