extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")

const FAKE_NOW := 10_000.0

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	main.daily_briefing_source.time_source = func() -> float:
		return FAKE_NOW
	main.daily_briefing_source.datetime_source = func() -> Dictionary:
		return {
			"year": 2026,
			"month": 7,
			"day": 31,
			"weekday": 5,
			"hour": 9,
			"minute": 30,
			"second": 0,
		}
	main.weather_check_in_source.time_source = func() -> float:
		return FAKE_NOW
	main.settings.language = "en"
	main.settings.ambient_cards_enabled = true
	main.settings.daily_briefing_enabled = true
	main.settings.last_daily_briefing_date = ""
	main.settings.weather_notes_enabled = true
	main.settings.weather_city = "Toronto"
	main.settings.last_weather_note_id = ""
	main.settings.calendar_notes_enabled = true
	main.check_in_manager.set_enabled(true)
	main.check_in_manager.time_source = func() -> float:
		return FAKE_NOW
	main.check_in_manager.set_cooldown_seconds(0)
	main.check_in_manager.remove_source("daily_briefing")
	main.check_in_manager.remove_source("weather")

	var weather := {
		"id": 6167865,
		"name": "Toronto",
		"display_name": "Toronto",
		"requested_city": "Toronto",
		"temperature_c": 18.4,
		"temperature_max_c": 23.1,
		"temperature_min_c": 14.2,
		"weather_code": 2,
		"fetched_unix": Time.get_unix_time_from_system(),
	}
	main.weather_provider.last_weather = weather.duplicate(true)
	var briefing_events: Array[Dictionary] = [{
		"id": "briefing-event",
		"title": "Design review",
		"start_unix": FAKE_NOW + 3 * 60 * 60,
		"end_unix": FAKE_NOW + 4 * 60 * 60,
		"is_all_day": false,
	}]
	main.latest_calendar_events = briefing_events
	main._handle_weather_updated(weather)
	_expect(
		not main.check_in_manager.has_pending(),
		(
			"startup weather must wait for the daily briefing instead "
			+ "of showing a separate card first"
		)
	)
	main.daily_briefing_ready = true
	main._queue_daily_briefing_if_needed(true)
	_expect(
		main.check_in_manager.has_pending(),
		"the first eligible launch of a local day must queue a briefing"
	)
	_expect(
		main._try_show_check_in(),
		"the briefing must use the normal Pet Notes display path"
	)
	await process_frame
	var weather_note_id: String = (
		main.weather_check_in_source.card_id_for(
			weather
		)
	)
	_expect(
		main.notification_label.text
		== (
			"Good morning! Fri, Jul 31.\n"
			+ "Toronto · 18°C · partly cloudy\n"
			+ "Next · Design review · ~3 hr"
		)
		and main.notification_label.text.split("\n").size() == 3
		and main.settings.last_daily_briefing_date == "2026-07-31"
		and main.settings.last_weather_note_id == weather_note_id,
		(
			"showing a briefing must persist the date and included "
			+ "weather bucket while staying within three lines"
		)
	)
	main.notification_done_button.pressed.emit()
	main._queue_daily_briefing_if_needed()
	_expect(
		not main.check_in_manager.has_pending(),
		"the same local date must not queue another briefing"
	)

	var duplicate_weather: Dictionary = (
		main.weather_check_in_source.create_weather_card(weather, false)
	)
	main._handle_pet_note_card_ready(duplicate_weather)
	_expect(
		not main.check_in_manager.has_pending(),
		"a weather bucket included in the briefing must stay seen"
	)

	main.settings.language = "zh_CN"
	main.settings.last_daily_briefing_date = ""
	main._show_daily_briefing_preview()
	await process_frame
	_expect(
		main.notification_label.text
		== (
			"早上好！7月31日，星期五。\n"
			+ "Toronto · 18°C · 多云\n"
			+ "下一项 · Design review · 约3小时后"
		)
		and main.settings.last_daily_briefing_date.is_empty(),
		(
			"the Developer preview must render the Chinese greeting "
			+ "without consuming the daily briefing (actual=%s)"
			% main.notification_label.text
		)
	)
	main.notification_done_button.pressed.emit()
	main.settings.language = "en"
	var long_events: Array[Dictionary] = [{
		"id": "long-briefing-event",
		"title": (
			"Quarterly international product design review and planning"
		),
		"start_unix": FAKE_NOW + 3 * 60 * 60,
		"end_unix": FAKE_NOW + 4 * 60 * 60,
		"is_all_day": false,
	}]
	var long_card: Dictionary = (
		main.daily_briefing_source.create_briefing_card(
			{},
			weather,
			long_events,
			"",
			true
		)
	)
	for scale_value in [1.0, 3.0]:
		var scale_factor := float(scale_value)
		main._apply_scale(scale_factor, false)
		main._show_pet_note_card(long_card)
		await process_frame
		var rendered_lines: PackedStringArray = (
			main.notification_label.text.split(
				"\n",
				false
			)
		)
		var font: Font = main.notification_label.get_theme_font("font")
		var font_size: int = main.notification_label.get_theme_font_size(
			"font_size"
		)
		var width_limit: float = (
			main.DAILY_BRIEFING_TEXT_WIDTH * scale_factor
		)
		var every_line_fits: bool = rendered_lines.size() == 3
		for line in rendered_lines:
			every_line_fits = (
				every_line_fits
				and font.get_string_size(
					line,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1.0,
					font_size
				).x <= width_limit
			)
		_expect(
			every_line_fits
			and str(rendered_lines[-1]).ends_with("…"),
			(
				"long event titles must end with an ellipsis on the "
				+ "third line at %d%% scale"
				% roundi(scale_factor * 100.0)
			)
		)
		main.notification_done_button.pressed.emit()

	main.shutting_down = true
	main.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("Daily briefing integration self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(
		"Daily briefing integration self-test failed: %s" % message
	)
