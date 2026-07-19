extends Node

const ActivityStatsScript := preload("res://src/Activity/activity_stats.gd")
const InputActivityMonitorScript := preload(
	"res://src/Activity/input_activity_monitor.gd"
)
const WindowsActivityAdapterScript := preload(
	"res://src/platform/windows/windows_activity_adapter.gd"
)
const TimerManagerScript := preload("res://src/timers/timer_manager.gd")

const BASE_WINDOW_SIZE := 360
const DEFAULT_PET_ID := &"leo"
const FOCUS_DURATION_SECONDS := 25 * 60
const BREAK_DURATION_SECONDS := 5 * 60
const DEV_FOCUS_DURATION_SECONDS := 1
const DEV_BREAK_DURATION_SECONDS := 1
const AUTO_BREAK_DELAY_SECONDS := 5.0
const AUTO_TRANSITION_LATE_GRACE_SECONDS := 2.0

const MENU_ALWAYS_ON_TOP := 10
const MENU_ACTIVITY_SENSING := 15
const MENU_ACTIVITY_COUNTS := 16
const MENU_CLEAR_ACTIVITY := 17
const MENU_ACTIVITY_STATUS := 18
const MENU_SCALE_75 := 30
const MENU_SCALE_100 := 31
const MENU_SCALE_125 := 32
const MENU_SCALE_150 := 33
const MENU_TIMER_STATUS := 40
const MENU_START_FOCUS := 41
const MENU_START_BREAK := 42
const MENU_PAUSE_RESUME_TIMER := 43
const MENU_CANCEL_TIMER := 44
const MENU_DEV_FOCUS_1S := 45
const MENU_DEV_BREAK_1S := 46
const MENU_CANCEL_AUTO_TRANSITION := 47
const MENU_EXIT := 90
const MENU_PET_BASE := 1000

const SETTINGS_FILE := "user://prototype-settings.cfg"

@onready var pet: PetVisual = $PetVisual

var context_menu: PopupMenu
var hint_label: Label
var notification_panel: PanelContainer
var notification_label: Label
var notification_timer: Timer
var auto_transition_timer: Timer
var activity_monitor
var activity_stats
var activity_adapter
var timer_manager
var pet_definitions: Array[PetDefinition] = []
var pet_menu_id_to_pet_id: Dictionary = {}
var settings := {
	"always_on_top": true,
	"display_scale": 1.0,
	"selected_pet_id": String(DEFAULT_PET_ID),
	"activity_sensing_enabled": false,
	"activity_consent_shown": false,
	"timer_snapshot": {},
	"has_saved_position": false,
	"window_position": Vector2i.ZERO,
}

var dragging := false
var drag_moved := false
var drag_offset := Vector2i.ZERO
var drag_start := Vector2i.ZERO
var shutting_down := false
var restoring_timer := false
var auto_transition_deadline_unix := 0.0
var auto_break_delay_seconds := AUTO_BREAK_DELAY_SECONDS


func _ready() -> void:
	_load_settings()
	_build_activity_pipeline()
	_build_timer_pipeline()
	_load_pet_definitions()
	if pet_definitions.is_empty():
		push_error("No valid pet definitions were found.")
		get_tree().quit()
		return
	_select_initial_pet()
	_configure_window()
	_build_hud()
	_build_context_menu()
	_apply_scale(settings.display_scale, false)
	_restore_or_choose_window_position()
	_restore_timer()
	_update_menu_checks()
	_start_preview_capture_if_requested()


func _build_activity_pipeline() -> void:
	activity_stats = ActivityStatsScript.new()
	activity_stats.changed.connect(_update_activity_menu)

	activity_monitor = InputActivityMonitorScript.new()
	activity_monitor.activity_batch_ready.connect(_handle_activity_batch)
	activity_monitor.listening_changed.connect(_handle_listening_changed)
	add_child(activity_monitor)

	activity_adapter = WindowsActivityAdapterScript.new()
	activity_adapter.aggregate_received.connect(
		activity_monitor.submit_aggregate
	)
	activity_adapter.state_changed.connect(_handle_activity_adapter_state)
	add_child(activity_adapter)

	activity_monitor.set_listening(settings.activity_sensing_enabled)


