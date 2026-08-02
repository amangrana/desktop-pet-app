extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")

const MENU_TRAY_TOGGLE_PET := 8
const MENU_ACTIVITY_CENTER := 9
const MENU_START_FOCUS := 41
const MENU_AMBIENT_CARDS := 59
const MENU_EXIT := 90
const MENU_SCALE_300 := 37

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
		and main.tray_menu.get_item_index(MENU_ACTIVITY_CENTER) >= 0
		and main.tray_menu.get_item_index(MENU_START_FOCUS) >= 0
		and main.tray_menu.get_item_index(MENU_AMBIENT_CARDS) >= 0
		and main.tray_menu.get_item_index(MENU_EXIT) >= 0,
		"the tray menu must expose the core desktop-pet actions"
	)
	_expect(
		ProjectSettings.get_setting("application/config/icon", "")
		== "res://assets/ui/desktop_pet_icon.png"
		and ProjectSettings.get_setting(
			"application/config/windows_native_icon",
			""
		) == "res://assets/ui/desktop_pet_icon.ico"
		and FileAccess.file_exists("res://assets/ui/desktop_pet_icon.png")
		and FileAccess.file_exists("res://assets/ui/desktop_pet_icon.ico"),
		(
			"the project and exported Windows app must use the custom "
			+ "Desktop Pet icon"
		)
	)
	_expect(
		main.TRAY_ICON_PATH == "res://assets/ui/desktop_pet_icon.png",
		"the Windows tray must reuse the branded application icon"
	)
	var tray_icon: Texture2D = main._load_icon_texture(
		main.TRAY_ICON_PATH
	)
	_expect(
		tray_icon != null
		and tray_icon.get_width() == tray_icon.get_height()
		and tray_icon.get_width() >= 256,
		(
			"the shared application/tray icon must load as a sufficiently "
			+ "large square imported texture, including in exported PCK builds"
		)
	)
	_expect(
		main.windows_taskbar_adapter != null
		and main.windows_taskbar_adapter.helper_exists(),
		"the safe Windows taskbar button helper must be packaged"
	)
	_expect(
		main.windows_fullscreen_adapter != null
		and main.windows_fullscreen_adapter.helper_exists(),
		"the anonymous Windows fullscreen helper must be packaged"
	)
	_expect(
		main.window_menu.get_item_index(MENU_SCALE_300) >= 0,
		"the Window menu must expose the 300% pet scale"
	)
	main._apply_scale(3.0, false)
	var scaled_menus: Array[PopupMenu] = main._scalable_popup_menus()
	var menus_scaled: bool = not scaled_menus.is_empty()
	for menu in scaled_menus:
		if (
			menu.get_theme_font_size("font_size") != 32
			or menu.get_theme_constant("v_separation") != 8
		):
			menus_scaled = false
			break
	_expect(
		menus_scaled
		and main.settings.display_scale == 3.0
		and main.get_window().size == Vector2i(1080, 1080)
		and not main.tray_menu.has_theme_font_size_override("font_size"),
		(
			"300% pet scale must enlarge the pet window and all Godot "
			+ "menus while the "
			+ "native tray menu stays under Windows DPI control"
		)
	)
	main._apply_scale(0.75, false)
	_expect(
		main.context_menu.get_theme_font_size("font_size") == 14,
		"75% pet scale must use the compact readable menu font"
	)
	main._apply_scale(1.0, false)
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
	main._set_pet_window_visible(false)
	main._handle_single_instance_activation()
	_expect(
		main.pet_window_visible
		and not main.pending_instance_activation,
		(
			"launching Desktop Pet again must restore the existing pet "
			+ "instead of leaving it hidden in the tray"
		)
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
