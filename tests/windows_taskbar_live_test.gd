extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_name() != "Windows":
		print("Windows taskbar live test skipped outside Windows.")
		quit(0)
		return

	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	await create_timer(1.0).timeout

	_expect(
		main.taskbar_button_hidden,
		"ITaskbarList::DeleteTab must succeed for the live pet window"
	)
	_expect(
		not main.get_window().unfocusable,
		"taskbar removal must not change the pet window focus style"
	)
	_expect(
		main.context_menu != null
		and not main.context_menu.prefer_native_menu,
		"taskbar removal must not replace the live Godot pet menu"
	)

	main.shutting_down = true
	if _failed:
		quit(1)
		return
	print("Windows taskbar live self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Windows taskbar live self-test failed: %s" % message)