func _build_timer_pipeline() -> void:
	timer_manager = TimerManagerScript.new()
	timer_manager.changed.connect(_handle_timer_changed)
	timer_manager.tick.connect(_handle_timer_tick)
	timer_manager.completed.connect(_handle_timer_completed)
	add_child(timer_manager)

	auto_transition_timer = Timer.new()
	auto_transition_timer.wait_time = 0.1
	auto_transition_timer.timeout.connect(_handle_auto_transition_tick)
	add_child(auto_transition_timer)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if (
			event.pressed
			and not event.echo
			and event.ctrl_pressed
			and event.keycode == KEY_Q
		):
			_shutdown()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and dragging:
		var mouse_position := DisplayServer.mouse_get_position()
		if (mouse_position - drag_start).length_squared() > 25:
			drag_moved = true

		var window := get_window()
		window.position = _clamp_to_visible_screen(
			mouse_position - drag_offset,
			window.size
		)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown()


func _exit_tree() -> void:
	if not shutting_down:
		_save_settings()


func _load_pet_definitions() -> void:
	pet_definitions = PetRegistry.discover()


func _select_initial_pet() -> void:
	var saved_pet_id := StringName(str(settings.selected_pet_id))
	if _select_pet(saved_pet_id, false):
		return
	if _select_pet(DEFAULT_PET_ID, false):
		return
	_select_pet(pet_definitions[0].pet_id, false)


func _select_pet(pet_id: StringName, save := true) -> bool:
	var definition := PetRegistry.find_by_id(pet_definitions, pet_id)
	if definition == null:
		return false

	pet.set_definition(definition)
	settings.selected_pet_id = String(definition.pet_id)

	var window := get_window()
	window.title = "%s - Desktop Pet Prototype" % definition.display_name
	if window.size.x > 0 and window.size.y > 0:
		_update_mouse_passthrough(window.size)
		window.position = _clamp_to_visible_screen(
			window.position,
			window.size
		)
	_update_menu_checks()

	if save:
		_save_settings()
	return true


func _configure_window() -> void:
	var window := get_window()
	window.title = "%s - Desktop Pet Prototype" % pet.get_display_name()
	window.borderless = true
	window.transparent = true
	window.always_on_top = settings.always_on_top
	window.unresizable = true
	get_viewport().transparent_bg = true


func _build_hud() -> void:
	hint_label = Label.new()
	hint_label.text = "Right-click: menu   Ctrl+Q: exit"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.78))
	hint_label.add_theme_color_override("font_outline_color", Color("#352B42"))
	hint_label.add_theme_constant_override("outline_size", 4)
	hint_label.add_theme_font_size_override("font_size", 12)
	add_child(hint_label)

	notification_panel = PanelContainer.new()
	notification_panel.visible = false
	notification_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_panel.z_index = 100
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color("#FFF7E8")
	bubble_style.border_color = Color("#5C466F")
	bubble_style.set_border_width_all(2)
	bubble_style.set_corner_radius_all(12)
	bubble_style.shadow_color = Color(0.12, 0.08, 0.16, 0.28)
	bubble_style.shadow_size = 5
	bubble_style.content_margin_left = 10.0
	bubble_style.content_margin_right = 10.0
	bubble_style.content_margin_top = 7.0
	bubble_style.content_margin_bottom = 7.0
	notification_panel.add_theme_stylebox_override("panel", bubble_style)
	add_child(notification_panel)

	notification_label = Label.new()
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notification_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_label.add_theme_color_override("font_color", Color("#352B42"))
	notification_label.add_theme_font_size_override("font_size", 14)
	notification_panel.add_child(notification_label)

	notification_timer = Timer.new()
	notification_timer.one_shot = true
	notification_timer.timeout.connect(_hide_notification)
	add_child(notification_timer)


