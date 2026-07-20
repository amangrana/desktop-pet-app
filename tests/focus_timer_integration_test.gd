extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const TimerManagerScript := preload("res://src/timers/timer_manager.gd")
const DEV_FOCUS_MENU_ID := 45
const DEV_BREAK_MENU_ID := 46
const CANCEL_AUTO_TRANSITION_MENU_ID := 47
const TIMER_STATUS_MENU_ID := 40
const FOCUS_SUBMENU_MENU_ID := 1
const START_FOCUS_MENU_ID := 41

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	_expect(
		main.context_menu.get_item_count() <= 10,
		"top-level context menu must stay compact"
	)
	_expect(
		main.context_menu.get_item_index(FOCUS_SUBMENU_MENU_ID) >= 0,
		"top-level context menu must expose live focus status"
	)
	_expect(
		not main.context_menu.prefer_native_menu,
		"context menu must remain Godot-driven for live timer updates"
	)
	_expect(
		main.context_menu.get_item_index(START_FOCUS_MENU_ID) < 0,
		"focus commands must not remain in the top-level menu"
	)
	_expect(
		main.focus_menu.get_item_index(START_FOCUS_MENU_ID) >= 0,
		"focus submenu must contain the normal focus command"
	)
	_expect(
		main.developer_menu.get_item_index(DEV_FOCUS_MENU_ID) >= 0,
		"developer submenu must expose the one-second focus option"
	)
	_expect(
		main.developer_menu.get_item_index(DEV_BREAK_MENU_ID) >= 0,
		"developer submenu must expose the one-second break option"
	)
	_expect(
		main.pet_definitions.size() == 4
		and main.pet_menu_id_to_pet_id.values().has(&"leo")
		and main.pet_menu_id_to_pet_id.values().has(&"bobo")
		and main.pet_menu_id_to_pet_id.values().has(&"milo")
		and main.pet_menu_id_to_pet_id.values().has(&"mable"),
		"pet registry and menu must discover Leo, Bobo, Milo, and Mable"
	)
	for submenu in [
		main.focus_menu,
		main.reminder_menu,
		main.activity_menu,
		main.pets_menu,
		main.window_menu,
		main.settings_menu,
		main.developer_menu,
	]:
		_expect(
			not submenu.prefer_native_menu,
			"every submenu must remain rectangular and Godot-driven"
		)
	_test_focus_hotspot(main, &"leo")
	_test_focus_hotspot(main, &"bobo")
	_test_focus_hotspot(main, &"milo")
	_test_focus_hotspot(main, &"mable")
	main._select_pet(&"leo", false)
	main._hide_notification()

	main._start_timer(TimerManagerScript.Kind.FOCUS, 5)
	main.context_menu.popup()
	await process_frame
	var focus_title_index: int = main.context_menu.get_item_index(
		FOCUS_SUBMENU_MENU_ID
	)
	var first_title: String = main.context_menu.get_item_text(
		focus_title_index
	)
	await create_timer(1.3).timeout
	var second_title: String = main.context_menu.get_item_text(
		focus_title_index
	)
	_expect(
		main.context_menu.visible,
		"context menu must stay open while its timer text refreshes"
	)
	_expect(
		first_title != second_title,
		"visible top-level focus status must change once per second"
	)
	main.context_menu.hide()

	main.focus_menu.popup()
	await process_frame
	var timer_status_index: int = main.focus_menu.get_item_index(
		TIMER_STATUS_MENU_ID
	)
	var first_status: String = main.focus_menu.get_item_text(
		timer_status_index
	)
	await create_timer(1.3).timeout
	var second_status: String = main.focus_menu.get_item_text(
		timer_status_index
	)
	_expect(
		main.focus_menu.visible,
		"focus submenu must stay open while its timer text refreshes"
	)
	_expect(
		first_status != second_status,
		"visible focus-submenu countdown must change once per second"
	)
	main.focus_menu.hide()
	main.timer_manager.cancel()

	main._start_timer(TimerManagerScript.Kind.FOCUS, 10)
	_expect(main.timer_manager.pause(), "focus timer must pause through the UI")
	main._save_settings()
	main.shutting_down = true
	main.queue_free()
	await process_frame

	main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	_expect(
		main.timer_manager.state == TimerManagerScript.State.PAUSED,
		"paused focus timer must restore from local settings"
	)
	_expect(
		main.timer_manager.remaining_seconds() == 10,
		"restored paused timer must preserve its remaining time"
	)
	main.timer_manager.cancel()

	main.auto_break_delay_seconds = 1.0
	main._start_timer(TimerManagerScript.Kind.FOCUS, 1)
	await create_timer(1.2).timeout

	_expect(
		main.timer_manager.state == TimerManagerScript.State.WAITING_NEXT,
		"one-second focus timer must wait for its break"
	)
	_expect(
		main.timer_manager.next_kind == TimerManagerScript.Kind.BREAK,
		"completed focus must point to a break"
	)
	_expect(
		main.notification_panel.visible,
		"focus completion must show the pet notification bubble"
	)
	_expect(
		"Break starts" in main.notification_label.text,
		"focus completion bubble must show the auto-break countdown"
	)
	_expect(
		main._has_auto_transition(),
		"focus completion must schedule its automatic break"
	)
	var pending_break_deadline: float = main.auto_transition_deadline_unix
	main._handle_pet_tap(
		main.pet.to_global(main.pet.get_focus_hotspot_centers()[0])
	)
	_expect(
		main.timer_manager.state == TimerManagerScript.State.WAITING_NEXT
		and main.timer_manager.next_kind == TimerManagerScript.Kind.BREAK,
		"paw tap while waiting for break must not skip the break"
	)
	_expect(
		is_equal_approx(
			main.auto_transition_deadline_unix,
			pending_break_deadline
		),
		"paw tap while waiting for break must not restart its countdown"
	)
	main._handle_menu_item(CANCEL_AUTO_TRANSITION_MENU_ID)
	_expect(
		not main._has_auto_transition(),
		"menu action must cancel automatic break start"
	)
	_expect(
		main.timer_manager.state == TimerManagerScript.State.WAITING_NEXT,
		"canceling auto-start must keep the next stage available"
	)
	main._save_settings()
	main.shutting_down = true
	main.queue_free()
	await process_frame

	main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	_expect(
		main.timer_manager.state == TimerManagerScript.State.WAITING_NEXT,
		"waiting-next state must persist across restart"
	)
	_expect(
		main.timer_manager.next_kind == TimerManagerScript.Kind.BREAK,
		"restored waiting state must still point to a break"
	)
	_expect(
		not main._has_auto_transition(),
		"automatic countdown must not resume after restart"
	)
	main.auto_break_delay_seconds = 1.0

	main._begin_auto_break_countdown()
	main.auto_transition_deadline_unix = (
		Time.get_unix_time_from_system()
		- main.AUTO_TRANSITION_LATE_GRACE_SECONDS
		- 1.0
	)
	main._handle_auto_transition_tick()
	_expect(
		main.timer_manager.state == TimerManagerScript.State.WAITING_NEXT,
		"a stale countdown must not auto-start after a long absence"
	)
	_expect(
		not main._has_auto_transition(),
		"stale auto-start must fall back to manual confirmation"
	)

	main._start_timer(TimerManagerScript.Kind.FOCUS, 1)
	await create_timer(2.4).timeout
	_expect(
		main.timer_manager.state == TimerManagerScript.State.RUNNING,
		"active countdown must automatically start the break"
	)
	_expect(
		main.timer_manager.kind == TimerManagerScript.Kind.BREAK,
		"automatic next stage after focus must be a break"
	)
	main.timer_manager.cancel()

	main._handle_menu_item(DEV_BREAK_MENU_ID)
	await create_timer(1.2).timeout
	_expect(
		main.timer_manager.state == TimerManagerScript.State.WAITING_NEXT,
		"one-second break timer must wait for the next focus"
	)
	_expect(
		main.timer_manager.next_kind == TimerManagerScript.Kind.FOCUS,
		"completed break must point to focus without auto-starting it"
	)
	_expect(
		main.notification_panel.visible,
		"break completion must show the pet notification bubble"
	)
	_expect(
		"Break complete" in main.notification_label.text,
		"completion bubble must explain that break finished"
	)
	await create_timer(1.2).timeout
	_expect(
		main.timer_manager.state == TimerManagerScript.State.WAITING_NEXT,
		"break completion must not automatically start focus"
	)
	main._handle_pet_tap(
		main.pet.to_global(main.pet.get_focus_hotspot_centers()[0])
	)
	_expect(
		main.timer_manager.state == TimerManagerScript.State.RUNNING
		and main.timer_manager.kind == TimerManagerScript.Kind.FOCUS,
		"paw tap after break must start the next focus"
	)
	main.timer_manager.cancel()

	main.shutting_down = true
	if _failed:
		quit(1)
		return
	print("Focus timer integration self-test passed.")
	quit(0)


