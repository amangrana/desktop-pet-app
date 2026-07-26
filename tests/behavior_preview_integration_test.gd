extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const BEHAVIOR_PREVIEW_MENU_ID := 65
const CORE_BEHAVIOR_IDS := [
	&"idle_blink",
	&"click_happy",
	&"keyboard",
	&"mouse",
	&"focus_calm",
	&"reminder_attention",
]
const OPTIONAL_BEHAVIOR_IDS := [
	&"idle_look",
	&"idle_yawn",
	&"idle_stretch",
]

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main._select_pet(&"leo", false)

	_expect(
		main.developer_menu.get_item_index(
			BEHAVIOR_PREVIEW_MENU_ID
		) >= 0,
		"Developer menu must expose one behavior preview entry."
	)
	_expect(
		main.behavior_preview_window != null
		and not main.behavior_preview_window.exclusive
		and main.behavior_preview_buttons.size()
			== CORE_BEHAVIOR_IDS.size() + OPTIONAL_BEHAVIOR_IDS.size()
		and main.behavior_preview_buttons.has(&"idle_look")
		and main.behavior_preview_buttons.has(&"idle_yawn")
		and main.behavior_preview_buttons.has(&"idle_stretch"),
		(
			"Behavior preview must dynamically include Leo's nine "
			+ "configured actions."
		)
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

	for behavior_id in CORE_BEHAVIOR_IDS:
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
	for behavior_id in OPTIONAL_BEHAVIOR_IDS:
		var button: Button = main.behavior_preview_buttons[behavior_id]
		button.pressed.emit()
		_expect(
			main.pet.get_current_behavior_id() == behavior_id,
			"Leo's optional %s must be previewable." % behavior_id
		)

	main._select_pet(&"bobo", false)
	_expect(
		main.behavior_preview_buttons.size()
			== CORE_BEHAVIOR_IDS.size() + OPTIONAL_BEHAVIOR_IDS.size()
		and main.behavior_preview_buttons.has(&"idle_look")
		and main.behavior_preview_buttons.has(&"idle_yawn")
		and main.behavior_preview_buttons.has(&"idle_stretch"),
		"Bobo's package must expose all nine configured actions."
	)
	for behavior_id in CORE_BEHAVIOR_IDS:
		var button: Button = main.behavior_preview_buttons[behavior_id]
		_expect(
			not button.disabled,
			"Bobo's complete profile must enable %s preview."
			% behavior_id
		)
		button.pressed.emit()
		_expect(
			main.pet.get_current_behavior_id() == behavior_id,
			"Bobo preview must start %s immediately." % behavior_id
		)
	for behavior_id in OPTIONAL_BEHAVIOR_IDS:
		var button: Button = main.behavior_preview_buttons[behavior_id]
		button.pressed.emit()
		_expect(
			main.pet.get_current_behavior_id() == behavior_id,
			"Bobo optional preview must start %s." % behavior_id
		)

	main._select_pet(&"mable", false)
	_expect(
		main.behavior_preview_buttons.size()
			== CORE_BEHAVIOR_IDS.size() + OPTIONAL_BEHAVIOR_IDS.size()
		and main.behavior_preview_buttons.has(&"idle_look")
		and main.behavior_preview_buttons.has(&"idle_yawn")
		and main.behavior_preview_buttons.has(&"idle_stretch"),
		"Mable's package must expose all nine configured actions."
	)
	for behavior_id in CORE_BEHAVIOR_IDS:
		var button: Button = main.behavior_preview_buttons[behavior_id]
		_expect(
			not button.disabled,
			"Mable's complete profile must enable %s preview."
			% behavior_id
		)
		button.pressed.emit()
		_expect(
			main.pet.get_current_behavior_id() == behavior_id,
			"Mable preview must start %s immediately." % behavior_id
		)
	for behavior_id in OPTIONAL_BEHAVIOR_IDS:
		var button: Button = main.behavior_preview_buttons[behavior_id]
		button.pressed.emit()
		_expect(
			main.pet.get_current_behavior_id() == behavior_id,
			"Mable optional preview must start %s." % behavior_id
		)

	main._select_pet(&"milo", false)
	_expect(
		main.behavior_preview_buttons.size()
			== CORE_BEHAVIOR_IDS.size() + OPTIONAL_BEHAVIOR_IDS.size()
		and main.behavior_preview_buttons.has(&"idle_look")
		and main.behavior_preview_buttons.has(&"idle_yawn")
		and main.behavior_preview_buttons.has(&"idle_stretch"),
		"Milo's package must expose all nine configured actions."
	)
	for behavior_id in CORE_BEHAVIOR_IDS:
		var button: Button = main.behavior_preview_buttons[behavior_id]
		_expect(
			not button.disabled,
			"Milo's complete profile must enable %s preview."
			% behavior_id
		)
		button.pressed.emit()
		_expect(
			main.pet.get_current_behavior_id() == behavior_id,
			"Milo preview must start %s immediately." % behavior_id
		)
	for behavior_id in OPTIONAL_BEHAVIOR_IDS:
		var button: Button = main.behavior_preview_buttons[behavior_id]
		button.pressed.emit()
		_expect(
			main.pet.get_current_behavior_id() == behavior_id,
			"Milo optional preview must start %s." % behavior_id
		)

	_test_stretch_window_shape(main, &"mable")
	_test_stretch_window_shape(main, &"milo")

	main._select_pet(&"leo", false)
	main.settings.language = "zh_CN"
	main._refresh_localized_ui()
	var menu_index: int = main.developer_menu.get_item_index(
		BEHAVIOR_PREVIEW_MENU_ID
	)
	_expect(
		main.behavior_preview_window.title == "宠物动作预览"
		and main.behavior_preview_buttons[&"mouse"].text == "鼠标活动"
		and main.behavior_preview_buttons[&"idle_look"].text
			== "空闲观察"
		and main.behavior_preview_buttons[&"idle_yawn"].text
			== "空闲哈欠"
		and main.behavior_preview_buttons[&"idle_stretch"].text
			== "空闲伸展",
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


func _test_stretch_window_shape(main, pet_id: StringName) -> void:
	main._select_pet(pet_id, false)
	var idle_bounds := _polygon_bounds(
		main.get_window().mouse_passthrough_polygon
	)
	_expect(
		main.pet.preview_behavior(&"idle_stretch"),
		"%s stretch preview must start." % pet_id
	)
	main.pet._process(1.01)
	var stretch_bounds := _polygon_bounds(
		main.get_window().mouse_passthrough_polygon
	)
	_expect(
		stretch_bounds.size.x > idle_bounds.size.x,
		(
			"%s stretch must expand the Windows visible shape "
			+ "(idle=%s stretch=%s)."
		) % [pet_id, idle_bounds, stretch_bounds]
	)
	main.pet._process(2.1)
	var restored_bounds := _polygon_bounds(
		main.get_window().mouse_passthrough_polygon
	)
	_expect(
		restored_bounds == idle_bounds,
		"%s must restore its idle window shape after stretching." % pet_id
	)


func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	if polygon.is_empty():
		return Rect2()
	var minimum := polygon[0]
	var maximum := polygon[0]
	for point in polygon:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