func _build_context_menu() -> void:
	# A separate Godot subwindow stays rectangular outside the transparent
	# pet window while still letting the main loop refresh live menu text.
	get_viewport().gui_embed_subwindows = false
	context_menu = PopupMenu.new()
	context_menu.prefer_native_menu = false
	context_menu.force_native = false
	context_menu.transparent = false
	context_menu.transient = true
	context_menu.unresizable = true
	context_menu.add_check_item("Always on top", MENU_ALWAYS_ON_TOP)
	context_menu.add_separator("Activity")
	context_menu.add_check_item(
		"Activity sensing",
		MENU_ACTIVITY_SENSING
	)
	context_menu.add_item(activity_stats.summary(), MENU_ACTIVITY_COUNTS)
	context_menu.set_item_disabled(
		context_menu.get_item_index(MENU_ACTIVITY_COUNTS),
		true
	)
	context_menu.add_item(
		_activity_source_summary(),
		MENU_ACTIVITY_STATUS
	)
	context_menu.set_item_disabled(
		context_menu.get_item_index(MENU_ACTIVITY_STATUS),
		true
	)
	context_menu.add_item("Clear session activity", MENU_CLEAR_ACTIVITY)
	context_menu.add_separator("Focus")
	context_menu.add_item(_timer_status_summary(), MENU_TIMER_STATUS)
	context_menu.set_item_disabled(
		context_menu.get_item_index(MENU_TIMER_STATUS),
		true
	)
	context_menu.add_item("Start focus — 25 min", MENU_START_FOCUS)
	if OS.has_feature("editor"):
		context_menu.add_item(
			"Start focus — 1 sec (test)",
			MENU_DEV_FOCUS_1S
		)
	context_menu.add_item("Start break — 5 min", MENU_START_BREAK)
	if OS.has_feature("editor"):
		context_menu.add_item(
			"Start break — 1 sec (test)",
			MENU_DEV_BREAK_1S
		)
	context_menu.add_item("Pause timer", MENU_PAUSE_RESUME_TIMER)
	context_menu.add_item("Cancel timer", MENU_CANCEL_TIMER)
	context_menu.add_item(
		"Cancel auto-start",
		MENU_CANCEL_AUTO_TRANSITION
	)
	context_menu.add_separator("Pets")
	for index in pet_definitions.size():
		var definition := pet_definitions[index]
		var menu_id := MENU_PET_BASE + index
		pet_menu_id_to_pet_id[menu_id] = definition.pet_id
		context_menu.add_radio_check_item(
			"Pet: %s" % definition.display_name,
			menu_id
		)
	context_menu.add_separator()
	context_menu.add_check_item("Scale: 75%", MENU_SCALE_75)
	context_menu.add_check_item("Scale: 100%", MENU_SCALE_100)
	context_menu.add_check_item("Scale: 125%", MENU_SCALE_125)
	context_menu.add_check_item("Scale: 150%", MENU_SCALE_150)
	context_menu.add_separator()
	context_menu.add_item("Exit Desktop Pet (Ctrl+Q)", MENU_EXIT)
	context_menu.id_pressed.connect(_handle_menu_item)
	add_child(context_menu)


func _handle_mouse_button(button: InputEventMouseButton) -> void:
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		_update_menu_checks()
		context_menu.position = DisplayServer.mouse_get_position()
		context_menu.popup()
		get_viewport().set_input_as_handled()
		return

	if button.button_index != MOUSE_BUTTON_LEFT:
		return

	if button.pressed:
		dragging = true
		drag_moved = false
		drag_start = DisplayServer.mouse_get_position()
		drag_offset = drag_start - get_window().position
	elif dragging:
		dragging = false
		if not drag_moved:
			_handle_pet_tap(button.position)
		_save_settings()

	get_viewport().set_input_as_handled()


func _handle_pet_tap(viewport_position: Vector2) -> void:
	var local_position := pet.to_local(viewport_position)
	if pet.is_focus_hotspot(local_position):
		_handle_focus_hotspot_tap()
		return
	pet.react_to_click()


func _handle_focus_hotspot_tap() -> void:
	pet.react_to_click()
	if timer_manager == null:
		return

	var can_start_focus: bool = (
		timer_manager.state == TimerManagerScript.State.IDLE
		or (
			timer_manager.state == TimerManagerScript.State.WAITING_NEXT
			and timer_manager.next_kind == TimerManagerScript.Kind.FOCUS
		)
	)
	if can_start_focus:
		_start_timer(
			TimerManagerScript.Kind.FOCUS,
			FOCUS_DURATION_SECONDS
		)
		_show_notification(
			"Focus started — %s" % _format_duration(
				FOCUS_DURATION_SECONDS
			),
			3.0
		)
		return

	if _has_auto_transition():
		notification_timer.stop()
		notification_panel.visible = true
		_update_auto_break_countdown()
		return

	_show_notification(_timer_status_summary(), 3.0)


