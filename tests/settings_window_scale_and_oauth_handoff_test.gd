extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	main._apply_scale(2.0, false)
	await _expect_scaled_window(
		main,
		main.activity_center_window,
		Vector2i(500, 700),
		main._open_activity_center,
		"Activity Center"
	)
	_expect(
		not main.activity_center_window.exclusive,
		"Activity Center must not block pet interaction"
	)
	await _expect_scaled_window(
		main,
		main.duration_settings_window,
		Vector2i(430, 390),
		main._open_duration_settings,
		"Duration settings"
	)
	await _expect_scaled_window(
		main,
		main.quiet_settings_window,
		Vector2i(410, 330),
		main._open_quiet_settings,
		"Quiet hours settings"
	)
	_expect(
		main.quiet_start_option.get_popup().max_size.y
		== main.quiet_end_option.get_popup().max_size.y
		and not main.quiet_start_option.get_popup().wrap_controls
		and main.quiet_start_option.get_popup().min_size.x
		== main.quiet_start_option.get_popup().max_size.x
		and main.quiet_start_option.get_popup().min_size.x
		>= roundi(main.QUIET_HOUR_POPUP_LOGICAL_WIDTH * 2.0)
		and main.quiet_start_option.get_popup().size.y
		== main.quiet_start_option.get_popup().max_size.y
		and main.quiet_start_option.get_popup().max_size.y >= 280
		and main.quiet_start_option.get_popup().max_size.y <= 480,
		(
			"quiet-hour dropdown height must follow the settings UI "
			+ "scale while respecting limited screen height"
		)
	)
	await _expect_scaled_window(
		main,
		main.language_settings_window,
		Vector2i(390, 250),
		main._open_language_settings,
		"Language settings"
	)
	await _expect_scaled_window(
		main,
		main.pet_notes_settings_window,
		Vector2i(420, 310),
		main._open_pet_notes_settings,
		"Pet Notes settings"
	)

	main.settings.always_on_top = true
	main.get_window().always_on_top = true
	main._open_pet_notes_settings()
	await process_frame
	main._begin_google_oauth_browser_handoff()
	_expect(
		main.google_oauth_browser_handoff_active
		and main.google_oauth_restore_always_on_top
		and not main.pet_notes_settings_window.visible
		and not main.get_window().always_on_top,
		(
			"opening browser authorization must release the exclusive "
			+ "settings window and temporarily disable pet topmost"
		)
	)
	main._end_google_oauth_browser_handoff()
	await process_frame
	await process_frame
	_expect(
		not main.google_oauth_browser_handoff_active
		and main.pet_notes_settings_window.visible
		and main.settings.always_on_top
		and (
			main.get_window().always_on_top
			or DisplayServer.get_name() == "headless"
		),
		(
			"finishing browser authorization must restore topmost and "
			+ "reopen Pet Notes settings "
			+ "(visible=%s topmost=%s shutting_down=%s)"
			% [
				main.pet_notes_settings_window.visible,
				main.get_window().always_on_top,
				main.shutting_down,
			]
		)
	)

	main.pet_notes_settings_window.hide()
	main.shutting_down = true
	if _failed:
		quit(1)
		return
	print("Settings window scale and OAuth handoff test passed.")
	quit()


func _expect_scaled_window(
	main,
	window: Window,
	base_size: Vector2i,
	open_callable: Callable,
	label: String
) -> void:
	open_callable.call()
	await process_frame
	await process_frame
	var width_scale := float(window.size.x) / float(base_size.x)
	var content_width_scale := (
		float(window.size.x) / float(window.content_scale_size.x)
	)
	_expect(
		window.visible
		and window.content_scale_mode
		== Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		and window.content_scale_size.x == base_size.x
		and is_equal_approx(width_scale, 2.0)
		and is_equal_approx(content_width_scale, 2.0),
		(
			(
				"%s must use the pet display scale for its physical "
				+ "window and logical UI content "
				+ "(window=%s content=%s)"
			)
			% [label, window.size, window.content_scale_size]
		)
	)
	window.hide()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
