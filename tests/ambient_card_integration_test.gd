extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const TimerManagerScript := preload("res://src/timers/timer_manager.gd")

const AMBIENT_CARDS_MENU_ID := 59
const WEATHER_NOW_MENU_ID := 19
const DEV_AMBIENT_CARD_MENU_ID := 64
const DEV_WEATHER_CARD_MENU_ID := 66
const DEV_DAILY_BRIEFING_MENU_ID := 67

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	_expect(
		not main.settings.ambient_cards_enabled
		and main.settings_menu.get_item_index(AMBIENT_CARDS_MENU_ID) >= 0,
		"pet info cards must be optional and off by default"
	)
	_expect(
		main.developer_menu.get_item_index(DEV_AMBIENT_CARD_MENU_ID) >= 0,
		"developer menu must expose a passive-card test entry"
	)
	_expect(
		main.developer_menu.get_item_index(DEV_WEATHER_CARD_MENU_ID) >= 0,
		"developer menu must expose a mock weather source test entry"
	)
	_expect(
		main.developer_menu.get_item_index(
			DEV_DAILY_BRIEFING_MENU_ID
		) >= 0,
		"developer menu must expose a daily briefing test entry"
	)
	_expect(
		main.activity_menu.get_item_index(WEATHER_NOW_MENU_ID) >= 0,
		"Activity menu must expose a manual Weather now entry"
	)
	main._handle_menu_item(WEATHER_NOW_MENU_ID)
	await process_frame
	_expect(
		main.pet_notes_settings_window.visible
		and main.weather_city_edit.editable,
		(
			"Weather now without a configured city must open settings "
			+ "with manual city entry available"
		)
	)
	main.pet_notes_settings_window.hide()

	main._handle_menu_item(AMBIENT_CARDS_MENU_ID)
	await process_frame
	_expect(
		main.pet_notes_settings_window.visible,
		"Pet Notes menu must open its dedicated settings window"
	)
	_expect(
		main.pet_notes_settings_window.size == Vector2i(440, 515)
		and main.pet_notes_background.color == Color("#2B2434")
		and main.pet_notes_master_card.has_theme_stylebox_override(
			"panel"
		)
		and main.pet_notes_daily_briefing_card.has_theme_stylebox_override(
			"panel"
		)
		and main.pet_notes_calendar_card.has_theme_stylebox_override(
			"panel"
		)
		and main.pet_notes_weather_card.has_theme_stylebox_override(
			"panel"
		)
		and not main.pet_notes_scroll.get_v_scroll_bar().visible,
		(
			"Pet Notes settings must use the compact card layout "
			+ "(body_min=%s scroll=%s)"
			% [
				main.pet_notes_scroll_content.get_combined_minimum_size(),
				main.pet_notes_scroll.size,
			]
		)
	)
	main.google_calendar_provider._set_state(
		main.GoogleCalendarProviderScript.State.ERROR,
		"client_secret_missing"
	)
	await process_frame
	await process_frame
	var save_button_rect: Rect2 = (
		main.pet_notes_save_button.get_global_rect()
	)
	var cancel_button_rect: Rect2 = (
		main.pet_notes_cancel_button.get_global_rect()
	)
	_expect(
		save_button_rect.end.y
		<= main.pet_notes_settings_window.size.y - 10
		and cancel_button_rect.end.y
		<= main.pet_notes_settings_window.size.y - 10
		and main.pet_notes_save_button.size.y >= 30
		and main.pet_notes_cancel_button.size.y >= 30,
		(
			"long Calendar errors must grow Pet Notes while keeping "
			+ "Save and Cancel fully visible "
			+ "(window=%s save=%s cancel=%s)"
			% [
				main.pet_notes_settings_window.size,
				save_button_rect,
				cancel_button_rect,
			]
		)
	)
	main.google_calendar_status_label.text = (
		main.google_calendar_status_label.text
		+ " "
		+ "Additional diagnostic details ".repeat(12)
	)
	main._queue_pet_notes_window_resize()
	await process_frame
	await process_frame
	_expect(
		main.pet_notes_settings_window.size.y > 515
		and main.pet_notes_settings_window.size.y <= 680,
		(
			"Pet Notes must grow within its height cap when status "
			+ "content needs substantially more lines "
			+ "(window=%s measured=%s baseline=%s label_width=%s)"
			% [
				main.pet_notes_settings_window.size,
				main._wrapped_label_height(
					main.google_calendar_status_label,
					34,
					356
				),
				main.pet_notes_base_status_height,
				main.google_calendar_status_label.size.x,
			]
		)
	)
	main.google_calendar_status_label.text += (
		"More diagnostic context ".repeat(60)
	)
	main._queue_pet_notes_window_resize()
	await process_frame
	await process_frame
	save_button_rect = main.pet_notes_save_button.get_global_rect()
	cancel_button_rect = main.pet_notes_cancel_button.get_global_rect()
	_expect(
		main.pet_notes_settings_window.size.y == 680
		and main.pet_notes_scroll.get_v_scroll_bar().visible
		and save_button_rect.end.y
		<= main.pet_notes_settings_window.size.y - 10
		and cancel_button_rect.end.y
		<= main.pet_notes_settings_window.size.y - 10,
		(
			"overflowing Pet Notes content must scroll at the height "
			+ "cap without moving the footer buttons out of view"
		)
	)
	main.google_calendar_provider._set_state(
		main.GoogleCalendarProviderScript.State.DISCONNECTED,
		""
	)
	await process_frame
	await process_frame
	_expect(
		main.pet_notes_settings_window.size == Vector2i(440, 515),
		"Pet Notes must shrink back after the long status is cleared"
	)
	_expect(
		main.pet_notes_enabled_check.has_theme_icon_override("unchecked")
		and main.pet_notes_enabled_check.has_theme_icon_override("checked")
		and main.daily_briefing_enabled_check.has_theme_icon_override(
			"unchecked"
		)
		and main.daily_briefing_enabled_check.has_theme_icon_override(
			"checked"
		)
		and main.calendar_notes_enabled_check.has_theme_icon_override(
			"unchecked"
		)
		and main.calendar_notes_enabled_check.has_theme_icon_override(
			"checked"
		)
		and main.weather_notes_enabled_check.has_theme_icon_override(
			"unchecked"
		)
		and main.weather_notes_enabled_check.has_theme_icon_override(
			"checked"
		),
		"Pet Notes checkboxes must use visible high-contrast icons"
	)
	var unchecked_icon: Texture2D = (
		main.pet_notes_enabled_check.get_theme_icon("unchecked")
	)
	var checked_icon: Texture2D = (
		main.pet_notes_enabled_check.get_theme_icon("checked")
	)
	_expect(
		unchecked_icon != null
		and checked_icon != null
		and unchecked_icon.get_size() == Vector2(24, 24)
		and checked_icon.get_size() == Vector2(24, 24),
		(
			"Pet Notes checkbox icons must contain their imported pixels, "
			+ "including in exported PCK builds"
		)
	)
	_expect(
		main.pet_notes_enabled_check.get_theme_color("font_color")
		== Color.WHITE
		and main.pet_notes_enabled_check.get_theme_color(
			"font_outline_color"
		) == Color("#352B42")
		and main.pet_notes_enabled_check.get_theme_constant(
			"outline_size"
		) >= 3,
		"Pet Notes checkbox text must remain readable on dark backgrounds"
	)
	main.pet_notes_enabled_check.button_pressed = false
	_expect(
		main.daily_briefing_enabled_check.disabled
		and main.pet_notes_daily_briefing_card.modulate.a < 1.0
		and main.calendar_notes_enabled_check.disabled
		and main.google_calendar_connect_button.disabled
		and main.pet_notes_calendar_card.modulate.a < 1.0
		and main.weather_notes_enabled_check.disabled
		and main.weather_city_edit.editable
		and main.weather_refresh_button.disabled
		and main.pet_notes_weather_card.modulate == Color.WHITE,
		(
			"disabling Pet Notes must disable automatic sources while "
			+ "keeping manual weather configuration available"
		)
	)
	main.weather_city_edit.text = "Toronto"
	main._refresh_weather_status()
	_expect(
		main.weather_city_edit.editable
		and not main.weather_refresh_button.disabled,
		(
			"manual city and Check now must remain available when "
			+ "automatic Pet Notes are disabled"
		)
	)
	main.pet_notes_enabled_check.button_pressed = true
	_expect(
		not main.daily_briefing_enabled_check.disabled
		and main.pet_notes_daily_briefing_card.modulate == Color.WHITE
		and not main.calendar_notes_enabled_check.disabled
		and not main.google_calendar_connect_button.disabled
		and main.pet_notes_calendar_card.modulate == Color.WHITE
		and not main.weather_notes_enabled_check.disabled
		and main.pet_notes_weather_card.modulate == Color.WHITE,
		(
			"re-enabling Pet Notes must restore available source "
			+ "controls according to account state"
		)
	)
	main.weather_notes_enabled_check.button_pressed = true
	main.weather_city_edit.text = "Toronto"
	main._refresh_weather_status()
	_expect(
		main.weather_city_edit.editable
		and not main.weather_refresh_button.disabled
		and "Open-Meteo" in main.weather_attribution_link.text,
		(
			"automatic weather settings must expose an editable city, "
			+ "a Check now test entry, and provider attribution"
			+ " (editable=%s disabled=%s attribution=%s state=%s city=%s)"
			% [
				main.weather_city_edit.editable,
				main.weather_refresh_button.disabled,
				main.weather_attribution_link.text,
				main.weather_provider.state,
				main.weather_city_edit.text,
			]
		)
	)
	main.weather_notes_enabled_check.button_pressed = false
	main.daily_briefing_enabled_check.button_pressed = false
	main.calendar_notes_enabled_check.button_pressed = true
	main.pet_notes_save_button.pressed.emit()
	main.check_in_manager.set_cooldown_seconds(0)
	var calendar_now := Time.get_unix_time_from_system()
	main.calendar_check_in_source.time_source = (
		func() -> float: return calendar_now
	)
	var integration_calendar_events: Array[Dictionary] = [{
		"id": "integration-calendar-contract",
		"title": "Design review",
		"start_unix": calendar_now + 30 * 60,
		"end_unix": calendar_now + 60 * 60,
		"is_all_day": false,
	}]
	main.calendar_check_in_source.replace_events(
		integration_calendar_events
	)
	main.calendar_check_in_source.poll()
	_expect(
		main._try_show_check_in(),
		"Calendar source cards must enter the common Pet Notes queue"
	)
	await process_frame
	_expect(
		main.notification_label.text
		== main._text(
			"calendar_event_card",
			["Design review", 30]
		),
		(
			"Calendar cards must resolve their message key in the "
			+ "current interface language"
		)
	)
	main.notification_done_button.pressed.emit()

	main.check_in_manager.enqueue_card(
		"integration-1",
		"calendar",
		"Design review starts soon.",
		10
	)
	var first_card_started: bool = main._try_show_check_in()
	await process_frame
	_expect(
		first_card_started,
		"an eligible non-focus card must appear"
	)
	_expect(
		main.ambient_card_active
		and main.notification_panel.visible
		and main.notification_actions.visible
		and main.notification_done_button.visible
		and not main.notification_snooze_button.visible
		and not main.notification_stop_button.visible
		and main.notification_done_button.text == "OK (10)",
		"passive card must show only an OK button with countdown"
	)
	_expect(
		main.notification_panel.size == Vector2(264, 102),
		(
			"the first Pet Note must use its final actionable layout; "
			+ "actual size is %s"
			% main.notification_panel.size
		)
	)
	_expect(
		main.notification_panel.mouse_filter == Control.MOUSE_FILTER_STOP
		and Geometry2D.is_point_in_polygon(
			main.notification_panel.position
			+ main.notification_panel.size / 2.0,
			main.get_window().mouse_passthrough_polygon
		),
		"passive card and its button must accept mouse input"
	)
	main.notification_done_button.pressed.emit()
	_expect(
		not main.ambient_card_active
		and not main.notification_panel.visible,
		"OK must close the passive card immediately"
	)

	main.check_in_manager.enqueue_card(
		"integration-long",
		"calendar",
		(
			"A very long calendar title and description that keeps "
			+ "going so the passive note needs several wrapped lines "
			+ "without ever pushing its countdown button outside the "
			+ "fixed pet bubble."
		),
		10
	)
	main._try_show_check_in()
	await process_frame
	var ambient_button_rect: Rect2 = (
		main.notification_done_button.get_global_rect()
	)
	var ambient_panel_rect := Rect2(
		main.notification_panel.position,
		main.notification_panel.size
	)
	_expect(
		main.notification_label.max_lines_visible == 3
		and main.notification_label.text_overrun_behavior
		== TextServer.OVERRUN_TRIM_ELLIPSIS
		and ambient_panel_rect.encloses(ambient_button_rect),
		(
			"long passive notes must trim to three lines while keeping "
			+ "the countdown button inside the bubble"
		)
	)
	main.notification_done_button.pressed.emit()

	main.check_in_manager.enqueue_card(
		"integration-2",
		"calendar",
		"Planning starts soon.",
		10
	)
	main._try_show_check_in()
	main.ambient_card_deadline_unix = (
		Time.get_unix_time_from_system() - 0.1
	)
	main._handle_ambient_card_tick()
	_expect(
		not main.ambient_card_active
		and not main.notification_panel.visible,
		"countdown reaching zero must dismiss the card automatically"
	)

	main.check_in_manager.enqueue_card(
		"integration-3",
		"calendar",
		"Focus should defer this card.",
		10
	)
	main._start_timer(TimerManagerScript.Kind.FOCUS, 30)
	_expect(
		not main._try_show_check_in()
		and not main.notification_panel.visible,
		"focus time must suppress passive cards"
	)
	main.timer_manager.cancel()
	var deferred_card_started: bool = main._try_show_check_in()
	await process_frame
	_expect(
		deferred_card_started and main.ambient_card_active,
		"a deferred card may appear after focus ends"
	)
	main._start_timer(TimerManagerScript.Kind.FOCUS, 30)
	_expect(
		not main.ambient_card_active
		and not main.notification_panel.visible,
		"starting focus must close a visible passive card"
	)
	main.timer_manager.cancel()

	main.settings.weather_notes_enabled = true
	main.settings.weather_city = "Toronto"
	main._handle_weather_updated({
		"id": 6167865,
		"name": "Toronto",
		"display_name": "Toronto, Ontario, Canada",
		"temperature_c": 18.4,
		"temperature_max_c": 23.1,
		"temperature_min_c": 14.2,
		"weather_code": 2,
		"fetched_unix": Time.get_unix_time_from_system(),
	})
	await process_frame
	_expect(
		main.ambient_card_active
		and "18°C" in main.notification_label.text
		and "Open-Meteo" in main.notification_label.text,
		(
			"a successful live-weather payload must travel through the "
			+ "standard source and display an attributed Pet Note"
		)
	)
	_expect(
		not main.settings.weather_snapshot.has("latitude")
		and not main.settings.weather_snapshot.has("longitude")
		and main.settings.weather_snapshot.get("id", 0) == 6167865,
		(
			"the offline weather cache must retain display data without "
			+ "persisting derived precise coordinates"
		)
	)
	main.notification_done_button.pressed.emit()

	main._handle_menu_item(AMBIENT_CARDS_MENU_ID)
	await process_frame
	main.pet_notes_enabled_check.button_pressed = false
	main.calendar_notes_enabled_check.button_pressed = false
	main.weather_notes_enabled_check.button_pressed = false
	main.pet_notes_save_button.pressed.emit()
	_expect(
		not main.settings.ambient_cards_enabled
		and not main.check_in_manager.is_enabled(),
		"turning pet info cards off must disable the source pipeline"
	)

	main._handle_menu_item(DEV_WEATHER_CARD_MENU_ID)
	await process_frame
	var expected_weather_message := (
		"多伦多：18°C，多云间晴。出门可以带件薄外套。"
		if main.settings.language == "zh_CN"
		else (
			"Toronto: 18°C and partly cloudy. "
			+ "A light jacket may help."
		)
	)
	_expect(
		main.ambient_card_active
		and main.notification_label.text == expected_weather_message
		and not main.check_in_manager.is_enabled(),
		(
			"the mock weather developer entry must travel through the "
			+ "source and queue contract, localize, and restore the "
			+ "disabled Pet Notes state"
		)
	)
	main.notification_done_button.pressed.emit()

	var active_weather := {
		"id": 6167865,
		"name": "Toronto",
		"display_name": "Toronto, Ontario, Canada",
		"temperature_c": 18.4,
		"temperature_max_c": 23.1,
		"temperature_min_c": 14.2,
		"weather_code": 2,
		"requested_city": "Toronto",
		"fetched_unix": Time.get_unix_time_from_system(),
	}
	main.weather_provider.last_weather = active_weather.duplicate(true)
	main.settings.weather_city = "Toronto"
	main._handle_menu_item(WEATHER_NOW_MENU_ID)
	await process_frame
	_expect(
		main.ambient_card_active
		and "18°C" in main.notification_label.text
		and not main.check_in_manager.is_enabled(),
		(
			"Weather now must show a fresh cached forecast even when "
			+ "automatic Pet Notes are disabled"
		)
	)
	main.notification_done_button.pressed.emit()

	main._show_actionable_notification(
		TimerManagerScript.Kind.WATER,
		"Health reminder must remain visible"
	)
	main._handle_menu_item(WEATHER_NOW_MENU_ID)
	_expect(
		main.notification_label.text
		== "Health reminder must remain visible"
		and not main.manual_weather_card.is_empty(),
		(
			"manual weather must wait instead of replacing a visible "
			+ "health reminder"
		)
	)
	main._hide_notification()
	main._poll_check_ins()
	await process_frame
	_expect(
		main.ambient_card_active
		and "18°C" in main.notification_label.text,
		"queued manual weather must appear after the reminder closes"
	)
	main.notification_done_button.pressed.emit()

	main.shutting_down = true
	if _failed:
		quit(1)
		return
	print("Ambient card integration self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Ambient card integration self-test failed: %s" % message)