func _handle_menu_item(id: int) -> void:
	if pet_menu_id_to_pet_id.has(id):
		_select_pet(StringName(pet_menu_id_to_pet_id[id]))
		return

	match id:
		MENU_ALWAYS_ON_TOP:
			settings.always_on_top = not settings.always_on_top
			get_window().always_on_top = settings.always_on_top
		MENU_ACTIVITY_SENSING:
			_toggle_activity_sensing()
			return
		MENU_CLEAR_ACTIVITY:
			activity_stats.clear()
		MENU_START_FOCUS:
			_start_timer(
				TimerManagerScript.Kind.FOCUS,
				FOCUS_DURATION_SECONDS
			)
		MENU_DEV_FOCUS_1S:
			_start_timer(
				TimerManagerScript.Kind.FOCUS,
				DEV_FOCUS_DURATION_SECONDS
			)
		MENU_START_BREAK:
			_start_timer(
				TimerManagerScript.Kind.BREAK,
				BREAK_DURATION_SECONDS
			)
		MENU_DEV_BREAK_1S:
			_start_timer(
				TimerManagerScript.Kind.BREAK,
				DEV_BREAK_DURATION_SECONDS
			)
		MENU_PAUSE_RESUME_TIMER:
			if timer_manager.state == TimerManagerScript.State.RUNNING:
				timer_manager.pause()
			elif timer_manager.state == TimerManagerScript.State.PAUSED:
				timer_manager.resume()
		MENU_CANCEL_TIMER:
			_cancel_auto_transition(false)
			timer_manager.cancel()
			_hide_notification()
		MENU_CANCEL_AUTO_TRANSITION:
			_cancel_auto_transition(true)
		MENU_SCALE_75:
			_apply_scale(0.75)
		MENU_SCALE_100:
			_apply_scale(1.0)
		MENU_SCALE_125:
			_apply_scale(1.25)
		MENU_SCALE_150:
			_apply_scale(1.5)
		MENU_EXIT:
			_shutdown()
			return

	_update_menu_checks()
	_save_settings()


func _apply_scale(scale_factor: float, save := true) -> void:
	settings.display_scale = clampf(scale_factor, 0.75, 1.5)
	var size := roundi(BASE_WINDOW_SIZE * settings.display_scale)
	var window_size := Vector2i(size, size)
	var window := get_window()

	window.size = window_size
	pet.scale = Vector2.ONE * settings.display_scale
	pet.position = Vector2(
		window_size.x / 2.0,
		window_size.y / 2.0 - 2 * settings.display_scale
	)

	hint_label.position = Vector2(0, window_size.y - 30 * settings.display_scale)
	hint_label.size = Vector2(window_size.x, 22 * settings.display_scale)
	notification_panel.position = Vector2(62, 52) * settings.display_scale
	notification_panel.size = Vector2(236, 60) * settings.display_scale
	notification_label.add_theme_font_size_override(
		"font_size",
		roundi(14 * settings.display_scale)
	)

	_update_mouse_passthrough(window_size)
	window.position = _clamp_to_visible_screen(window.position, window_size)
	_update_menu_checks()

	if save:
		_save_settings()


func _update_mouse_passthrough(window_size: Vector2i) -> void:
	var center := Vector2(
		window_size.x / 2.0,
		window_size.y / 2.0 - 2 * settings.display_scale
	)
	var source_polygon := pet.get_interaction_polygon()
	var scaled_polygon := PackedVector2Array()
	for point in source_polygon:
		scaled_polygon.append(center + point * settings.display_scale)
	get_window().mouse_passthrough_polygon = scaled_polygon


func _restore_or_choose_window_position() -> void:
	var window := get_window()
	if settings.has_saved_position:
		window.position = _clamp_to_visible_screen(settings.window_position, window.size)
		return

	var usable := DisplayServer.screen_get_usable_rect(0)
	window.position = usable.end - window.size - Vector2i(24, 24)


func _clamp_to_visible_screen(position: Vector2i, window_size: Vector2i) -> Vector2i:
	var selected_usable := DisplayServer.screen_get_usable_rect(0)
	var largest_overlap := -1
	var content_bounds := _pet_content_bounds(window_size)
	var content_position := position + content_bounds.position
	var content_end := position + content_bounds.end

	for screen in DisplayServer.get_screen_count():
		var usable := DisplayServer.screen_get_usable_rect(screen)
		var overlap_width := maxi(
			0,
			mini(content_end.x, usable.end.x)
			- maxi(content_position.x, usable.position.x)
		)
		var overlap_height := maxi(
			0,
			mini(content_end.y, usable.end.y)
			- maxi(content_position.y, usable.position.y)
		)
		var overlap_area := overlap_width * overlap_height
		if overlap_area > largest_overlap:
			largest_overlap = overlap_area
			selected_usable = usable

	return _clamp_content_to_usable_rect(
		position,
		content_bounds,
		selected_usable
	)


