extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const TimerManagerScript := preload("res://src/timers/timer_manager.gd")

const AMBIENT_CARDS_MENU_ID := 59
const DEV_AMBIENT_CARD_MENU_ID := 64

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	_expect(
		not main.settings.ambient_cards_enabled
		and main.settings_menu.get_item_index(AMBIENT_CARDS_MENU_ID) >= 0,
		"pet info cards must be optional and off by default"
	)
	_expect(
		main.developer_menu.get_item_index(DEV_AMBIENT_CARD_MENU_ID) >= 0,
		"developer menu must expose a passive-card test entry"
	)

	main._handle_menu_item(AMBIENT_CARDS_MENU_ID)
	await process_frame
	_expect(
		main.pet_notes_settings_window.visible,
		"Pet Notes menu must open its dedicated settings window"
	)
	_expect(
		main.pet_notes_settings_window.size == Vector2i(420, 310)
		and main.pet_notes_background.color == Color("#2B2434")
		and main.pet_notes_master_card.has_theme_stylebox_override(
			"panel"
		)
		and main.pet_notes_calendar_card.has_theme_stylebox_override(
			"panel"
		),
		"Pet Notes settings must use the compact card layout"
	)
	_expect(
		main.pet_notes_enabled_check.has_theme_icon_override("unchecked")
		and main.pet_notes_enabled_check.has_theme_icon_override("checked")
		and main.calendar_notes_enabled_check.has_theme_icon_override(
			"unchecked"
		)
		and main.calendar_notes_enabled_check.has_theme_icon_override(
			"checked"
		),
		"Pet Notes checkboxes must use visible high-contrast icons"
	)
	_expect(
		main.pet_notes_enabled_check.get_theme_color("font_color")
		== Color.WHITE
		and main.pet_notes_enabled_check.get_theme_color(
			"font_outline_color"
		) == Color("#352B42")
		and main.pet_notes_enabled_check.get_theme_constant(
			"outline_size"
		) >= 3,
		"Pet Notes checkbox text must remain readable on dark backgrounds"
	)
	main.pet_notes_enabled_check.button_pressed = true
	main.calendar_notes_enabled_check.button_pressed = true
	main.pet_notes_save_button.pressed.emit()
	main.check_in_manager.set_cooldown_seconds(0)
	main.check_in_manager.enqueue_card(
		"integration-1",
		"calendar",
		"Design review starts soon.",
		10
	)
	var first_card_started: bool = main._try_show_check_in()
	await process_frame
	_expect(
		first_card_started,
		"an eligible non-focus card must appear"
	)
	_expect(
		main.ambient_card_active
		and main.notification_panel.visible
		and main.notification_actions.visible
		and main.notification_done_button.visible
		and not main.notification_snooze_button.visible
		and not main.notification_more_button.visible
		and main.notification_done_button.text == "OK (10)",
		"passive card must show only an OK button with countdown"
	)
	_expect(
		main.notification_panel.size == Vector2(264, 102),
		(
			"the first Pet Note must use its final actionable layout; "
			+ "actual size is %s"
			% main.notification_panel.size
		)
	)
	_expect(
		main.notification_panel.mouse_filter == Control.MOUSE_FILTER_STOP
		and Geometry2D.is_point_in_polygon(
			main.notification_panel.position
			+ main.notification_panel.size / 2.0,
			main.get_window().mouse_passthrough_polygon
		),
		"passive card and its button must accept mouse input"
	)
	main.notification_done_button.pressed.emit()
	_expect(
		not main.ambient_card_active
		and not main.notification_panel.visible,
		"OK must close the passive card immediately"
	)

	main.check_in_manager.enqueue_card(
		"integration-2",
		"calendar",
		"Planning starts soon.",
		10
	)
	main._try_show_check_in()
	main.ambient_card_deadline_unix = (
		Time.get_unix_time_from_system() - 0.1
	)
	main._handle_ambient_card_tick()
	_expect(
		not main.ambient_card_active
		and not main.notification_panel.visible,
		"countdown reaching zero must dismiss the card automatically"
	)

	main.check_in_manager.enqueue_card(
		"integration-3",
		"calendar",
		"Focus should defer this card.",
		10
	)
	main._start_timer(TimerManagerScript.Kind.FOCUS, 30)
	_expect(
		not main._try_show_check_in()
		and not main.notification_panel.visible,
		"focus time must suppress passive cards"
	)
	main.timer_manager.cancel()
	var deferred_card_started: bool = main._try_show_check_in()
	await process_frame
	_expect(
		deferred_card_started and main.ambient_card_active,
		"a deferred card may appear after focus ends"
	)
	main._start_timer(TimerManagerScript.Kind.FOCUS, 30)
	_expect(
		not main.ambient_card_active
		and not main.notification_panel.visible,
		"starting focus must close a visible passive card"
	)
	main.timer_manager.cancel()

	main._handle_menu_item(AMBIENT_CARDS_MENU_ID)
	await process_frame
	main.pet_notes_enabled_check.button_pressed = false
	main.calendar_notes_enabled_check.button_pressed = false
	main.pet_notes_save_button.pressed.emit()
	_expect(
		not main.settings.ambient_cards_enabled
		and not main.check_in_manager.is_enabled(),
		"turning pet info cards off must disable the source pipeline"
	)

	main.shutting_down = true
	if _failed:
		quit(1)
		return
	print("Ambient card integration self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Ambient card integration self-test failed: %s" % message)