func _test_focus_hotspot(main, pet_id: StringName) -> void:
	_expect(
		main._select_pet(pet_id, false),
		"test pet must be selectable: %s" % pet_id
	)
	_expect(
		main.pet.has_focus_hotspot(),
		"pet must define a focus hotspot: %s" % pet_id
	)

	var centers: PackedVector2Array = main.pet.get_focus_hotspot_centers()
	var radius: float = main.pet.get_focus_hotspot_radius()
	_expect(
		centers.size() == 2,
		"pet must define both front-paw hotspots: %s" % pet_id
	)
	_test_edge_clamping(main, pet_id)
	main._handle_pet_tap(
		main.pet.to_global(Vector2(0, -100))
	)
	_expect(
		main.timer_manager.state == TimerManagerScript.State.IDLE,
		"ordinary pet click must not start focus: %s" % pet_id
	)

	for center in centers:
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = main.pet.to_global(center)

		main.dragging = true
		main.drag_moved = true
		main._handle_mouse_button(release)
		_expect(
			main.timer_manager.state == TimerManagerScript.State.IDLE,
			"drag release over a paw must not start focus: %s" % pet_id
		)

		main.dragging = true
		main.drag_moved = false
		main._handle_mouse_button(release)
		_expect(
			main.timer_manager.state == TimerManagerScript.State.RUNNING,
			"short front-paw tap must start focus: %s" % pet_id
		)
		_expect(
			main.timer_manager.kind == TimerManagerScript.Kind.FOCUS,
			"front-paw quick action must start focus: %s" % pet_id
		)
		_expect(
			"Focus started" in main.notification_label.text,
			"front-paw tap must confirm focus start: %s" % pet_id
		)
		var original_end_unix: float = main.timer_manager.end_unix
		main._handle_pet_tap(main.pet.to_global(center))
		_expect(
			main.timer_manager.state == TimerManagerScript.State.RUNNING
			and main.timer_manager.kind == TimerManagerScript.Kind.FOCUS,
			"paw tap during focus must keep the current stage: %s" % pet_id
		)
		_expect(
			is_equal_approx(main.timer_manager.end_unix, original_end_unix),
			"paw tap during focus must not restart its deadline: %s" % pet_id
		)
		main.timer_manager.cancel()