func _clamp_content_to_usable_rect(
	position: Vector2i,
	content_bounds: Rect2i,
	usable: Rect2i
) -> Vector2i:
	var minimum_x := usable.position.x - content_bounds.position.x
	var minimum_y := usable.position.y - content_bounds.position.y
	var maximum_x := maxi(
		minimum_x,
		usable.end.x - content_bounds.end.x
	)
	var maximum_y := maxi(
		minimum_y,
		usable.end.y - content_bounds.end.y
	)
	return Vector2i(
		clampi(position.x, minimum_x, maximum_x),
		clampi(position.y, minimum_y, maximum_y)
	)


func _pet_content_bounds(window_size: Vector2i) -> Rect2i:
	var visible_bounds := pet.get_visible_bounds()
	if visible_bounds.size.x <= 0.0 or visible_bounds.size.y <= 0.0:
		return Rect2i(Vector2i.ZERO, window_size)

	var center := Vector2(
		window_size.x / 2.0,
		window_size.y / 2.0 - 2 * settings.display_scale
	)
	var minimum: Vector2 = (
		center + visible_bounds.position * settings.display_scale
	)
	var maximum: Vector2 = (
		center + visible_bounds.end * settings.display_scale
	)

	var integer_minimum := Vector2i(
		floori(minimum.x),
		floori(minimum.y)
	)
	var integer_maximum := Vector2i(
		ceili(maximum.x),
		ceili(maximum.y)
	)
	return Rect2i(
		integer_minimum,
		integer_maximum - integer_minimum
	)


func _update_menu_checks() -> void:
	if context_menu == null:
		return

	_set_menu_checked(MENU_ALWAYS_ON_TOP, settings.always_on_top)
	_set_menu_checked(MENU_ACTIVITY_SENSING, activity_monitor.listening)
	context_menu.set_item_disabled(
		context_menu.get_item_index(MENU_CLEAR_ACTIVITY),
		activity_stats.is_empty()
	)
	_set_menu_checked(MENU_SCALE_75, is_equal_approx(settings.display_scale, 0.75))
	_set_menu_checked(MENU_SCALE_100, is_equal_approx(settings.display_scale, 1.0))
	_set_menu_checked(MENU_SCALE_125, is_equal_approx(settings.display_scale, 1.25))
	_set_menu_checked(MENU_SCALE_150, is_equal_approx(settings.display_scale, 1.5))
	_update_timer_menu()
	for menu_id in pet_menu_id_to_pet_id:
		_set_menu_checked(
			int(menu_id),
			pet.get_pet_id() == pet_menu_id_to_pet_id[menu_id]
		)


func _update_timer_menu() -> void:
	if context_menu == null or timer_manager == null:
		return

	_set_menu_text(MENU_TIMER_STATUS, _timer_status_summary())
	var is_idle: bool = timer_manager.state == TimerManagerScript.State.IDLE
	var is_waiting: bool = (
		timer_manager.state == TimerManagerScript.State.WAITING_NEXT
	)
	var can_start: bool = is_idle or is_waiting
	_set_menu_disabled(MENU_START_FOCUS, not can_start)
	_set_menu_disabled(MENU_START_BREAK, not can_start)
	_set_menu_disabled(MENU_DEV_FOCUS_1S, not can_start)
	_set_menu_disabled(MENU_DEV_BREAK_1S, not can_start)
	_set_menu_disabled(
		MENU_PAUSE_RESUME_TIMER,
		timer_manager.state != TimerManagerScript.State.RUNNING
		and timer_manager.state != TimerManagerScript.State.PAUSED
	)
	_set_menu_disabled(
		MENU_CANCEL_TIMER,
		is_idle
	)
	_set_menu_disabled(
		MENU_CANCEL_AUTO_TRANSITION,
		not _has_auto_transition()
	)

	if timer_manager.state == TimerManagerScript.State.PAUSED:
		_set_menu_text(MENU_PAUSE_RESUME_TIMER, "Resume timer")
	else:
		_set_menu_text(MENU_PAUSE_RESUME_TIMER, "Pause timer")


func _timer_status_summary() -> String:
	if timer_manager == null or timer_manager.state == TimerManagerScript.State.IDLE:
		return "Timer: idle"

	if timer_manager.state == TimerManagerScript.State.WAITING_NEXT:
		var completed_name := _timer_kind_name(timer_manager.kind)
		var next_name := _timer_kind_name(timer_manager.next_kind).to_lower()
		if _has_auto_transition():
			return "%s complete — %s in %s" % [
				completed_name,
				next_name,
				_format_duration(_auto_transition_remaining_seconds()),
			]
		return "%s complete — start %s when ready" % [
			completed_name,
			next_name,
		]

	var kind_name := (
		"Focus"
		if timer_manager.kind == TimerManagerScript.Kind.FOCUS
		else "Break"
	)
	var state_suffix := (
		" paused"
		if timer_manager.state == TimerManagerScript.State.PAUSED
		else ""
	)
	return "%s%s: %s" % [
		kind_name,
		state_suffix,
		_format_duration(timer_manager.remaining_seconds()),
	]


