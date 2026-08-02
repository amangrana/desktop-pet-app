extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const MENU_ALWAYS_ON_TOP := 10

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	main.fullscreen_detection_test_mode = true
	main.settings.always_on_top = true
	main.external_fullscreen_state_known = true
	main.external_fullscreen_active = false
	main._apply_effective_always_on_top()
	_expect(
		main._should_enable_always_on_top(),
		"the saved topmost preference must apply when no fullscreen app is active"
	)

	main._handle_external_fullscreen_changed(true)
	main._update_menu_checks()
	var menu_index: int = main.window_menu.get_item_index(
		MENU_ALWAYS_ON_TOP
	)
	_expect(
		not main._should_enable_always_on_top()
		and main.settings.always_on_top
		and main.window_menu.is_item_checked(menu_index),
		"fullscreen must suspend effective topmost without changing the preference"
	)

	main._handle_external_fullscreen_changed(false)
	_expect(
		main._should_enable_always_on_top(),
		"leaving fullscreen must restore the saved topmost preference"
	)

	main._handle_external_fullscreen_changed(true)
	main._begin_google_oauth_browser_handoff()
	main._end_google_oauth_browser_handoff()
	_expect(
		not main._should_enable_always_on_top(),
		"ending OAuth must not override an active fullscreen suspension"
	)
	main._handle_external_fullscreen_changed(false)
	_expect(
		main._should_enable_always_on_top(),
		"topmost must recover after both temporary suspension reasons end"
	)

	main.settings.always_on_top = false
	main._apply_effective_always_on_top()
	main._handle_external_fullscreen_changed(false)
	_expect(
		not main._should_enable_always_on_top(),
		"fullscreen changes must never enable a user-disabled topmost setting"
	)

	main.shutting_down = true
	main.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("Fullscreen topmost integration self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Fullscreen topmost integration self-test failed: %s" % message)
