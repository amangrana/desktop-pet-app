extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const BEHAVIOR_PREVIEW_MENU_ID := 65
const BEHAVIOR_IDS := [
	&"idle_blink",
	&"click_happy",
	&"keyboard",
	&"mouse",
	&"focus_calm",
	&"reminder_attention",
]

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	_expect(
		main.developer_menu.get_item_index(
			BEHAVIOR_PREVIEW_MENU_ID
		) >= 0,
		"Developer menu must expose one behavior preview entry."
	)
	_expect(
		main.behavior_preview_window != null
		and not main.behavior_preview_window.exclusive
		and main.behavior_preview_buttons.size() == BEHAVIOR_IDS.size(),
		"Behavior preview must use a non-blocking six-action window."
	)

	main._handle_menu_item(BEHAVIOR_PREVIEW_MENU_ID)
	await process_frame
	_expect(
		main.behavior_preview_window.visible,
		"Behavior preview menu entry must open its window."
	)
	main._apply_scale(3.0, false)
	main._open_behavior_preview()
	await process_frame
	var preview_screen: int = main._settings_window_screen(
		main.behavior_preview_window
	)
	var usable_rect := DisplayServer.screen_get_usable_rect(preview_screen)
	var has_usable_rect := (
		usable_rect.size.x > 0 and usable_rect.size.y > 0
	)
	_expect(
		main.behavior_preview_window.content_scale_size
			== Vector2i(440, 470)
		and (
			not has_usable_rect
			or (
				main.behavior_preview_window.size.x
					<= usable_rect.size.x
				and main.behavior_preview_window.size.y
					<= usable_rect.size.y
			)
		),
		(
			"Behavior preview must scale without exceeding the usable screen "
			+ "(content=%s size=%s usable=%s)."
			% [
				main.behavior_preview_window.content_scale_size,
				main.behavior_preview_window.size,
				usable_rect.size,
			]
		)
	)

	main._select_pet(&"leo", false)
	for behavior_id in BEHAVIOR_IDS:
		var button: Button = main.behavior_preview_buttons[behavior_id]
		_expect(
			not button.disabled,
			"Leo's complete profile must enable %s preview."
			% behavior_id
		)
		button.pressed.emit()
		_expect(
			main.pet.get_current_behavior_id() == behavior_id,
			"Preview button must start %s immediately." % behavior_id
		)

	main._select_pet(&"bobo", false)
	for behavior_id in BEHAVIOR_IDS:
		var button: Button = main.behavior_preview_buttons[behavior_id]
		_expect(
			button.disabled,
			"Missing Bobo behavior %s must be disabled safely."
			% behavior_id
		)

	main.settings.language = "zh_CN"
	main._refresh_localized_ui()
	var menu_index: int = main.developer_menu.get_item_index(
		BEHAVIOR_PREVIEW_MENU_ID
	)
	_expect(
		main.behavior_preview_window.title == "宠物动作预览"
		and main.behavior_preview_buttons[&"mouse"].text == "鼠标活动",
		"Behavior preview window must refresh in Chinese."
	)
	_expect(
		main.developer_menu.get_item_text(menu_index) == "动作预览…",
		"Behavior preview developer entry must refresh in Chinese."
	)

	main.behavior_preview_window.hide()
	main.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("Behavior preview integration self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