func _timer_kind_name(timer_kind: int) -> String:
	if timer_kind == TimerManagerScript.Kind.FOCUS:
		return "Focus"
	if timer_kind == TimerManagerScript.Kind.BREAK:
		return "Break"
	return "Timer"


func _format_duration(total_seconds: int) -> String:
	var safe_seconds := maxi(0, total_seconds)
	return "%02d:%02d" % [
		safe_seconds / 60,
		safe_seconds % 60,
	]


func _start_timer(kind: int, duration_seconds: int) -> void:
	_cancel_auto_transition(false)
	if timer_manager.start_timer(kind, duration_seconds):
		_hide_notification()


func _restore_timer() -> void:
	restoring_timer = true
	timer_manager.restore(settings.timer_snapshot)
	restoring_timer = false
	_update_timer_menu()


func _handle_timer_changed() -> void:
	settings.timer_snapshot = timer_manager.snapshot()
	if (
		timer_manager.state != TimerManagerScript.State.WAITING_NEXT
		or timer_manager.next_kind != TimerManagerScript.Kind.BREAK
	):
		_cancel_auto_transition(false)
	pet.set_focus_mode(
		timer_manager.state == TimerManagerScript.State.RUNNING
		and timer_manager.kind == TimerManagerScript.Kind.FOCUS
	)
	_update_timer_menu()
	if context_menu != null:
		_save_settings()


func _handle_timer_tick(_remaining_seconds: int) -> void:
	_update_timer_menu()


func _handle_timer_completed(kind: int) -> void:
	pet.react_to_reminder()
	if kind == TimerManagerScript.Kind.FOCUS:
		if restoring_timer:
			_show_notification(
				"Focus complete! Start your break when ready.",
				10.0
			)
		else:
			_begin_auto_break_countdown()
	elif kind == TimerManagerScript.Kind.BREAK:
		_show_notification(
			"Break complete! Ready for another focus session?",
			10.0
		)


func _begin_auto_break_countdown() -> void:
	_cancel_auto_transition(false)
	auto_transition_deadline_unix = (
		Time.get_unix_time_from_system()
		+ maxf(0.1, auto_break_delay_seconds)
	)
	auto_transition_timer.start()
	notification_timer.stop()
	notification_panel.visible = true
	_update_auto_break_countdown()


func _handle_auto_transition_tick() -> void:
	if not _has_auto_transition():
		_cancel_auto_transition(false)
		return

	var remaining := _auto_transition_remaining_seconds()
	if remaining > 0:
		_update_auto_break_countdown()
		return

	var lateness := (
		Time.get_unix_time_from_system()
		- auto_transition_deadline_unix
	)
	if lateness <= AUTO_TRANSITION_LATE_GRACE_SECONDS:
		_cancel_auto_transition(false)
		_start_timer(
			TimerManagerScript.Kind.BREAK,
			BREAK_DURATION_SECONDS
		)
		return

	_cancel_auto_transition(true)


func _update_auto_break_countdown() -> void:
	var remaining := _auto_transition_remaining_seconds()
	notification_label.text = (
		"Focus complete! Break starts in %d second%s."
		% [
			remaining,
			"" if remaining == 1 else "s",
		]
	)
	_update_timer_menu()


func _cancel_auto_transition(show_ready_message: bool) -> void:
	auto_transition_deadline_unix = 0.0
	if auto_transition_timer != null:
		auto_transition_timer.stop()
	if (
		show_ready_message
		and timer_manager != null
		and timer_manager.state == TimerManagerScript.State.WAITING_NEXT
		and timer_manager.next_kind == TimerManagerScript.Kind.BREAK
	):
		_show_notification(
			"Focus complete! Start your break when ready.",
			10.0
		)
	_update_timer_menu()


func _has_auto_transition() -> bool:
	return (
		auto_transition_deadline_unix > 0.0
		and timer_manager != null
		and timer_manager.state == TimerManagerScript.State.WAITING_NEXT
		and timer_manager.next_kind == TimerManagerScript.Kind.BREAK
	)


func _auto_transition_remaining_seconds() -> int:
	if auto_transition_deadline_unix <= 0.0:
		return 0
	return maxi(
		0,
		ceili(
			auto_transition_deadline_unix
			- Time.get_unix_time_from_system()
		)
	)


