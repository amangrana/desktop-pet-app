extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const TimerManagerScript := preload("res://src/timers/timer_manager.gd")
const ReminderManagerScript := preload(
	"res://src/timers/reminder_manager.gd"
)

const REMINDERS_SUBMENU_ID := 2
const WATER_MENU_ID := 50
const COMPLETE_MENU_ID := 52
const REMOVED_SKIP_MENU_ID := 54
const REMOVED_PAUSE_TODAY_MENU_ID := 55
const DEV_WATER_MENU_ID := 48
const DEV_STAND_MENU_ID := 49
const DURATION_SETTINGS_MENU_ID := 57
const LANGUAGE_SETTINGS_MENU_ID := 58
const STOP_REMINDER_MENU_ID := 60
const QUIET_HOURS_MENU_ID := 62
const SETTINGS_SUBMENU_ID := 3
const START_FOCUS_MENU_ID := 41
const START_BREAK_MENU_ID := 42
const CANCEL_TIMER_MENU_ID := 44

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	_expect(
		main._settings_file_path() != main.SETTINGS_FILE,
		"automated tests must not use the production settings file"
	)
	_expect(
		main.context_menu.get_item_index(REMINDERS_SUBMENU_ID) >= 0,
		"top-level menu must expose the reminders submenu"
	)
	_expect(
		main.reminder_menu.get_item_index(WATER_MENU_ID) >= 0,
		"reminders submenu must expose the water toggle"
	)
	_expect(
		main.reminder_menu.get_item_index(STOP_REMINDER_MENU_ID) >= 0
		and main.reminder_menu.get_item_index(
			REMOVED_SKIP_MENU_ID
		) < 0
		and main.reminder_menu.get_item_index(
			REMOVED_PAUSE_TODAY_MENU_ID
		) < 0,
		(
			"reminder actions must contain Done, Snooze, and Turn off "
			+ "without the removed Skip or Pause today choices"
		)
	)
	_expect(
		main.settings_menu.get_item_index(DURATION_SETTINGS_MENU_ID) >= 0
		and main.reminder_menu.get_item_index(
			DURATION_SETTINGS_MENU_ID
		) < 0,
		"duration settings must live in Settings, not Reminders"
	)
	_expect(
		main.settings_menu.get_item_index(LANGUAGE_SETTINGS_MENU_ID) >= 0,
		"Settings must expose one scalable language window entry"
	)
	_expect(
		main.settings_menu.get_item_index(QUIET_HOURS_MENU_ID) >= 0
		and main.reminder_menu.get_item_index(
			QUIET_HOURS_MENU_ID
		) >= 0,
		(
			"quiet hours must open the same settings window from "
			+ "Settings and Reminders"
		)
	)
	_expect(
		main.developer_menu.get_item_index(DEV_WATER_MENU_ID) >= 0,
		"developer menu must expose the one-second water reminder"
	)
	_expect(
		main.developer_menu.get_item_index(DEV_STAND_MENU_ID) >= 0,
		"developer menu must expose the one-second stand reminder"
	)
	var complete_index: int = main.reminder_menu.get_item_index(
		COMPLETE_MENU_ID
	)
	_expect(
		main.reminder_menu.is_item_disabled(complete_index),
		"reminder actions must stay disabled when nothing is due"
	)

	main._handle_menu_item(WATER_MENU_ID)
	_expect(
		main.reminder_manager.is_enabled(TimerManagerScript.Kind.WATER),
		"water reminder toggle must enable its schedule"
	)
	_expect(
		main.reminder_manager.remaining_seconds(
			TimerManagerScript.Kind.WATER
		) == ReminderManagerScript.WATER_INTERVAL_SECONDS,
		"water toggle must start a one-hour schedule"
	)
	var active_water_remaining: int = main.reminder_manager.remaining_seconds(
		TimerManagerScript.Kind.WATER
	)
	main._handle_menu_item(START_FOCUS_MENU_ID)
	var active_focus_remaining: int = main.timer_manager.remaining_seconds()
	main._handle_menu_item(DURATION_SETTINGS_MENU_ID)
	await process_frame
	_expect(
		main.duration_settings_window.visible
		and main.duration_settings_window.size == Vector2i(430, 390)
		and not main.duration_settings_scroll.get_v_scroll_bar().visible,
		"duration settings menu must open a standalone window"
	)
	var original_duration_note: String = main.duration_settings_note.text
	main.duration_settings_note.text += (
		" Additional translated guidance".repeat(80)
	)
	main._queue_duration_settings_window_resize()
	await process_frame
	await process_frame
	var duration_save_rect: Rect2 = (
		main.duration_save_button.get_global_rect()
	)
	var duration_cancel_rect: Rect2 = (
		main.duration_cancel_button.get_global_rect()
	)
	_expect(
		main.duration_settings_window.size.y == 600
		and main.duration_settings_scroll.get_v_scroll_bar().visible
		and duration_save_rect.end.y
		<= main.duration_settings_window.size.y - 18
		and duration_cancel_rect.end.y
		<= main.duration_settings_window.size.y - 18,
		(
			"long duration guidance must scroll while Save and Cancel "
			+ "remain fully visible"
		)
	)
	main.duration_settings_note.text = original_duration_note
	main._queue_duration_settings_window_resize()
	await process_frame
	await process_frame
	_expect(
		main.duration_settings_window.size == Vector2i(430, 390)
		and not main.duration_settings_scroll.get_v_scroll_bar().visible,
		"duration settings must shrink after long guidance is cleared"
	)
	main.duration_spin_boxes["focus"].get_line_edit().grab_focus()
	main.duration_spin_boxes["focus"].get_line_edit().text = "39"
	main.duration_spin_boxes["break"].value = 9
	main.duration_spin_boxes["water"].value = 90
	main.duration_spin_boxes["stand"].value = 30
	main.duration_spin_boxes["snooze"].value = 20
	main.duration_reset_button.pressed.emit()
	_expect(
		main.duration_settings_window.visible
		and int(main.duration_spin_boxes["focus"].value) == 25
		and main.duration_spin_boxes[
			"focus"
		].get_line_edit().text.begins_with("25")
		and int(main.duration_spin_boxes["break"].value) == 5
		and int(main.duration_spin_boxes["water"].value) == 60
		and int(main.duration_spin_boxes["stand"].value) == 45
		and int(main.duration_spin_boxes["snooze"].value) == 10,
		(
			"reset must restore 25/5/60/45/10 in the form "
			+ "without closing it"
		)
	)
	_expect(
		int(main.settings.focus_duration_seconds)
		== 25 * 60
		and main.reminder_manager.interval_seconds(
			TimerManagerScript.Kind.WATER
		) == ReminderManagerScript.WATER_INTERVAL_SECONDS,
		"reset must not apply form values before Save is pressed"
	)
	var focus_editor: LineEdit = (
		main.duration_spin_boxes["focus"].get_line_edit()
	)
	focus_editor.grab_focus()
	focus_editor.text = "40"
	focus_editor.text_changed.emit("40")
	main.duration_spin_boxes["break"].value = 8
	main.duration_spin_boxes["water"].value = 75
	main.duration_spin_boxes["stand"].value = 35
	main.duration_spin_boxes["snooze"].value = 15
	main.duration_save_button.pressed.emit()
	_expect(
		not main.duration_settings_window.visible
		and int(main.settings.focus_duration_seconds) == 40 * 60
		and int(main.settings.break_duration_seconds) == 8 * 60
		and main.reminder_manager.interval_seconds(
			TimerManagerScript.Kind.WATER
		) == 75 * 60
		and main.reminder_manager.interval_seconds(
			TimerManagerScript.Kind.STAND
		) == 35 * 60
		and main.reminder_manager.snooze_seconds() == 15 * 60,
		(
			"duration settings must save all five values even when "
			+ "the edited field still has input focus"
		)
	)
	_expect(
		main.reminder_manager.remaining_seconds(
			TimerManagerScript.Kind.WATER
		) == active_water_remaining,
		"new reminder defaults must not reset an active countdown"
	)
	_expect(
		main.timer_manager.remaining_seconds() == active_focus_remaining,
		"new focus and break defaults must not reset an active timer"
	)
	var focus_start_text: String = main.focus_menu.get_item_text(
		main.focus_menu.get_item_index(START_FOCUS_MENU_ID)
	)
	_expect(
		"40 min" in focus_start_text,
		"focus menu must immediately show the saved default duration"
	)
	main._handle_menu_item(CANCEL_TIMER_MENU_ID)
	main._handle_menu_item(START_FOCUS_MENU_ID)
	_expect(
		main.timer_manager.remaining_seconds() == 40 * 60,
		"normal focus start must use the configured default duration"
	)
	main._handle_menu_item(CANCEL_TIMER_MENU_ID)
	main._handle_menu_item(START_BREAK_MENU_ID)
	_expect(
		main.timer_manager.remaining_seconds() == 8 * 60,
		"normal break start must use the configured default duration"
	)
	main._handle_menu_item(CANCEL_TIMER_MENU_ID)

	main._handle_menu_item(DEV_WATER_MENU_ID)
	main.reminder_manager._timer_for(
		TimerManagerScript.Kind.WATER
	).end_unix = Time.get_unix_time_from_system() - 0.1
	main.reminder_manager._timer_for(
		TimerManagerScript.Kind.WATER
	)._process(0.0)
	_expect(
		main.reminder_manager.is_due(TimerManagerScript.Kind.WATER),
		(
			"one-second water reminder must become due "
			+ "(state=%d remaining=%d)"
			% [
				main.reminder_manager._timer_for(
					TimerManagerScript.Kind.WATER
				).state,
				main.reminder_manager.remaining_seconds(
					TimerManagerScript.Kind.WATER
				),
			]
		)
	)
	_expect(
		main.notification_panel.visible,
		"due health reminder must show the pet bubble"
	)
	_expect(
		main.notification_stop_button.visible
		and main.notification_stop_button.text == "Turn off"
		and main.notification_stop_button.has_theme_stylebox_override(
			"normal"
		),
		(
			"due reminder bubble must expose a direct warning-styled "
			+ "Turn off action"
		)
	)
	_expect(
		"Water break" in main.notification_label.text,
		"water reminder bubble must use gentle copy"
	)
	_expect(
		main.notification_actions.visible
		and main.notification_done_button.text == "Done"
		and main.notification_snooze_button.text == "15 min"
		and main.notification_stop_button.text == "Turn off",
		(
			"due reminder bubble must directly expose Done, Snooze, "
			+ "and Turn off"
		)
	)
	_expect(
		main.notification_panel.mouse_filter == Control.MOUSE_FILTER_STOP,
		"actionable bubble must accept mouse input"
	)
	_expect(
		Geometry2D.is_point_in_polygon(
			main.notification_panel.position
			+ main.notification_panel.size / 2.0,
			main.get_window().mouse_passthrough_polygon
		),
		"actionable bubble must be included in the window hit region"
	)
	var bubble_click := InputEventMouseButton.new()
	bubble_click.button_index = MOUSE_BUTTON_LEFT
	bubble_click.pressed = true
	bubble_click.position = (
		main.notification_panel.position
		+ main.notification_panel.size / 2.0
	)
	main.dragging = false
	main._handle_mouse_button(bubble_click)
	_expect(
		not main.dragging,
		"clicking reminder actions must not begin dragging the pet"
	)
	_expect(
		not main.reminder_menu.is_item_disabled(complete_index),
		"reminder actions must enable while a reminder is due"
	)
	main._hide_notification()
	main._handle_pet_tap(Vector2.ZERO)
	_expect(
		main.notification_panel.visible
		and main.notification_actions.visible,
		"clicking the pet must reopen a hidden due reminder"
	)
	main.notification_snooze_button.pressed.emit()
	_expect(
		not main.reminder_manager.is_due(TimerManagerScript.Kind.WATER)
		and main.reminder_manager.remaining_seconds(
			TimerManagerScript.Kind.WATER
		) == 15 * 60
		and is_equal_approx(
			main.notification_timer.wait_time,
			main.INFORMATION_NOTIFICATION_SECONDS
		),
		(
			"bubble snooze must use the configured duration and show "
			+ "only a short result message"
		)
	)

	main._handle_menu_item(DEV_WATER_MENU_ID)
	main.reminder_manager._timer_for(
		TimerManagerScript.Kind.WATER
	).end_unix = Time.get_unix_time_from_system() - 0.1
	main.reminder_manager._timer_for(
		TimerManagerScript.Kind.WATER
	)._process(0.0)
	main.notification_done_button.pressed.emit()
	_expect(
		not main.reminder_manager.is_due(TimerManagerScript.Kind.WATER),
		"bubble completion button must schedule the next interval"
	)
	_expect(
		is_equal_approx(
			main.notification_timer.wait_time,
			main.INFORMATION_NOTIFICATION_SECONDS
		),
		"Done result message must close after 2.5 seconds"
	)

	main._handle_menu_item(DEV_WATER_MENU_ID)
	main.reminder_manager._timer_for(
		TimerManagerScript.Kind.WATER
	).end_unix = Time.get_unix_time_from_system() - 0.1
	main.reminder_manager._timer_for(
		TimerManagerScript.Kind.WATER
	)._process(0.0)
	main.notification_stop_button.pressed.emit()
	_expect(
		not main.reminder_manager.is_enabled(
			TimerManagerScript.Kind.WATER
		)
		and not main.reminder_manager.is_due(
			TimerManagerScript.Kind.WATER
		)
		and "Water reminders are off" in main.notification_label.text
		and is_equal_approx(
			main.notification_timer.wait_time,
			main.INFORMATION_NOTIFICATION_SECONDS
		),
		(
			"stop action must disable the due reminder and show only "
			+ "a short result message"
		)
	)
	main._handle_menu_item(WATER_MENU_ID)

	main._handle_menu_item(LANGUAGE_SETTINGS_MENU_ID)
	await process_frame
	_expect(
		main.language_settings_window.visible
		and main.language_option_button.item_count == 2
		and main.language_settings_window.size == Vector2i(390, 250)
		and not main.language_settings_scroll.get_v_scroll_bar().visible,
		"language entry must open a standalone language picker"
	)
	var original_language_note: String = main.language_settings_note.text
	main.language_settings_note.text += (
		" Additional localization guidance".repeat(80)
	)
	main._queue_language_settings_window_resize()
	await process_frame
	await process_frame
	var language_save_rect: Rect2 = (
		main.language_save_button.get_global_rect()
	)
	var language_cancel_rect: Rect2 = (
		main.language_cancel_button.get_global_rect()
	)
	_expect(
		main.language_settings_window.size.y == 480
		and main.language_settings_scroll.get_v_scroll_bar().visible
		and language_save_rect.end.y
		<= main.language_settings_window.size.y - 18
		and language_cancel_rect.end.y
		<= main.language_settings_window.size.y - 18,
		(
			"long language guidance must scroll while Save and Cancel "
			+ "remain fully visible"
		)
	)
	main.language_settings_note.text = original_language_note
	main._queue_language_settings_window_resize()
	await process_frame
	await process_frame
	_expect(
		main.language_settings_window.size == Vector2i(390, 250)
		and not main.language_settings_scroll.get_v_scroll_bar().visible,
		"language settings must shrink after long guidance is cleared"
	)
	main.language_option_button.select(1)
	main.language_save_button.pressed.emit()
	_expect(
		not main.language_settings_window.visible
		and main.settings.language == "zh_CN"
		and main.duration_reset_button.text == "恢复默认值"
		and "设置" in main.context_menu.get_item_text(
			main.context_menu.get_item_index(SETTINGS_SUBMENU_ID)
		),
		"language picker must switch the interface to Simplified Chinese"
	)

	var fake_local_hour := [23]
	main.reminder_manager.local_hour_source = (
		func() -> int: return int(fake_local_hour[0])
	)
	main._handle_menu_item(QUIET_HOURS_MENU_ID)
	_expect(
		main.quiet_settings_window.visible
		and not main.reminder_manager.quiet_hours_enabled()
		and main._quiet_option_hour(main.quiet_start_option) == 22
		and main._quiet_option_hour(main.quiet_end_option) == 8
		and main.quiet_start_option.item_count == 24
		and not main.quiet_start_option.get_popup().wrap_controls
		and main.quiet_start_option.get_popup().min_size.x > 0
		and main.quiet_start_option.get_popup().min_size.y
		== main.quiet_start_option.get_popup().max_size.y
		and main.quiet_start_option.get_popup().max_size.y > 0
		and main.quiet_start_option.get_popup().max_size.y
		< main.quiet_start_option.item_count * 24,
		(
			"opening quiet hours must load saved values without "
			+ "changing the schedule, and the hour list must use a "
			+ "short scrollable popup"
		)
	)
	main.quiet_enabled_check.button_pressed = true
	main.quiet_start_option.select(21)
	main.quiet_end_option.select(21)
	main._update_quiet_settings_form()
	_expect(
		main.quiet_save_button.disabled
		and main.quiet_validation_label.visible,
		"equal quiet-hour endpoints must show validation and block Save"
	)
	main.quiet_end_option.select(7)
	main._update_quiet_settings_form()
	main.quiet_save_button.pressed.emit()
	_expect(
		not main.quiet_settings_window.visible
		and main.reminder_manager.quiet_hours_enabled()
		and main.reminder_manager.quiet_start_hour() == 21
		and main.reminder_manager.quiet_end_hour() == 7
		and main.reminder_manager.is_quiet_now()
		and main.reminder_menu.is_item_checked(
			main.reminder_menu.get_item_index(QUIET_HOURS_MENU_ID)
		)
		and main.settings_menu.is_item_checked(
			main.settings_menu.get_item_index(QUIET_HOURS_MENU_ID)
		)
		and main.reminder_menu.get_item_text(
			main.reminder_menu.get_item_index(QUIET_HOURS_MENU_ID)
		) == "勿扰时段：21:00–07:00"
		and main.reminder_menu.get_item_icon_modulate(
			main.reminder_menu.get_item_index(QUIET_HOURS_MENU_ID)
		) == main.QUIET_STATUS_ACTIVE_COLOR,
		(
			"quiet-hours form must save the selected 21:00–07:00 "
			+ "range, check both menu entries, and use the active color"
		)
	)
	main._handle_menu_item(QUIET_HOURS_MENU_ID)
	_expect(
		main.quiet_settings_window.visible
		and main._quiet_option_hour(main.quiet_start_option) == 21
		and main._quiet_option_hour(main.quiet_end_option) == 7,
		"reopening quiet hours must preserve values instead of cycling"
	)
	main.quiet_start_option.select(20)
	main.quiet_cancel_button.pressed.emit()
	_expect(
		not main.quiet_settings_window.visible
		and main.reminder_manager.quiet_start_hour() == 21
		and main.reminder_manager.quiet_end_hour() == 7,
		"Cancel must discard form changes without mutating quiet hours"
	)
	main._start_timer(TimerManagerScript.Kind.FOCUS, 30)
	main._handle_menu_item(DEV_STAND_MENU_ID)
	main.reminder_manager._timer_for(
		TimerManagerScript.Kind.STAND
	).end_unix = Time.get_unix_time_from_system() - 0.1
	main.reminder_manager._timer_for(
		TimerManagerScript.Kind.STAND
	)._process(0.0)
	_expect(
		main.reminder_manager.is_due(TimerManagerScript.Kind.STAND),
		"stand reminder must still become due during focus"
	)
	_expect(
		not main.notification_panel.visible,
		"health reminder bubble must defer during focus"
	)
	main._start_timer(TimerManagerScript.Kind.BREAK, 30)
	_expect(
		not main.notification_panel.visible,
		"quiet hours must keep the reminder deferred during a break"
	)
	fake_local_hour[0] = 9
	main.reminder_manager._next_boundary_check_unix = 0.0
	main.reminder_manager._process(0.0)
	_expect(
		main.notification_panel.visible
		and "伸伸懒腰" in main.notification_label.text
		and main.notification_done_button.text == "完成"
		and main.reminder_menu.get_item_text(
			main.reminder_menu.get_item_index(QUIET_HOURS_MENU_ID)
		) == "勿扰时段：21:00–07:00"
		and main.reminder_menu.get_item_icon_modulate(
			main.reminder_menu.get_item_index(QUIET_HOURS_MENU_ID)
		) == main.QUIET_STATUS_INACTIVE_COLOR,
		"reminder must surface in Chinese after quiet hours end: %s"
		% main.notification_label.text
	)

	var saved_snapshot = main.settings.reminder_snapshot
	_expect(
		saved_snapshot is Dictionary
		and bool(saved_snapshot.water.enabled)
		and bool(saved_snapshot.stand.enabled)
		and int(saved_snapshot.preferences.water_interval_seconds)
		== 75 * 60
		and int(saved_snapshot.preferences.stand_interval_seconds)
		== 35 * 60
		and int(saved_snapshot.preferences.snooze_seconds) == 15 * 60
		and bool(saved_snapshot.preferences.quiet_enabled)
		and int(saved_snapshot.preferences.quiet_start_hour) == 21
		and int(saved_snapshot.preferences.quiet_end_hour) == 7,
		"enabled schedules and reminder preferences must be in settings"
	)
	main._save_settings()
	var config := ConfigFile.new()
	_expect(
		config.load(main._settings_file_path()) == OK,
		"health reminder settings must be written to the local config"
	)
	_expect(
		config.get_value("interface", "language", "") == "zh_CN",
		"selected interface language must persist"
	)
	_expect(
		int(
			config.get_value(
				"timer_defaults",
				"focus_duration_seconds",
				0
			)
		) == 40 * 60
		and int(
			config.get_value(
				"timer_defaults",
				"break_duration_seconds",
				0
			)
		) == 8 * 60,
		"focus and break defaults must persist in the local config"
	)
	var persisted_snapshot = config.get_value(
		"reminders",
		"snapshot",
		{}
	)
	var restored = ReminderManagerScript.new()
	root.add_child(restored)
	_expect(
		persisted_snapshot is Dictionary
		and restored.restore(persisted_snapshot),
		"health reminder schedules must restore from the local config"
	)
	_expect(
		restored.is_enabled(TimerManagerScript.Kind.WATER)
		and restored.is_due(TimerManagerScript.Kind.STAND),
		"restored config must preserve running and due reminders"
	)

	main.shutting_down = true
	main.queue_free()
	await process_frame
	var localized_main = MainScene.instantiate()
	root.add_child(localized_main)
	await process_frame
	_expect(
		localized_main.settings.language == "zh_CN"
		and int(localized_main.settings.focus_duration_seconds) == 40 * 60
		and int(localized_main.settings.break_duration_seconds) == 8 * 60
		and localized_main.notification_done_button.text == "完成"
		and localized_main.notification_snooze_button.text == "15 分钟后"
		and localized_main.reminder_manager.quiet_hours_enabled(),
		(
			"saved Chinese interface and quiet hours must restore "
			+ "(language=%s button=%s quiet=%s)"
			% [
				localized_main.settings.language,
				localized_main.notification_done_button.text,
				localized_main.reminder_manager.quiet_hours_enabled(),
			]
		)
	)
	var contaminated_config := ConfigFile.new()
	contaminated_config.set_value(
		"timer_defaults",
		"focus_duration_seconds",
		40 * 60
	)
	contaminated_config.set_value(
		"timer_defaults",
		"break_duration_seconds",
		8 * 60
	)
	contaminated_config.set_value("interface", "language", "zh_CN")
	contaminated_config.set_value("reminders", "snapshot", {
		"preferences": {
			"water_interval_seconds": 75 * 60,
			"stand_interval_seconds": 35 * 60,
			"snooze_seconds": 15 * 60,
			"quiet_enabled": true,
		},
		"water": {"enabled": true},
		"stand": {"enabled": true},
	})
	_expect(
		localized_main._recover_legacy_test_settings(
			contaminated_config
		)
		and int(contaminated_config.get_value(
			"timer_defaults",
			"focus_duration_seconds",
			0
		)) == 25 * 60
		and int(contaminated_config.get_value(
			"timer_defaults",
			"break_duration_seconds",
			0
		)) == 5 * 60
		and contaminated_config.get_value(
			"reminders",
			"snapshot",
			{"unexpected": true}
		).is_empty(),
		"the legacy integration-test fingerprint must reset safely"
	)
	var legitimate_config := ConfigFile.new()
	legitimate_config.set_value(
		"timer_defaults",
		"focus_duration_seconds",
		40 * 60
	)
	legitimate_config.set_value(
		"timer_defaults",
		"break_duration_seconds",
		8 * 60
	)
	legitimate_config.set_value("reminders", "snapshot", {
		"preferences": {
			"water_interval_seconds": 75 * 60,
			"stand_interval_seconds": 35 * 60,
			"snooze_seconds": 15 * 60,
			"quiet_enabled": false,
		},
		"water": {"enabled": true},
		"stand": {"enabled": true},
	})
	_expect(
		not localized_main._recover_legacy_test_settings(
			legitimate_config
		),
		"similar intentional user settings must not be reset"
	)
	localized_main.shutting_down = true
	if _failed:
		quit(1)
		return
	print("Health reminder integration self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Health reminder integration self-test failed: %s" % message)
