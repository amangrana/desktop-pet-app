extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	_expect(
		main._google_calendar_auto_restore_allowed(),
		"Google Calendar auto-restore must be allowed before disconnect"
	)

	main._set_google_calendar_explicit_disconnect(true)
	_expect(
		not main._google_calendar_auto_restore_allowed(),
		"an explicit disconnect must block auto-restore immediately"
	)
	main.shutting_down = true
	main.queue_free()
	await process_frame

	var restarted_main = MainScene.instantiate()
	root.add_child(restarted_main)
	await process_frame
	_expect(
		bool(
			restarted_main.settings
			.google_calendar_explicitly_disconnected
		)
		and not restarted_main._google_calendar_auto_restore_allowed(),
		(
			"the explicit-disconnect guard must survive an immediate "
			+ "app restart"
		)
	)

	restarted_main._set_google_calendar_explicit_disconnect(false)
	restarted_main.shutting_down = true
	restarted_main.queue_free()
	await process_frame
	var reconnected_main = MainScene.instantiate()
	root.add_child(reconnected_main)
	await process_frame
	_expect(
		reconnected_main._google_calendar_auto_restore_allowed(),
		"a later successful connection must re-enable auto-restore"
	)
	reconnected_main.shutting_down = true

	if _failed:
		quit(1)
		return
	print("Google Calendar disconnect policy self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(
		"Google Calendar disconnect policy self-test failed: %s"
		% message
	)