func _show_notification(message: String, duration_seconds: float) -> void:
	notification_label.text = message
	notification_panel.visible = true
	notification_timer.start(maxf(1.0, duration_seconds))


func _hide_notification() -> void:
	if notification_timer != null:
		notification_timer.stop()
	if notification_panel != null:
		notification_panel.visible = false


func _update_activity_menu() -> void:
	if context_menu == null:
		return

	var counts_index := context_menu.get_item_index(MENU_ACTIVITY_COUNTS)
	if counts_index >= 0:
		context_menu.set_item_text(counts_index, activity_stats.summary())
	var status_index := context_menu.get_item_index(MENU_ACTIVITY_STATUS)
	if status_index >= 0:
		context_menu.set_item_text(status_index, _activity_source_summary())
	_update_menu_checks()


func _activity_source_summary() -> String:
	if activity_adapter == null:
		return "Activity source: unavailable"
	return "Activity source: %s" % activity_adapter.status_message


func _toggle_activity_sensing() -> void:
	var enable: bool = not bool(activity_monitor.listening)
	if enable and not settings.activity_consent_shown:
		_request_initial_activity_consent()
		return

	activity_monitor.set_listening(enable)
	settings.activity_sensing_enabled = bool(activity_monitor.listening)
	_update_menu_checks()
	_save_settings()


func _request_initial_activity_consent() -> void:
	if settings.activity_consent_shown:
		return

	var result := DisplayServer.dialog_show(
		"Desktop Pet activity privacy",
		_activity_privacy_message(),
		PackedStringArray([
			"Enable activity sensing",
			"Keep it off",
		]),
		_handle_initial_activity_consent
	)
	if result != OK:
		# Unsupported display servers leave sensing off. The user can retry
		# from the Activity sensing menu item.
		return


func _handle_initial_activity_consent(button_index: int) -> void:
	if button_index < 0:
		return
	settings.activity_consent_shown = true
	var enable := button_index == 0
	activity_monitor.set_listening(enable)
	settings.activity_sensing_enabled = bool(activity_monitor.listening)
	_update_menu_checks()
	_save_settings()


func _activity_privacy_message() -> String:
	return (
		"Desktop Pet can react while you use other Windows apps. "
		+ "It only receives aggregate keyboard-press and "
		+ "mouse-button-press counts.\n\n"
		+ "It does not store keys, text, shortcuts, specific mouse "
		+ "buttons, cursor positions, applications, windows, or "
		+ "an input timeline. Counts stay on this device and are "
		+ "cleared when the game exits.\n\n"
		+ "Enable it now? You can pause it at any time from the pet menu."
	)


func _handle_listening_changed(enabled: bool) -> void:
	settings.activity_sensing_enabled = enabled
	if enabled:
		if not activity_adapter.start():
			activity_monitor.set_listening(false)
			return
	else:
		activity_adapter.stop()
	_update_menu_checks()


func _handle_activity_adapter_state(state: int, message: String) -> void:
	_update_activity_menu()
	if state != WindowsActivityAdapterScript.State.ERROR:
		return

	if activity_monitor.listening:
		activity_monitor.set_listening(false)
	if not shutting_down:
		settings.activity_sensing_enabled = false
		_save_settings()
		OS.alert(
			"Windows activity sensing stopped.\n\n%s" % message,
			"Desktop Pet activity error"
		)


func _handle_activity_batch(batch) -> void:
	activity_stats.record(batch)

	if batch.keyboard_count > 0 and batch.keyboard_count >= batch.mouse_count:
		pet.react_to_keyboard(batch.keyboard_count)
	elif batch.mouse_count > 0:
		pet.react_to_mouse(batch.mouse_count)


func _set_menu_checked(id: int, checked: bool) -> void:
	var index := context_menu.get_item_index(id)
	if index >= 0:
		context_menu.set_item_checked(index, checked)


func _set_menu_disabled(id: int, disabled: bool) -> void:
	var index := context_menu.get_item_index(id)
	if index >= 0:
		context_menu.set_item_disabled(index, disabled)


