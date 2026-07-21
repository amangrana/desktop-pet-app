extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const TimerManagerScript := preload("res://src/timers/timer_manager.gd")

const MENU_ACTIVITY_CENTER := 9

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.activity_center_log.time_source = (
		func() -> Dictionary: return {"hour": 9, "minute": 7}
	)

	var timer_snapshot_before: Dictionary = main.timer_manager.snapshot()
	var reminder_snapshot_before: Dictionary = (
		main.reminder_manager.snapshot()
	)
	_expect(
		main.activity_center_window != null
		and main.activity_center_view != null
		and not main.activity_center_window.visible
		and main.activity_center_window.transient
		and not main.activity_center_window.exclusive
		and main.activity_center_window.unresizable,
		(
			"Activity Center must be a hidden, non-exclusive transient "
			+ "window that does not lock the pet"
		)
	)
	_expect(
		main.context_menu.get_item_index(MENU_ACTIVITY_CENTER) >= 0
		and main.tray_menu.get_item_index(MENU_ACTIVITY_CENTER) >= 0,
		"pet and tray menus must expose Activity Center"
	)

	main._handle_menu_item(MENU_ACTIVITY_CENTER)
	await process_frame
	await process_frame
	_expect(
		main.activity_center_window.visible
		and main.activity_center_view.heading_label.text
		== "Activity Center"
		and main.activity_center_view.focus_status_label.text
		== "Timer: idle"
		and main.activity_center_view.water_status_label.text == "Off"
		and main.activity_center_view.stand_status_label.text == "Off"
		and main.activity_center_view.quiet_status_label.text == "Off"
		and main.activity_center_view.pending_label.text
		== "No reminders need attention"
		and main.activity_center_view.recent_empty_label.visible
		and main.activity_center_view.water_turn_on_button.visible
		and main.activity_center_view.water_turn_on_button.text == "Turn on"
		and main.activity_center_view.stand_turn_on_button.visible
		and main.activity_center_view.water_inline_actions.visible
		and not main.activity_center_view.water_actions.visible
		and main.activity_center_view.quiet_inline_actions.visible
		and main.activity_center_view.quiet_settings_button.text == "Edit…",
		"opening Activity Center must show the current English state"
	)
	_expect(
		main.timer_manager.snapshot() == timer_snapshot_before
		and main.reminder_manager.snapshot() == reminder_snapshot_before,
		"opening Activity Center must not mutate timers or reminders"
	)
	_expect(
		main.activity_center_log.entries().is_empty(),
		"opening Activity Center must not create a recent activity event"
	)
	_expect(
		main.activity_center_view.focus_actions.visible
		and main.activity_center_view.focus_primary_button.text
		== "Start focus — 25 min"
		and main.activity_center_view.focus_secondary_button.text
		== "Start break — 5 min",
		"idle Focus controls must offer the two available stages"
	)

	main.activity_center_view.focus_primary_button.pressed.emit()
	_expect(
		main.timer_manager.state == TimerManagerScript.State.RUNNING
		and main.timer_manager.kind == TimerManagerScript.Kind.FOCUS
		and main.activity_center_view.focus_primary_button.text
		== "Pause timer"
		and main.activity_center_view.focus_secondary_button.text
		== "Cancel timer",
		"Focus primary action must start a session and refresh controls"
	)
	main.activity_center_view.focus_primary_button.pressed.emit()
	_expect(
		main.timer_manager.state == TimerManagerScript.State.PAUSED
		and main.activity_center_view.focus_primary_button.text
		== "Resume timer",
		"running Focus primary action must pause the timer"
	)
	main.activity_center_view.focus_primary_button.pressed.emit()
	_expect(
		main.timer_manager.state == TimerManagerScript.State.RUNNING,
		"paused Focus primary action must resume the timer"
	)
	main.activity_center_view.focus_secondary_button.pressed.emit()
	_expect(
		main.timer_manager.state == TimerManagerScript.State.IDLE
		and main.activity_center_log.entries().size() == 4
		and main.activity_center_view.recent_labels[0].text
		== "09:07  Focus cancelled",
		(
			"running Focus secondary action must cancel the timer and "
			+ "record the result"
		)
	)

	main._start_timer(TimerManagerScript.Kind.FOCUS, 120)
	_expect(
		main.activity_center_view.focus_status_label.text
		== "Focus: 02:00"
		and main.activity_center_view.focus_dot.get_theme_color(
			"font_color"
		) == main.activity_center_view.COLOR_ACTIVE,
		"Focus changes must refresh the visible Activity Center"
	)

	main.activity_center_view.water_turn_on_button.pressed.emit()
	_expect(
		main.reminder_manager.is_enabled(TimerManagerScript.Kind.WATER)
		and main.activity_center_view.water_status_label.text
		.begins_with("Next in ")
		and main.activity_center_view.water_running_turn_off_button.visible
		and main.activity_center_view.water_inline_actions.visible
		and not main.activity_center_view.water_actions.visible
		and not main.activity_center_view.water_done_button.visible
		and main.activity_center_view.water_dot.get_theme_color(
			"font_color"
		) == main.activity_center_view.COLOR_ACTIVE
		and main.activity_center_view.recent_labels[0].text
		== "09:07  Water reminders turned on",
		"Turn on must start the selected reminder and refresh its card"
	)
	main.activity_center_view.water_running_turn_off_button.pressed.emit()
	_expect(
		not main.reminder_manager.is_enabled(TimerManagerScript.Kind.WATER)
		and main.activity_center_view.water_status_label.text == "Off"
		and main.activity_center_view.water_turn_on_button.visible
		and main.activity_center_view.recent_labels[0].text
		== "09:07  Water reminders turned off",
		"running reminder Turn off must stop only the selected type"
	)
	main.activity_center_view.water_turn_on_button.pressed.emit()

	var fake_local_hour := [23]
	main.reminder_manager.local_hour_source = (
		func() -> int: return int(fake_local_hour[0])
	)
	main.reminder_manager.set_quiet_hours(true, 22, 8)
	var water_timer = main.reminder_manager._timer_for(
		TimerManagerScript.Kind.WATER
	)
	water_timer.end_unix = Time.get_unix_time_from_system() - 0.1
	water_timer._process(0.0)
	main.activity_center_view.stand_turn_on_button.pressed.emit()
	var stand_timer = main.reminder_manager._timer_for(
		TimerManagerScript.Kind.STAND
	)
	stand_timer.end_unix = Time.get_unix_time_from_system() - 0.1
	stand_timer._process(0.0)
	_expect(
		main.activity_center_view.water_status_label.text
		== "Due — queued until quiet hours end"
		and main.activity_center_view.water_dot.get_theme_color(
			"font_color"
		) == main.activity_center_view.COLOR_ATTENTION
		and main.activity_center_view.quiet_status_label.text
		== "22:00–08:00 — active now"
		and main.activity_center_view.water_actions.visible
		and main.activity_center_view.stand_actions.visible
		and not main.activity_center_view.water_inline_actions.visible
		and not main.activity_center_view.stand_inline_actions.visible
		and not main.activity_center_view.water_turn_on_button.visible
		and main.activity_center_view.water_done_button.visible
		and main.activity_center_view.water_snooze_button.visible
		and main.activity_center_view.water_turn_off_button.visible
		and main.activity_center_view.pending_label.text
		== "2 reminders need attention"
		and main.context_menu.get_item_text(
			main.context_menu.get_item_index(MENU_ACTIVITY_CENTER)
		) == "Activity Center… (2)"
		and main.tray_menu.get_item_text(
			main.tray_menu.get_item_index(MENU_ACTIVITY_CENTER)
		) == "Activity Center… (2)",
		(
			"due reminders must show as queued while quiet hours are "
			+ "active and expose their direct actions"
		)
	)

	main._set_language("zh_CN")
	var chinese_recent_text := ""
	for label in main.activity_center_view.recent_labels:
		if label.visible:
			chinese_recent_text += label.text
	_expect(
		main.activity_center_window.title == "活动中心"
		and main.activity_center_view.heading_label.text == "活动中心"
		and main.activity_center_view.focus_title_label.text == "专注计时"
		and main.activity_center_view.water_status_label.text
		== "待处理 — 将在勿扰结束后显示"
		and main.activity_center_view.water_done_button.text == "完成"
		and main.activity_center_view.water_snooze_button.text
		== "10 分钟后"
		and main.activity_center_view.water_turn_off_button.text == "关闭"
		and main.activity_center_view.quiet_settings_button.text == "编辑…"
		and main.activity_center_view.pending_label.text
		== "有 2 项提醒待处理"
		and chinese_recent_text.contains("提醒已到期")
		and main.activity_center_view.close_button.text == "关闭",
		(
			"Activity Center must refresh current state and stored "
			+ "recent events in Chinese"
		)
	)

	main.activity_center_view.stand_done_button.pressed.emit()
	_expect(
		not main.reminder_manager.is_due(TimerManagerScript.Kind.STAND)
		and main.reminder_manager.is_due(TimerManagerScript.Kind.WATER),
		(
			"a Stand card action must handle Stand without consuming "
			+ "an earlier due Water reminder"
		)
	)
	stand_timer.end_unix = Time.get_unix_time_from_system() - 0.1
	stand_timer._process(0.0)
	main.activity_center_view.stand_turn_off_button.pressed.emit()
	_expect(
		not main.reminder_manager.is_enabled(
			TimerManagerScript.Kind.STAND
		)
		and main.reminder_manager.is_due(TimerManagerScript.Kind.WATER)
		and main.activity_center_view.stand_turn_on_button.visible
		and main.activity_center_view.stand_turn_on_button.text == "开启",
		(
			"Turn off must disable only the selected reminder type and "
			+ "offer localized re-enabling"
		)
	)
	main.activity_center_view.water_snooze_button.pressed.emit()
	_expect(
		not main.reminder_manager.is_due(TimerManagerScript.Kind.WATER)
		and main.reminder_manager.remaining_seconds(
			TimerManagerScript.Kind.WATER
		) == main.reminder_manager.snooze_seconds(),
		"Snooze must reschedule the selected due reminder"
	)
	water_timer.end_unix = Time.get_unix_time_from_system() - 0.1
	water_timer._process(0.0)

	main._apply_scale(2.0, false)
	await process_frame
	var expected_activity_scale: float = main._settings_window_scale(
		main.activity_center_window,
		main.ACTIVITY_CENTER_WINDOW_SIZE
	)
	var expected_activity_size := Vector2i(
		roundi(main.ACTIVITY_CENTER_WINDOW_SIZE.x * expected_activity_scale),
		roundi(main.ACTIVITY_CENTER_WINDOW_SIZE.y * expected_activity_scale)
	)
	_expect(
		main.activity_center_window.content_scale_size
		== main.ACTIVITY_CENTER_WINDOW_SIZE
		and main.activity_center_window.size
		== expected_activity_size,
		(
			"Activity Center must follow the pet display scale while "
			+ "remaining inside the usable screen"
		)
	)

	main.activity_center_view.duration_settings_button.pressed.emit()
	await process_frame
	_expect(
		main.duration_settings_window.visible,
		"Set durations must open the existing duration settings window"
	)
	main.duration_settings_window.hide()
	main.activity_center_view.quiet_settings_button.pressed.emit()
	await process_frame
	_expect(
		main.quiet_settings_window.visible,
		"Quiet hours must open the existing quiet settings window"
	)
	main.quiet_settings_window.hide()

	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--capture-activity-center="):
			continue
		main._set_language("en")
		main._apply_scale(1.0, false)
		main._open_activity_center()
		await process_frame
		await RenderingServer.frame_post_draw
		var output_path := argument.trim_prefix(
			"--capture-activity-center="
		)
		main.activity_center_window.get_texture().get_image().save_png(
			output_path
		)

	main.activity_center_view.recent_clear_button.pressed.emit()
	_expect(
		main.activity_center_log.entries().is_empty()
		and main.activity_center_view.recent_empty_label.visible
		and main.activity_center_view.recent_clear_button.disabled,
		"Clear must remove only the session recent activity list"
	)
	main.activity_center_view.focus_secondary_button.pressed.emit()
	fake_local_hour[0] = 12
	main.reminder_manager._next_boundary_check_unix = 0.0
	main.reminder_manager._process(0.0)
	_expect(
		not main.notification_panel.visible
		and main.reminder_manager.is_due(TimerManagerScript.Kind.WATER),
		(
			"due reminder bubbles must stay suppressed while Activity "
			+ "Center supplies the actionable controls"
		)
	)
	main.activity_center_view.close_button.pressed.emit()
	_expect(
		not main.activity_center_window.visible,
		"the Activity Center Close button must hide the window"
	)
	await process_frame
	_expect(
		main.notification_panel.visible
		and main.notification_action_kind == TimerManagerScript.Kind.WATER,
		(
			"closing Activity Center must restore a still-due reminder "
			+ "to the pet bubble"
		)
	)
	main._hide_notification()

	main.shutting_down = true
	if _failed:
		quit(1)
		return
	print("Activity Center integration self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Activity Center integration self-test failed: %s" % message)
