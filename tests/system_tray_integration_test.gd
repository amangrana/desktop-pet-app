extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")

const MENU_TRAY_TOGGLE_PET := 8
const MENU_START_FOCUS := 41
const MENU_AMBIENT_CARDS := 59
const MENU_EXIT := 90

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	_expect(
		not main.context_menu.prefer_native_menu
		and not main.context_menu.force_native,
		"the pet menu must remain Godot-driven for live status updates"
	)
	_expect(
		main.tray_menu != null
		and main.tray_menu.get_item_index(MENU_TRAY_TOGGLE_PET) >= 0
		and main.tray_menu.get_item_index(MENU_START_FOCUS) >= 0
		and main.tray_menu.get_item_index(MENU_AMBIENT_CARDS) >= 0
		and main.tray_menu.get_item_index(MENU_EXIT) >= 0,
		"the tray menu must expose the core desktop-pet actions"
	)
	_expect(
		FileAccess.file_exists("res://assets/ui/tray_icon.svg"),
		"the Windows tray icon asset must exist"
	)
	_expect(
		main.windows_taskbar_adapter != null
		and main.windows_taskbar_adapter.helper_exists(),
		"the safe Windows taskbar button helper must be packaged"
	)
	main._set_pet_window_visible(false)
	_expect(
		not main.pet_window_visible,
		"the tray action must be able to hide the pet"
	)
	main._set_pet_window_visible(true)
	_expect(
		main.pet_window_visible,
		"the tray action must be able to restore the pet"
	)

	main.shutting_down = true
	if _failed:
		quit(1)
		return
	print("System tray integration self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("System tray integration self-test failed: %s" % message)