func _set_menu_text(id: int, text: String) -> void:
	var index := context_menu.get_item_index(id)
	if index >= 0:
		context_menu.set_item_text(index, text)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE) != OK:
		return

	settings.always_on_top = config.get_value("window", "always_on_top", true)
	settings.display_scale = clampf(
		float(config.get_value("window", "display_scale", 1.0)),
		0.75,
		1.5
	)
	settings.selected_pet_id = str(
		config.get_value("pet", "selected_pet_id", String(DEFAULT_PET_ID))
	)
	settings.activity_consent_shown = bool(
		config.get_value("activity", "consent_shown", false)
	)
	settings.activity_sensing_enabled = bool(
		config.get_value("activity", "sensing_enabled", false)
	)
	settings.timer_snapshot = {
		"state": int(config.get_value("timer", "state", 0)),
		"kind": int(config.get_value("timer", "kind", 0)),
		"next_kind": int(config.get_value("timer", "next_kind", 0)),
		"end_unix": float(config.get_value("timer", "end_unix", 0.0)),
		"paused_remaining": float(
			config.get_value("timer", "paused_remaining", 0.0)
		),
	}
	settings.has_saved_position = config.get_value(
		"window",
		"has_saved_position",
		false
	)
	settings.window_position = Vector2i(
		int(config.get_value("window", "position_x", 0)),
		int(config.get_value("window", "position_y", 0))
	)


func _save_settings() -> void:
	if settings.is_empty():
		return

	settings.has_saved_position = true
	settings.window_position = get_window().position
	if timer_manager != null:
		settings.timer_snapshot = timer_manager.snapshot()

	var config := ConfigFile.new()
	config.set_value("window", "always_on_top", settings.always_on_top)
	config.set_value("window", "display_scale", settings.display_scale)
	config.set_value("pet", "selected_pet_id", settings.selected_pet_id)
	config.set_value(
		"activity",
		"sensing_enabled",
		settings.activity_sensing_enabled
	)
	config.set_value(
		"activity",
		"consent_shown",
		settings.activity_consent_shown
	)
	config.set_value("timer", "state", settings.timer_snapshot.state)
	config.set_value("timer", "kind", settings.timer_snapshot.kind)
	config.set_value("timer", "next_kind", settings.timer_snapshot.next_kind)
	config.set_value("timer", "end_unix", settings.timer_snapshot.end_unix)
	config.set_value(
		"timer",
		"paused_remaining",
		settings.timer_snapshot.paused_remaining
	)
	config.set_value("window", "has_saved_position", settings.has_saved_position)
	config.set_value("window", "position_x", settings.window_position.x)
	config.set_value("window", "position_y", settings.window_position.y)
	config.save(SETTINGS_FILE)


func _shutdown() -> void:
	if shutting_down:
		return

	shutting_down = true
	_save_settings()
	if activity_monitor != null:
		activity_monitor.set_listening(false)
	get_tree().quit()


func _start_preview_capture_if_requested() -> void:
	var arguments := OS.get_cmdline_user_args()
	for argument in arguments:
		if argument.begins_with("--select-pet="):
			var requested_pet_id := StringName(
				argument.trim_prefix("--select-pet=")
			)
			if not _select_pet(requested_pet_id, false):
				push_error("Preview pet was not found: %s" % requested_pet_id)

	if "--preview-click" in arguments:
		pet.react_to_click()
	if "--preview-focus-complete" in arguments:
		_handle_timer_completed(TimerManagerScript.Kind.FOCUS)
	if "--preview-live-menu" in arguments:
		_open_live_menu_preview.call_deferred()

	for argument in arguments:
		if argument == "--print-pet-catalog":
			var pet_ids: Array[String] = []
			for definition in pet_definitions:
				pet_ids.append(String(definition.pet_id))
			print(
				"Pet catalog: count=%d selected=%s ids=%s"
				% [
					pet_definitions.size(),
					pet.get_pet_id(),
					",".join(pet_ids),
				]
			)
		if argument.begins_with("--preview-scale="):
			var preview_scale := float(argument.trim_prefix("--preview-scale="))
			_apply_scale(preview_scale, false)
		if argument.begins_with("--capture-preview="):
			var output_path := argument.trim_prefix("--capture-preview=")
			_capture_preview.call_deferred(output_path)
			return


func _open_live_menu_preview() -> void:
	_start_timer(TimerManagerScript.Kind.FOCUS, 90)
	var usable := DisplayServer.screen_get_usable_rect(0)
	context_menu.position = usable.position + Vector2i(64, 64)
	context_menu.popup()


func _capture_preview(output_path: String) -> void:
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(output_path)
	if result == OK:
		print("Preview captured: %s" % output_path)
	else:
		push_error("Preview capture failed with error %s" % result)

	# Automated visual checks must not overwrite the user's window settings.
	shutting_down = true
	get_tree().quit()