func _test_edge_clamping(main, pet_id: StringName) -> void:
	var usable := Rect2i(0, 0, 1920, 1080)
	var window_size: Vector2i = main.get_window().size
	var visible_bounds: Rect2 = main.pet.get_visible_bounds()
	_expect(
		visible_bounds.size.x < main.pet.definition.display_size.x
		and visible_bounds.size.y < main.pet.definition.display_size.y,
		"cached edge bounds must exclude transparent texture padding: %s"
		% pet_id
	)
	var content_bounds: Rect2i = main._pet_content_bounds(window_size)
	var far := 1000000

	var left_position: Vector2i = main._clamp_content_to_usable_rect(
		Vector2i(-far, usable.position.y),
		content_bounds,
		usable
	)
	var right_position: Vector2i = main._clamp_content_to_usable_rect(
		Vector2i(far, usable.position.y),
		content_bounds,
		usable
	)
	var top_position: Vector2i = main._clamp_content_to_usable_rect(
		Vector2i(usable.position.x, -far),
		content_bounds,
		usable
	)
	var bottom_position: Vector2i = main._clamp_content_to_usable_rect(
		Vector2i(usable.position.x, far),
		content_bounds,
		usable
	)

	_expect(
		left_position.x + content_bounds.position.x == usable.position.x,
		"pet content must reach the left screen edge: %s" % pet_id
	)
	_expect(
		right_position.x + content_bounds.end.x == usable.end.x,
		"pet content must reach the right screen edge: %s" % pet_id
	)
	_expect(
		top_position.y + content_bounds.position.y == usable.position.y,
		"pet content must reach the top screen edge: %s" % pet_id
	)
	_expect(
		bottom_position.y + content_bounds.end.y == usable.end.y,
		"pet content must reach the bottom screen edge: %s" % pet_id
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Focus timer integration self-test failed: %s" % message)
