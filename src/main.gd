extends Node

const ActivityStatsScript := preload("res://src/Activity/activity_stats.gd")
const InputActivityMonitorScript := preload(
	"res://src/Activity/input_activity_monitor.gd"
)
const WindowsActivityAdapterScript := preload(
	"res://src/platform/windows/windows_activity_adapter.gd"
)
const WindowsTaskbarAdapterScript := preload(
	"res://src/platform/windows/windows_taskbar_adapter.gd"
)
const WindowsCredentialStoreScript := preload(
	"res://src/platform/windows/windows_credential_store.gd"
)
const TimerManagerScript := preload("res://src/timers/timer_manager.gd")
const ReminderManagerScript := preload(
	"res://src/timers/reminder_manager.gd"
)
const AppLocalizationScript := preload(
	"res://src/localization/app_localization.gd"
)
const CheckInManagerScript := preload(
	"res://src/checkins/check_in_manager.gd"
)
const CalendarCheckInSourceScript := preload(
	"res://src/checkins/calendar_check_in_source.gd"
)
const GoogleCalendarProviderScript := preload(
	"res://src/checkins/google_calendar_provider.gd"
)
const GoogleOAuthClientConfigScript := preload(
	"res://src/checkins/google_oauth_client_config.gd"
)
const CHECKBOX_UNCHECKED_ICON_PATH := (
	"res://assets/ui/checkbox_unchecked.svg"
)
const CHECKBOX_CHECKED_ICON_PATH := "res://assets/ui/checkbox_checked.svg"
const TRAY_ICON_PATH := "res://assets/ui/tray_icon.svg"

const BASE_WINDOW_SIZE := 360
const DEFAULT_PET_ID := &"leo"
const FOCUS_DURATION_SECONDS := 25 * 60
const BREAK_DURATION_SECONDS := 5 * 60
const DEV_FOCUS_DURATION_SECONDS := 1
const DEV_BREAK_DURATION_SECONDS := 1
const AUTO_BREAK_DELAY_SECONDS := 5.0
const AUTO_TRANSITION_LATE_GRACE_SECONDS := 2.0
const GOOGLE_CALENDAR_CLIENT_ID := (
	GoogleOAuthClientConfigScript.DEFAULT_CLIENT_ID
)
const GOOGLE_CALENDAR_CREDENTIAL_PREFIX := "client_secret"
const DURATION_SETTINGS_WINDOW_SIZE := Vector2i(430, 390)
const DURATION_SETTINGS_WINDOW_MAX_HEIGHT := 600
const LANGUAGE_SETTINGS_WINDOW_SIZE := Vector2i(390, 250)
const LANGUAGE_SETTINGS_WINDOW_MAX_HEIGHT := 480
const PET_NOTES_WINDOW_SIZE := Vector2i(420, 310)
const PET_NOTES_WINDOW_MAX_HEIGHT := 520
const SETTINGS_WINDOW_SCREEN_MARGIN := 32
const MENU_FONT_SIZE_MIN := 14
const MENU_FONT_SIZE_BASE := 16
const MENU_FONT_SIZE_MAX := 20
const QUIET_HOURS_PRESETS := [
	Vector2i(-1, -1),
	Vector2i(22, 8),
	Vector2i(23, 8),
	Vector2i(0, 8),
]
const LANGUAGE_OPTIONS := [
	{"code": "en", "label_key": "language_english"},
	{"code": "zh_CN", "label_key": "language_chinese"},
]

const MENU_FOCUS_SUBMENU := 1
const MENU_REMINDERS_SUBMENU := 2
const MENU_SETTINGS_SUBMENU := 3
const MENU_ACTIVITY_SUBMENU := 4
const MENU_PETS_SUBMENU := 5
const MENU_WINDOW_SUBMENU := 6
const MENU_DEVELOPER_SUBMENU := 7
const MENU_TRAY_TOGGLE_PET := 8
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
const MENU_DEV_WATER_1S := 48
const MENU_DEV_STAND_1S := 49
const MENU_WATER_REMINDER := 50
const MENU_STAND_REMINDER := 51
const MENU_COMPLETE_REMINDER := 52
const MENU_SNOOZE_REMINDER := 53
const MENU_SKIP_REMINDER := 54
const MENU_PAUSE_REMINDER_TODAY := 55
const MENU_REMINDER_STATUS := 56
const MENU_DURATION_SETTINGS := 57
const MENU_LANGUAGE_SETTINGS := 58
const MENU_AMBIENT_CARDS := 59
const MENU_STOP_REMINDER := 60
const MENU_QUIET_HOURS := 62
const MENU_DEV_AMBIENT_CARD := 64
const MENU_EXIT := 90
const MENU_PET_BASE := 1000

const SETTINGS_FILE := "user://prototype-settings.cfg"
const TEST_SETTINGS_FILE_PATTERN := (
	"user://prototype-settings-test-%d.cfg"
)

static var _test_settings_file := ""
static var _test_settings_initialized := false

@onready var pet: PetVisual = $PetVisual

var context_menu: PopupMenu
var tray_menu: PopupMenu
var tray_indicator: StatusIndicator
var focus_menu: PopupMenu
var reminder_menu: PopupMenu
var activity_menu: PopupMenu
var pets_menu: PopupMenu
var window_menu: PopupMenu
var developer_menu: PopupMenu
var settings_menu: PopupMenu
var hint_label: Label
var notification_panel: PanelContainer
var notification_label: Label
var notification_actions: HBoxContainer
var notification_done_button: Button
var notification_snooze_button: Button
var notification_more_button: Button
var reminder_action_menu: PopupMenu
var duration_settings_window: Window
var duration_settings_content: VBoxContainer
var duration_settings_scroll: ScrollContainer
var duration_settings_scroll_content: VBoxContainer
var duration_settings_footer: HBoxContainer
var duration_settings_title: Label
var duration_settings_note: Label
var duration_spin_boxes: Dictionary = {}
var duration_field_labels: Dictionary = {}
var duration_reset_button: Button
var duration_save_button: Button
var duration_cancel_button: Button
var language_settings_window: Window
var language_settings_content: VBoxContainer
var language_settings_scroll: ScrollContainer
var language_settings_scroll_content: VBoxContainer
var language_settings_footer: HBoxContainer
var language_settings_title: Label
var language_settings_note: Label
var language_settings_label: Label
var language_option_button: OptionButton
var language_save_button: Button
var language_cancel_button: Button
var pet_notes_settings_window: Window
var pet_notes_background: ColorRect
var pet_notes_content: VBoxContainer
var pet_notes_scroll: ScrollContainer
var pet_notes_scroll_content: VBoxContainer
var pet_notes_footer: HBoxContainer
var pet_notes_master_card: PanelContainer
var pet_notes_calendar_card: PanelContainer
var pet_notes_settings_title: Label
var pet_notes_settings_note: Label
var pet_notes_enabled_check: CheckBox
var calendar_notes_enabled_check: CheckBox
var google_calendar_status_label: Label
var google_calendar_connect_button: Button
var google_calendar_sync_button: Button
var google_calendar_disconnect_button: Button
var pet_notes_save_button: Button
var pet_notes_cancel_button: Button
var checkbox_unchecked_icon: ImageTexture
var checkbox_checked_icon: ImageTexture
var notification_timer: Timer
var ambient_card_tick_timer: Timer
var auto_transition_timer: Timer
var check_in_poll_timer: Timer
var activity_monitor
var activity_stats
var activity_adapter
var windows_taskbar_adapter
var timer_manager
var reminder_manager
var check_in_manager
var calendar_check_in_source
var google_calendar_provider
var google_calendar_credential_store
var pet_definitions: Array[PetDefinition] = []
var pet_menu_id_to_pet_id: Dictionary = {}
var settings := {
	"always_on_top": true,
	"display_scale": 1.0,
	"selected_pet_id": String(DEFAULT_PET_ID),
	"activity_sensing_enabled": false,
	"activity_consent_shown": false,
	"timer_snapshot": {},
	"reminder_snapshot": {},
	"focus_duration_seconds": FOCUS_DURATION_SECONDS,
	"break_duration_seconds": BREAK_DURATION_SECONDS,
	"ambient_cards_enabled": false,
	"calendar_notes_enabled": false,
	"google_calendar_explicitly_disconnected": false,
	"language": AppLocalizationScript.ENGLISH,
	"has_saved_position": false,
	"window_position": Vector2i.ZERO,
}

var dragging := false
var drag_moved := false
var drag_offset := Vector2i.ZERO
var drag_start := Vector2i.ZERO
var shutting_down := false
var restoring_timer := false
var restoring_reminders := false
var restoring_saved_state := true
var notification_action_kind := TimerManagerScript.Kind.NONE
var ambient_card_active := false
var ambient_card_deadline_unix := 0.0
var auto_transition_deadline_unix := 0.0
var auto_break_delay_seconds := AUTO_BREAK_DELAY_SECONDS
var pet_window_visible := true
var taskbar_button_hidden := false
var google_calendar_credential_busy := false
var google_calendar_credential_saved := false
var google_calendar_credential_error := ""
var google_calendar_credential_action := ""
var recovered_legacy_test_settings := false
var duration_settings_resize_queued := false
var duration_settings_base_note_height := -1
var language_settings_resize_queued := false
var language_settings_base_note_height := -1
var pet_notes_resize_queued := false
var pet_notes_base_note_height := -1
var pet_notes_base_status_height := -1


func _ready() -> void:
	_load_settings()
	_build_activity_pipeline()
	_build_timer_pipeline()
	_build_reminder_pipeline()
	_build_check_in_pipeline()
	_load_pet_definitions()
	if pet_definitions.is_empty():
		push_error("No valid pet definitions were found.")
		get_tree().quit()
		return
	_select_initial_pet()
	_configure_window()
	_build_hud()
	_build_duration_settings_window()
	_build_language_settings_window()
	_build_pet_notes_settings_window()
	_build_context_menu()
	_build_system_tray()
	_apply_scale(settings.display_scale, false)
	_restore_or_choose_window_position()
	_restore_timer()
	_restore_reminders()
	restoring_saved_state = false
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


func _build_reminder_pipeline() -> void:
	reminder_manager = ReminderManagerScript.new()
	reminder_manager.changed.connect(_handle_reminder_changed)
	reminder_manager.tick.connect(_handle_reminder_tick)
	reminder_manager.reminder_due.connect(_handle_reminder_due)
	reminder_manager.quiet_state_changed.connect(
		_handle_quiet_state_changed
	)
	add_child(reminder_manager)


func _build_check_in_pipeline() -> void:
	check_in_manager = CheckInManagerScript.new()
	check_in_manager.set_enabled(settings.ambient_cards_enabled)
	add_child(check_in_manager)

	calendar_check_in_source = CalendarCheckInSourceScript.new()
	calendar_check_in_source.event_ready.connect(
		_handle_calendar_event_ready
	)
	add_child(calendar_check_in_source)

	google_calendar_provider = GoogleCalendarProviderScript.new()
	google_calendar_provider.configure(
		GOOGLE_CALENDAR_CLIENT_ID,
		"",
		true
	)
	_load_packaged_google_calendar_credentials()
	_load_local_google_calendar_credentials()
	google_calendar_provider.state_changed.connect(
		_handle_google_calendar_state_changed
	)
	google_calendar_provider.events_updated.connect(
		_handle_google_calendar_events_updated
	)
	google_calendar_provider.refresh_token_received.connect(
		_handle_google_calendar_refresh_token_received
	)
	google_calendar_provider.refresh_token_invalidated.connect(
		_handle_google_calendar_refresh_token_invalidated
	)
	add_child(google_calendar_provider)

	google_calendar_credential_store = WindowsCredentialStoreScript.new()
	google_calendar_credential_store.read_completed.connect(
		_handle_google_calendar_credential_read
	)
	google_calendar_credential_store.write_completed.connect(
		_handle_google_calendar_credential_written
	)
	google_calendar_credential_store.delete_completed.connect(
		_handle_google_calendar_credential_deleted
	)
	add_child(google_calendar_credential_store)
	_restore_google_calendar_credential.call_deferred()

	check_in_poll_timer = Timer.new()
	check_in_poll_timer.wait_time = 1.0
	check_in_poll_timer.timeout.connect(_poll_check_ins)
	add_child(check_in_poll_timer)
	check_in_poll_timer.start()


func _load_local_google_calendar_credentials() -> void:
	if not OS.has_feature("editor"):
		return
	var project_directory := DirAccess.open("res://")
	if project_directory == null:
		return
	var filenames := project_directory.get_files()
	filenames.sort()
	for filename in filenames:
		if (
			filename.begins_with(GOOGLE_CALENDAR_CREDENTIAL_PREFIX)
			and filename.ends_with(".json")
			and google_calendar_provider.load_client_credentials(
				"res://%s" % filename,
				true
			)
		):
			return


func _load_packaged_google_calendar_credentials() -> void:
	if not FileAccess.file_exists(
		GoogleOAuthClientConfigScript.RELEASE_CONFIG_PATH
	):
		return
	if not google_calendar_provider.load_client_credentials(
		GoogleOAuthClientConfigScript.RELEASE_CONFIG_PATH,
		false
	):
		push_warning("Packaged Google OAuth client configuration is invalid.")


func _restore_google_calendar_credential() -> void:
	if (
		OS.get_name() != "Windows"
		or DisplayServer.get_name() == "headless"
		or google_calendar_credential_store == null
	):
		return
	google_calendar_credential_busy = true
	google_calendar_credential_error = ""
	if not _google_calendar_auto_restore_allowed():
		google_calendar_credential_action = "delete"
		if google_calendar_credential_store.delete_secret(
			_google_calendar_credential_target()
		):
			_refresh_google_calendar_status()
			return
		google_calendar_credential_error = "delete"
	else:
		google_calendar_credential_action = "read"
		if google_calendar_credential_store.read_secret(
			_google_calendar_credential_target()
		):
			_refresh_google_calendar_status()
			return
		google_calendar_credential_error = "read"
	google_calendar_credential_action = ""
	google_calendar_credential_busy = false
	_refresh_google_calendar_status()


func _google_calendar_auto_restore_allowed() -> bool:
	return not bool(
		settings.google_calendar_explicitly_disconnected
	)


func _set_google_calendar_explicit_disconnect(disconnected: bool) -> void:
	if (
		bool(settings.google_calendar_explicitly_disconnected)
		== disconnected
	):
		return
	settings.google_calendar_explicitly_disconnected = disconnected
	_save_settings()


func _start_google_calendar_credential_delete() -> void:
	google_calendar_credential_saved = false
	google_calendar_credential_error = ""
	google_calendar_credential_busy = true
	google_calendar_credential_action = "delete"
	if not google_calendar_credential_store.delete_secret(
		_google_calendar_credential_target()
	):
		google_calendar_credential_busy = false
		google_calendar_credential_error = "delete"
		google_calendar_credential_action = ""
	_refresh_google_calendar_status()


func _google_calendar_credential_target() -> String:
	return (
		"DesktopPet.GoogleCalendar.RefreshToken."
		+ GOOGLE_CALENDAR_CLIENT_ID.sha256_text()
	)


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
	window.title = _text("window_title", [definition.display_name])
	if window.size.x > 0 and window.size.y > 0:
		_update_mouse_passthrough(window.size)
		window.position = _clamp_to_visible_screen(
			window.position,
			window.size
		)
	_update_menu_checks()
	_refresh_tray_ui()

	if save:
		_save_settings()
	return true


func _configure_window() -> void:
	var window := get_window()
	window.title = _text("window_title", [pet.get_display_name()])
	window.borderless = true
	window.transparent = true
	window.always_on_top = settings.always_on_top
	window.unresizable = true
	get_viewport().transparent_bg = true
	windows_taskbar_adapter = WindowsTaskbarAdapterScript.new()
	_schedule_taskbar_button_hide()


func _schedule_taskbar_button_hide() -> void:
	if OS.get_name() != "Windows":
		return
	get_tree().create_timer(0.5).timeout.connect(
		_hide_taskbar_button
	)


func _hide_taskbar_button() -> void:
	if windows_taskbar_adapter == null:
		return
	taskbar_button_hidden = windows_taskbar_adapter.hide_button()


func _build_hud() -> void:
	hint_label = Label.new()
	hint_label.text = _text("hint")
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

	var notification_content := VBoxContainer.new()
	notification_content.mouse_filter = Control.MOUSE_FILTER_PASS
	notification_content.add_theme_constant_override("separation", 6)
	notification_panel.add_child(notification_content)

	notification_label = Label.new()
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notification_label.clip_text = true
	notification_label.text_overrun_behavior = (
		TextServer.OVERRUN_TRIM_ELLIPSIS
	)
	notification_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_label.add_theme_color_override("font_color", Color("#352B42"))
	notification_label.add_theme_font_size_override("font_size", 14)
	notification_content.add_child(notification_label)

	notification_actions = HBoxContainer.new()
	notification_actions.visible = false
	notification_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	notification_actions.mouse_filter = Control.MOUSE_FILTER_PASS
	notification_actions.add_theme_constant_override("separation", 5)
	notification_content.add_child(notification_actions)

	notification_done_button = _create_notification_button()
	notification_done_button.pressed.connect(
		_handle_primary_notification_action
	)
	notification_actions.add_child(notification_done_button)

	notification_snooze_button = _create_notification_button()
	notification_snooze_button.pressed.connect(_handle_snooze_reminder)
	notification_actions.add_child(notification_snooze_button)

	notification_more_button = _create_notification_button()
	notification_more_button.pressed.connect(_open_reminder_action_menu)
	notification_actions.add_child(notification_more_button)

	reminder_action_menu = _create_popup_menu("ReminderActionMenu")
	reminder_action_menu.add_item(
		_text("bubble_skip"),
		MENU_SKIP_REMINDER
	)
	reminder_action_menu.add_item(
		_text("bubble_pause_today"),
		MENU_PAUSE_REMINDER_TODAY
	)
	reminder_action_menu.add_separator()
	reminder_action_menu.add_item(
		_text("stop_reminder"),
		MENU_STOP_REMINDER
	)
	reminder_action_menu.id_pressed.connect(_handle_menu_item)
	add_child(reminder_action_menu)
	_refresh_notification_action_texts()

	notification_timer = Timer.new()
	notification_timer.one_shot = true
	notification_timer.timeout.connect(_hide_notification)
	add_child(notification_timer)

	ambient_card_tick_timer = Timer.new()
	ambient_card_tick_timer.wait_time = 1.0
	ambient_card_tick_timer.timeout.connect(_handle_ambient_card_tick)
	add_child(ambient_card_tick_timer)


func _create_notification_button() -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(62, 28)
	button.add_theme_font_size_override("font_size", 12)
	return button


func _build_duration_settings_window() -> void:
	duration_settings_window = Window.new()
	duration_settings_window.name = "DurationSettingsWindow"
	duration_settings_window.size = DURATION_SETTINGS_WINDOW_SIZE
	duration_settings_window.min_size = Vector2i(380, 360)
	duration_settings_window.unresizable = true
	duration_settings_window.transient = true
	duration_settings_window.exclusive = true
	duration_settings_window.visible = false
	duration_settings_window.close_requested.connect(
		duration_settings_window.hide
	)
	add_child(duration_settings_window)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	duration_settings_window.add_child(margin)

	duration_settings_content = VBoxContainer.new()
	duration_settings_content.add_theme_constant_override("separation", 12)
	margin.add_child(duration_settings_content)

	duration_settings_title = Label.new()
	duration_settings_title.add_theme_font_size_override("font_size", 20)
	duration_settings_content.add_child(duration_settings_title)

	duration_settings_scroll = ScrollContainer.new()
	duration_settings_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	duration_settings_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	duration_settings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	duration_settings_content.add_child(duration_settings_scroll)

	duration_settings_scroll_content = VBoxContainer.new()
	duration_settings_scroll_content.add_theme_constant_override(
		"separation",
		12
	)
	duration_settings_scroll_content.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	duration_settings_scroll.add_child(duration_settings_scroll_content)

	duration_settings_note = Label.new()
	duration_settings_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	duration_settings_note.custom_minimum_size = Vector2(0, 44)
	duration_settings_scroll_content.add_child(duration_settings_note)

	var fields := GridContainer.new()
	fields.columns = 2
	fields.add_theme_constant_override("h_separation", 16)
	fields.add_theme_constant_override("v_separation", 9)
	duration_settings_scroll_content.add_child(fields)
	_add_duration_field(fields, "focus", 1, 240)
	_add_duration_field(fields, "break", 1, 120)
	_add_duration_field(fields, "water", 5, 240)
	_add_duration_field(fields, "stand", 5, 240)
	_add_duration_field(fields, "snooze", 1, 60)

	duration_settings_footer = HBoxContainer.new()
	duration_settings_footer.add_theme_constant_override("separation", 8)
	duration_settings_content.add_child(duration_settings_footer)

	duration_reset_button = Button.new()
	duration_reset_button.focus_mode = Control.FOCUS_NONE
	duration_reset_button.pressed.connect(
		_reset_duration_settings_form
	)
	duration_settings_footer.add_child(duration_reset_button)

	var button_spacer := Control.new()
	button_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_settings_footer.add_child(button_spacer)

	duration_cancel_button = Button.new()
	duration_cancel_button.focus_mode = Control.FOCUS_NONE
	duration_cancel_button.pressed.connect(duration_settings_window.hide)
	duration_settings_footer.add_child(duration_cancel_button)

	duration_save_button = Button.new()
	duration_save_button.focus_mode = Control.FOCUS_NONE
	duration_save_button.pressed.connect(_save_duration_settings)
	duration_settings_footer.add_child(duration_save_button)
	_refresh_duration_settings_texts()


func _add_duration_field(
	container: GridContainer,
	field_key: String,
	minimum_minutes: int,
	maximum_minutes: int
) -> void:
	var label := Label.new()
	label.custom_minimum_size = Vector2(220, 32)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	duration_field_labels[field_key] = label
	container.add_child(label)

	var spin_box := SpinBox.new()
	spin_box.name = "%sMinutes" % field_key.capitalize()
	spin_box.min_value = minimum_minutes
	spin_box.max_value = maximum_minutes
	spin_box.step = 1.0
	spin_box.rounded = true
	spin_box.allow_greater = false
	spin_box.allow_lesser = false
	spin_box.update_on_text_changed = true
	spin_box.custom_minimum_size = Vector2(130, 32)
	duration_spin_boxes[field_key] = spin_box
	container.add_child(spin_box)


func _open_duration_settings() -> void:
	_set_pet_window_visible(true)
	duration_spin_boxes["focus"].value = (
		_focus_duration_seconds() / 60.0
	)
	duration_spin_boxes["break"].value = (
		_break_duration_seconds() / 60.0
	)
	duration_spin_boxes["water"].value = (
		reminder_manager.interval_seconds(TimerManagerScript.Kind.WATER)
		/ 60.0
	)
	duration_spin_boxes["stand"].value = (
		reminder_manager.interval_seconds(TimerManagerScript.Kind.STAND)
		/ 60.0
	)
	duration_spin_boxes["snooze"].value = (
		reminder_manager.snooze_seconds() / 60.0
	)
	duration_settings_window.popup_centered(DURATION_SETTINGS_WINDOW_SIZE)
	_queue_duration_settings_window_resize()


func _reset_duration_settings_form() -> void:
	var default_minutes := {
		"focus": FOCUS_DURATION_SECONDS / 60,
		"break": BREAK_DURATION_SECONDS / 60,
		"water": ReminderManagerScript.WATER_INTERVAL_SECONDS / 60,
		"stand": ReminderManagerScript.STAND_INTERVAL_SECONDS / 60,
		"snooze": ReminderManagerScript.SNOOZE_SECONDS / 60,
	}
	for field_key in default_minutes:
		var spin_box: SpinBox = duration_spin_boxes[field_key]
		var default_value := int(default_minutes[field_key])
		spin_box.value = default_value
		var line_edit := spin_box.get_line_edit()
		if line_edit.has_focus():
			line_edit.text = str(default_value)
			line_edit.select_all()


func _save_duration_settings() -> void:
	var focus_minutes := _duration_input_minutes("focus")
	var break_minutes := _duration_input_minutes("break")
	var water_minutes := _duration_input_minutes("water")
	var stand_minutes := _duration_input_minutes("stand")
	var snooze_minutes := _duration_input_minutes("snooze")
	settings.focus_duration_seconds = focus_minutes * 60
	settings.break_duration_seconds = break_minutes * 60
	reminder_manager.set_interval_seconds(
		TimerManagerScript.Kind.WATER,
		water_minutes * 60
	)
	reminder_manager.set_interval_seconds(
		TimerManagerScript.Kind.STAND,
		stand_minutes * 60
	)
	reminder_manager.set_snooze_seconds(
		snooze_minutes * 60
	)
	duration_settings_window.hide()
	_refresh_notification_action_texts()
	_update_timer_menu()
	_update_reminder_menu()
	_save_settings()
	_show_notification(_text("duration_settings_saved"), 3.0)


func _duration_input_minutes(field_key: String) -> int:
	var spin_box: SpinBox = duration_spin_boxes[field_key]
	var line_edit := spin_box.get_line_edit()
	var entered_minutes := roundi(spin_box.value)
	if line_edit.has_focus():
		var entered_text := line_edit.text.strip_edges()
		var parsed_minutes := roundi(entered_text.to_float())
		if not entered_text.is_empty() and (
			parsed_minutes != 0
			or entered_text.begins_with("0")
		):
			entered_minutes = parsed_minutes
	var safe_minutes := clampi(
		entered_minutes,
		roundi(spin_box.min_value),
		roundi(spin_box.max_value)
	)
	spin_box.value = safe_minutes
	return safe_minutes


func _refresh_duration_settings_texts() -> void:
	if duration_settings_window == null:
		return
	duration_settings_window.title = _text("duration_settings_window_title")
	duration_settings_title.text = _text("duration_settings_heading")
	duration_settings_note.text = _text("duration_settings_note")
	for field_key in duration_field_labels:
		duration_field_labels[field_key].text = _text(
			"duration_%s" % field_key
		)
	for spin_box in duration_spin_boxes.values():
		spin_box.suffix = _text("minutes_suffix")
	duration_reset_button.text = _text("duration_reset")
	duration_cancel_button.text = _text("duration_cancel")
	duration_save_button.text = _text("duration_save")
	_queue_duration_settings_window_resize()


func _queue_duration_settings_window_resize() -> void:
	if duration_settings_window == null or duration_settings_resize_queued:
		return
	duration_settings_resize_queued = true
	_resize_duration_settings_window.call_deferred()


func _resize_duration_settings_window() -> void:
	duration_settings_resize_queued = false
	if duration_settings_window == null or duration_settings_note == null:
		return
	var note_height := _wrapped_label_height(
		duration_settings_note,
		44,
		DURATION_SETTINGS_WINDOW_SIZE.x - 40
	)
	if duration_settings_base_note_height < 0:
		duration_settings_base_note_height = note_height
	duration_settings_note.custom_minimum_size.y = note_height
	_resize_centered_settings_window(
		duration_settings_window,
		DURATION_SETTINGS_WINDOW_SIZE,
		DURATION_SETTINGS_WINDOW_MAX_HEIGHT,
		maxi(0, note_height - duration_settings_base_note_height)
	)


func _build_language_settings_window() -> void:
	language_settings_window = Window.new()
	language_settings_window.name = "LanguageSettingsWindow"
	language_settings_window.size = LANGUAGE_SETTINGS_WINDOW_SIZE
	language_settings_window.min_size = Vector2i(350, 230)
	language_settings_window.unresizable = true
	language_settings_window.transient = true
	language_settings_window.exclusive = true
	language_settings_window.visible = false
	language_settings_window.close_requested.connect(
		language_settings_window.hide
	)
	add_child(language_settings_window)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	language_settings_window.add_child(margin)

	language_settings_content = VBoxContainer.new()
	language_settings_content.add_theme_constant_override("separation", 12)
	margin.add_child(language_settings_content)

	language_settings_title = Label.new()
	language_settings_title.add_theme_font_size_override("font_size", 20)
	language_settings_content.add_child(language_settings_title)

	language_settings_scroll = ScrollContainer.new()
	language_settings_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	language_settings_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	language_settings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	language_settings_content.add_child(language_settings_scroll)

	language_settings_scroll_content = VBoxContainer.new()
	language_settings_scroll_content.add_theme_constant_override(
		"separation",
		12
	)
	language_settings_scroll_content.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	language_settings_scroll.add_child(language_settings_scroll_content)

	language_settings_note = Label.new()
	language_settings_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	language_settings_note.custom_minimum_size = Vector2(0, 40)
	language_settings_scroll_content.add_child(language_settings_note)

	var language_row := HBoxContainer.new()
	language_row.add_theme_constant_override("separation", 12)
	language_settings_scroll_content.add_child(language_row)

	language_settings_label = Label.new()
	language_settings_label.custom_minimum_size = Vector2(125, 32)
	language_settings_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	language_row.add_child(language_settings_label)

	language_option_button = OptionButton.new()
	language_option_button.focus_mode = Control.FOCUS_NONE
	language_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_option_button.custom_minimum_size = Vector2(180, 32)
	for language_data in LANGUAGE_OPTIONS:
		var option_index := language_option_button.item_count
		language_option_button.add_item(
			_text(str(language_data.label_key))
		)
		language_option_button.set_item_metadata(
			option_index,
			str(language_data.code)
		)
	language_row.add_child(language_option_button)

	language_settings_footer = HBoxContainer.new()
	language_settings_footer.alignment = BoxContainer.ALIGNMENT_END
	language_settings_footer.add_theme_constant_override("separation", 8)
	language_settings_content.add_child(language_settings_footer)

	language_cancel_button = Button.new()
	language_cancel_button.focus_mode = Control.FOCUS_NONE
	language_cancel_button.pressed.connect(language_settings_window.hide)
	language_settings_footer.add_child(language_cancel_button)

	language_save_button = Button.new()
	language_save_button.focus_mode = Control.FOCUS_NONE
	language_save_button.pressed.connect(_save_language_settings)
	language_settings_footer.add_child(language_save_button)
	_refresh_language_settings_texts()


func _open_language_settings() -> void:
	_set_pet_window_visible(true)
	var current_language := AppLocalizationScript.normalize(
		str(settings.language)
	)
	for index in language_option_button.item_count:
		if str(language_option_button.get_item_metadata(index)) == current_language:
			language_option_button.select(index)
			break
	language_settings_window.popup_centered(LANGUAGE_SETTINGS_WINDOW_SIZE)
	_queue_language_settings_window_resize()


func _save_language_settings() -> void:
	var selected_index := language_option_button.selected
	if selected_index < 0:
		return
	var selected_language := str(
		language_option_button.get_item_metadata(selected_index)
	)
	language_settings_window.hide()
	_set_language(selected_language)


func _refresh_language_settings_texts() -> void:
	if language_settings_window == null:
		return
	language_settings_window.title = _text("language_settings_window_title")
	language_settings_title.text = _text("language_settings_heading")
	language_settings_note.text = _text("language_settings_note")
	language_settings_label.text = _text("language_settings_label")
	for index in mini(
		language_option_button.item_count,
		LANGUAGE_OPTIONS.size()
	):
		language_option_button.set_item_text(
			index,
			_text(str(LANGUAGE_OPTIONS[index].label_key))
		)
	language_cancel_button.text = _text("duration_cancel")
	language_save_button.text = _text("duration_save")
	_queue_language_settings_window_resize()


func _queue_language_settings_window_resize() -> void:
	if language_settings_window == null or language_settings_resize_queued:
		return
	language_settings_resize_queued = true
	_resize_language_settings_window.call_deferred()


func _resize_language_settings_window() -> void:
	language_settings_resize_queued = false
	if language_settings_window == null or language_settings_note == null:
		return
	var note_height := _wrapped_label_height(
		language_settings_note,
		40,
		LANGUAGE_SETTINGS_WINDOW_SIZE.x - 40
	)
	if language_settings_base_note_height < 0:
		language_settings_base_note_height = note_height
	language_settings_note.custom_minimum_size.y = note_height
	_resize_centered_settings_window(
		language_settings_window,
		LANGUAGE_SETTINGS_WINDOW_SIZE,
		LANGUAGE_SETTINGS_WINDOW_MAX_HEIGHT,
		maxi(0, note_height - language_settings_base_note_height)
	)


func _build_pet_notes_settings_window() -> void:
	pet_notes_settings_window = Window.new()
	pet_notes_settings_window.name = "PetNotesSettingsWindow"
	pet_notes_settings_window.size = PET_NOTES_WINDOW_SIZE
	pet_notes_settings_window.min_size = PET_NOTES_WINDOW_SIZE
	pet_notes_settings_window.unresizable = true
	pet_notes_settings_window.transient = true
	pet_notes_settings_window.exclusive = true
	pet_notes_settings_window.visible = false
	pet_notes_settings_window.close_requested.connect(
		pet_notes_settings_window.hide
	)
	add_child(pet_notes_settings_window)

	pet_notes_background = ColorRect.new()
	pet_notes_background.color = Color("#2B2434")
	pet_notes_background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	pet_notes_settings_window.add_child(pet_notes_background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	pet_notes_settings_window.add_child(margin)

	pet_notes_content = VBoxContainer.new()
	pet_notes_content.add_theme_constant_override("separation", 8)
	margin.add_child(pet_notes_content)

	pet_notes_settings_title = Label.new()
	pet_notes_settings_title.add_theme_font_size_override("font_size", 18)
	pet_notes_settings_title.add_theme_color_override(
		"font_color",
		Color.WHITE
	)
	pet_notes_content.add_child(pet_notes_settings_title)

	pet_notes_scroll = ScrollContainer.new()
	pet_notes_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	pet_notes_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pet_notes_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet_notes_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pet_notes_content.add_child(pet_notes_scroll)

	pet_notes_scroll_content = VBoxContainer.new()
	pet_notes_scroll_content.add_theme_constant_override("separation", 5)
	pet_notes_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet_notes_scroll.add_child(pet_notes_scroll_content)

	pet_notes_settings_note = Label.new()
	pet_notes_settings_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pet_notes_settings_note.custom_minimum_size = Vector2(0, 34)
	pet_notes_settings_note.add_theme_font_size_override("font_size", 12)
	pet_notes_settings_note.add_theme_color_override(
		"font_color",
		Color("#C8BDD9")
	)
	pet_notes_scroll_content.add_child(pet_notes_settings_note)

	pet_notes_master_card = PanelContainer.new()
	pet_notes_master_card.add_theme_stylebox_override(
		"panel",
		_settings_card_style()
	)
	pet_notes_scroll_content.add_child(pet_notes_master_card)

	pet_notes_enabled_check = CheckBox.new()
	pet_notes_enabled_check.focus_mode = Control.FOCUS_NONE
	_style_settings_checkbox(pet_notes_enabled_check)
	pet_notes_master_card.add_child(pet_notes_enabled_check)

	pet_notes_calendar_card = PanelContainer.new()
	pet_notes_calendar_card.add_theme_stylebox_override(
		"panel",
		_settings_card_style()
	)
	pet_notes_scroll_content.add_child(pet_notes_calendar_card)

	var calendar_content := VBoxContainer.new()
	calendar_content.add_theme_constant_override("separation", 4)
	pet_notes_calendar_card.add_child(calendar_content)

	calendar_notes_enabled_check = CheckBox.new()
	calendar_notes_enabled_check.focus_mode = Control.FOCUS_NONE
	_style_settings_checkbox(calendar_notes_enabled_check)
	calendar_content.add_child(calendar_notes_enabled_check)

	google_calendar_status_label = Label.new()
	google_calendar_status_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	google_calendar_status_label.custom_minimum_size = Vector2(0, 34)
	google_calendar_status_label.add_theme_font_size_override(
		"font_size",
		12
	)
	google_calendar_status_label.add_theme_color_override(
		"font_color",
		Color("#C8BDD9")
	)
	calendar_content.add_child(google_calendar_status_label)

	var calendar_buttons := HBoxContainer.new()
	calendar_buttons.add_theme_constant_override("separation", 6)
	calendar_content.add_child(calendar_buttons)

	google_calendar_connect_button = Button.new()
	google_calendar_connect_button.focus_mode = Control.FOCUS_NONE
	_style_settings_button(google_calendar_connect_button, true)
	google_calendar_connect_button.pressed.connect(
		_connect_google_calendar
	)
	calendar_buttons.add_child(google_calendar_connect_button)

	google_calendar_sync_button = Button.new()
	google_calendar_sync_button.focus_mode = Control.FOCUS_NONE
	_style_settings_button(google_calendar_sync_button)
	google_calendar_sync_button.pressed.connect(
		_sync_google_calendar
	)
	calendar_buttons.add_child(google_calendar_sync_button)

	google_calendar_disconnect_button = Button.new()
	google_calendar_disconnect_button.focus_mode = Control.FOCUS_NONE
	_style_settings_button(
		google_calendar_disconnect_button,
		false,
		true
	)
	google_calendar_disconnect_button.pressed.connect(
		_disconnect_google_calendar
	)
	calendar_buttons.add_child(google_calendar_disconnect_button)

	pet_notes_footer = HBoxContainer.new()
	pet_notes_footer.alignment = BoxContainer.ALIGNMENT_END
	pet_notes_footer.add_theme_constant_override("separation", 6)
	pet_notes_content.add_child(pet_notes_footer)

	pet_notes_cancel_button = Button.new()
	pet_notes_cancel_button.focus_mode = Control.FOCUS_NONE
	_style_settings_button(pet_notes_cancel_button)
	pet_notes_cancel_button.pressed.connect(
		pet_notes_settings_window.hide
	)
	pet_notes_footer.add_child(pet_notes_cancel_button)

	pet_notes_save_button = Button.new()
	pet_notes_save_button.focus_mode = Control.FOCUS_NONE
	_style_settings_button(pet_notes_save_button, true)
	pet_notes_save_button.pressed.connect(_save_pet_notes_settings)
	pet_notes_footer.add_child(pet_notes_save_button)
	_refresh_pet_notes_settings_texts()


func _settings_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3A3045")
	style.border_color = Color("#50425F")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 11
	style.content_margin_right = 11
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _style_settings_button(
	button: Button,
	accent: bool = false,
	danger: bool = false
) -> void:
	button.custom_minimum_size = Vector2(78, 30)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal_color := Color("#4A4055")
	var hover_color := Color("#5A4D68")
	var pressed_color := Color("#403649")
	if accent:
		normal_color = Color("#6D5BA6")
		hover_color = Color("#806DBB")
		pressed_color = Color("#5B4A91")
	elif danger:
		normal_color = Color("#5B3845")
		hover_color = Color("#714452")
		pressed_color = Color("#492E38")
	for state_data in [
		["normal", normal_color],
		["hover", hover_color],
		["pressed", pressed_color],
	]:
		var style := StyleBoxFlat.new()
		style.bg_color = state_data[1]
		style.set_corner_radius_all(7)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		button.add_theme_stylebox_override(str(state_data[0]), style)


func _style_settings_checkbox(check_box: CheckBox) -> void:
	if checkbox_unchecked_icon == null:
		checkbox_unchecked_icon = _load_svg_texture(
			CHECKBOX_UNCHECKED_ICON_PATH
		)
	if checkbox_checked_icon == null:
		checkbox_checked_icon = _load_svg_texture(
			CHECKBOX_CHECKED_ICON_PATH
		)
	check_box.custom_minimum_size.y = 32
	check_box.add_theme_constant_override("h_separation", 9)
	check_box.add_theme_color_override("font_color", Color.WHITE)
	check_box.add_theme_color_override("font_hover_color", Color.WHITE)
	check_box.add_theme_color_override("font_pressed_color", Color.WHITE)
	check_box.add_theme_color_override("font_focus_color", Color.WHITE)
	check_box.add_theme_color_override(
		"font_outline_color",
		Color("#352B42")
	)
	check_box.add_theme_constant_override("outline_size", 3)
	for icon_name in [
		"unchecked",
		"unchecked_hover",
		"unchecked_pressed",
		"unchecked_focus",
		"unchecked_hover_pressed",
		"unchecked_disabled",
	]:
		check_box.add_theme_icon_override(
			icon_name,
			checkbox_unchecked_icon
		)
	for icon_name in [
		"checked",
		"checked_hover",
		"checked_pressed",
		"checked_focus",
		"checked_hover_pressed",
		"checked_disabled",
	]:
		check_box.add_theme_icon_override(
			icon_name,
			checkbox_checked_icon
		)


func _load_svg_texture(path: String) -> ImageTexture:
	var image := Image.new()
	var load_result := image.load_svg_from_string(
		FileAccess.get_file_as_string(path)
	)
	if load_result != OK:
		push_error("Could not load settings icon: %s" % path)
		return ImageTexture.new()
	return ImageTexture.create_from_image(image)


func _open_pet_notes_settings() -> void:
	_set_pet_window_visible(true)
	pet_notes_enabled_check.button_pressed = (
		settings.ambient_cards_enabled
	)
	calendar_notes_enabled_check.button_pressed = (
		settings.calendar_notes_enabled
	)
	_refresh_pet_notes_settings_texts()
	pet_notes_settings_window.popup_centered(PET_NOTES_WINDOW_SIZE)
	_queue_pet_notes_window_resize()


func _save_pet_notes_settings() -> void:
	_apply_pet_notes_settings()
	pet_notes_settings_window.hide()


func _apply_pet_notes_settings() -> void:
	settings.ambient_cards_enabled = (
		pet_notes_enabled_check.button_pressed
	)
	settings.calendar_notes_enabled = (
		calendar_notes_enabled_check.button_pressed
	)
	check_in_manager.set_enabled(settings.ambient_cards_enabled)
	if not settings.ambient_cards_enabled and ambient_card_active:
		_hide_notification()
	if not settings.calendar_notes_enabled:
		check_in_manager.remove_source("calendar")
	_update_menu_checks()
	_save_settings()


func _connect_google_calendar() -> void:
	_apply_pet_notes_settings()
	google_calendar_provider.connect_account()
	_refresh_google_calendar_status()


func _sync_google_calendar() -> void:
	_apply_pet_notes_settings()
	google_calendar_provider.sync_events()
	_refresh_google_calendar_status()


func _disconnect_google_calendar() -> void:
	_set_google_calendar_explicit_disconnect(true)
	google_calendar_provider.disconnect_account()
	calendar_check_in_source.replace_events([])
	check_in_manager.remove_source("calendar")
	_start_google_calendar_credential_delete()


func _refresh_pet_notes_settings_texts() -> void:
	if pet_notes_settings_window == null:
		return
	pet_notes_settings_window.title = _text("pet_notes_window_title")
	pet_notes_settings_title.text = _text("pet_notes_heading")
	pet_notes_settings_note.text = _text("pet_notes_note")
	pet_notes_enabled_check.text = _text("pet_notes_enabled")
	calendar_notes_enabled_check.text = _text("calendar_notes_enabled")
	google_calendar_connect_button.text = _text("google_calendar_connect")
	google_calendar_sync_button.text = _text("google_calendar_sync")
	google_calendar_disconnect_button.text = _text(
		"google_calendar_disconnect"
	)
	pet_notes_cancel_button.text = _text("duration_cancel")
	pet_notes_save_button.text = _text("duration_save")
	_refresh_google_calendar_status()


func _refresh_google_calendar_status() -> void:
	if google_calendar_status_label == null:
		return
	if google_calendar_provider == null:
		google_calendar_status_label.text = _text(
			"google_calendar_disconnected"
		)
		return
	var state: int = google_calendar_provider.state
	var is_busy := (
		state == GoogleCalendarProviderScript.State.CONNECTING
		or state == GoogleCalendarProviderScript.State.SYNCING
		or google_calendar_credential_busy
	)
	var is_connected: bool = (
		google_calendar_provider.has_account_connection()
	)
	if state == GoogleCalendarProviderScript.State.ERROR:
		google_calendar_status_label.text = _text(
			"google_calendar_error",
			[
				_google_calendar_error_message(
					google_calendar_provider.status_message
				),
			]
		)
	elif (
		google_calendar_credential_busy
		and not is_connected
	):
		google_calendar_status_label.text = _text(
			"google_calendar_forgetting"
			if google_calendar_credential_action == "delete"
			else "google_calendar_restoring"
		)
	elif is_busy:
		google_calendar_status_label.text = _text(
			"google_calendar_connecting"
			if state == GoogleCalendarProviderScript.State.CONNECTING
			else "google_calendar_syncing"
		)
	elif is_connected:
		var account: String = google_calendar_provider.account_label
		if google_calendar_credential_error == "write":
			google_calendar_status_label.text = _text(
				"google_calendar_connected_not_saved"
			)
		elif not google_calendar_credential_saved:
			google_calendar_status_label.text = _text(
				"google_calendar_connected_session"
			)
		else:
			google_calendar_status_label.text = (
				_text("google_calendar_connected_account", [account])
				if not account.is_empty()
				else _text("google_calendar_connected")
			)
	elif google_calendar_credential_error == "delete":
		google_calendar_status_label.text = _text(
			"google_calendar_disconnect_not_removed"
		)
	elif google_calendar_credential_error == "read":
		google_calendar_status_label.text = _text(
			"google_calendar_credential_read_failed"
		)
	else:
		google_calendar_status_label.text = _text(
			"google_calendar_disconnected"
		)
	google_calendar_connect_button.visible = not is_connected
	google_calendar_connect_button.disabled = is_busy
	google_calendar_sync_button.visible = is_connected
	google_calendar_sync_button.disabled = is_busy
	google_calendar_disconnect_button.visible = is_connected
	google_calendar_disconnect_button.disabled = is_busy
	_queue_pet_notes_window_resize()


func _queue_pet_notes_window_resize() -> void:
	if (
		pet_notes_settings_window == null
		or pet_notes_resize_queued
	):
		return
	pet_notes_resize_queued = true
	_resize_pet_notes_settings_window.call_deferred()


func _resize_pet_notes_settings_window() -> void:
	pet_notes_resize_queued = false
	if (
		pet_notes_settings_window == null
		or pet_notes_scroll_content == null
		or pet_notes_footer == null
	):
		return
	var note_height := _wrapped_label_height(
		pet_notes_settings_note,
		34,
		PET_NOTES_WINDOW_SIZE.x - 64
	)
	var status_height := _wrapped_label_height(
		google_calendar_status_label,
		34,
		PET_NOTES_WINDOW_SIZE.x - 64
	)
	if pet_notes_base_note_height < 0:
		pet_notes_base_note_height = note_height
	if pet_notes_base_status_height < 0:
		pet_notes_base_status_height = status_height
	pet_notes_settings_note.custom_minimum_size.y = note_height
	google_calendar_status_label.custom_minimum_size.y = status_height
	_resize_centered_settings_window(
		pet_notes_settings_window,
		PET_NOTES_WINDOW_SIZE,
		PET_NOTES_WINDOW_MAX_HEIGHT,
		maxi(0, note_height - pet_notes_base_note_height)
		+ maxi(0, status_height - pet_notes_base_status_height)
	)


func _resize_centered_settings_window(
	window: Window,
	base_size: Vector2i,
	configured_maximum_height: int,
	extra_height: int
) -> void:
	var maximum_height := configured_maximum_height
	var screen := window.current_screen
	if screen < 0:
		screen = DisplayServer.get_primary_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	var has_usable_screen := (
		usable_rect.size.y
		>= base_size.y + SETTINGS_WINDOW_SCREEN_MARGIN
	)
	if has_usable_screen:
		maximum_height = mini(
			maximum_height,
			maxi(
				base_size.y,
				usable_rect.size.y - SETTINGS_WINDOW_SCREEN_MARGIN
			)
		)
	var target_size := Vector2i(
		base_size.x,
		clampi(
			base_size.y + extra_height,
			base_size.y,
			maximum_height
		)
	)
	window.size = target_size
	if window.visible and has_usable_screen:
		window.position = (
			usable_rect.position
			+ (usable_rect.size - target_size) / 2
		)


func _wrapped_label_height(
	label: Label,
	minimum_height: int,
	fallback_width: float
) -> int:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var wrap_width := label.size.x
	if wrap_width < fallback_width / 2.0:
		wrap_width = fallback_width
	var measured_size := font.get_multiline_string_size(
		label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		wrap_width,
		font_size
	)
	return maxi(minimum_height, ceili(measured_size.y))


func _google_calendar_error_message(code: String) -> String:
	if code == "missing_client_id":
		return _text("google_calendar_error_setup")
	if code == "missing_client_secret":
		return _text("google_calendar_error_client_secret")
	if code in [
		"callback_port_unavailable",
		"invalid_callback",
		"invalid_oauth_state",
	]:
		return _text("google_calendar_error_callback")
	if code == "browser_open_failed":
		return _text("google_calendar_error_browser")
	if code in [
		"access_denied",
		"authorization_required",
		"token_request_failed",
		"token_refresh_failed",
		"invalid_token_response",
		"missing_access_token",
	]:
		return _text("google_calendar_error_authorization")
	if code == "invalid_grant":
		return _text("google_calendar_error_invalid_grant")
	if code in ["invalid_client", "unauthorized_client"]:
		return _text("google_calendar_error_invalid_client")
	if code == "client_secret_missing":
		return _text("google_calendar_error_client_secret")
	if code in ["service_disabled", "accessnotconfigured"]:
		return _text("google_calendar_error_service_disabled")
	if code in ["permission_denied", "forbidden"]:
		return _text("google_calendar_error_permission")
	if code in ["token_network_error", "calendar_network_error"]:
		return _text("google_calendar_error_network")
	if code in [
		"token_exchange_failed",
		"calendar_api_failed",
		"invalid_calendar_response",
		"invalid_calendar_list",
		"calendar_request_failed",
	]:
		return _text("google_calendar_error_sync")
	return _text("google_calendar_error_unknown", [code])


func _refresh_notification_action_texts() -> void:
	if notification_done_button == null:
		return
	if ambient_card_active:
		_update_ambient_card_button()
	else:
		notification_done_button.text = _text("bubble_done")
	var snooze_seconds := ReminderManagerScript.SNOOZE_SECONDS
	if reminder_manager != null:
		snooze_seconds = reminder_manager.snooze_seconds()
	notification_snooze_button.text = _text(
		"bubble_snooze",
		[_format_setting_duration(snooze_seconds)]
	)
	notification_more_button.text = _text("bubble_more")
	_set_menu_text(
		reminder_action_menu,
		MENU_SKIP_REMINDER,
		_text("bubble_skip")
	)
	_set_menu_text(
		reminder_action_menu,
		MENU_PAUSE_REMINDER_TODAY,
		_text("bubble_pause_today")
	)
	var due_kind := notification_action_kind
	var due_name := _reminder_kind_name(due_kind).to_lower()
	_set_menu_text(
		reminder_action_menu,
		MENU_STOP_REMINDER,
		_text("bubble_stop_named", [due_name])
		if due_kind != TimerManagerScript.Kind.NONE
		else _text("stop_reminder")
	)


func _build_context_menu() -> void:
	# A separate Godot subwindow stays rectangular outside the transparent
	# pet window while still letting the main loop refresh live menu text.
	get_viewport().gui_embed_subwindows = false
	context_menu = _create_popup_menu("ContextMenu")
	add_child(context_menu)

	focus_menu = _create_submenu("FocusMenu")
	focus_menu.add_item(_timer_status_summary(), MENU_TIMER_STATUS)
	_set_menu_disabled(focus_menu, MENU_TIMER_STATUS, true)
	focus_menu.add_item(_focus_start_menu_text(), MENU_START_FOCUS)
	focus_menu.add_item(_break_start_menu_text(), MENU_START_BREAK)
	focus_menu.add_separator()
	focus_menu.add_item(_text("pause_timer"), MENU_PAUSE_RESUME_TIMER)
	focus_menu.add_item(_text("cancel_timer"), MENU_CANCEL_TIMER)
	focus_menu.add_item(
		_text("cancel_auto_start"),
		MENU_CANCEL_AUTO_TRANSITION
	)

	reminder_menu = _create_submenu("ReminderMenu")
	reminder_menu.add_item(
		_reminder_status_summary(),
		MENU_REMINDER_STATUS
	)
	_set_menu_disabled(reminder_menu, MENU_REMINDER_STATUS, true)
	reminder_menu.add_check_item(
		_reminder_kind_status(TimerManagerScript.Kind.WATER),
		MENU_WATER_REMINDER
	)
	reminder_menu.add_check_item(
		_reminder_kind_status(TimerManagerScript.Kind.STAND),
		MENU_STAND_REMINDER
	)
	reminder_menu.add_separator()
	reminder_menu.add_item(
		_quiet_hours_text(),
		MENU_QUIET_HOURS
	)
	reminder_menu.add_separator()
	reminder_menu.add_item(
		_text("complete_reminder"),
		MENU_COMPLETE_REMINDER
	)
	reminder_menu.add_item(
		_text(
			"snooze_reminder",
			[_format_setting_duration(reminder_manager.snooze_seconds())]
		),
		MENU_SNOOZE_REMINDER
	)
	reminder_menu.add_item(_text("skip_reminder"), MENU_SKIP_REMINDER)
	reminder_menu.add_item(
		_text("pause_reminder_today"),
		MENU_PAUSE_REMINDER_TODAY
	)
	reminder_menu.add_item(
		_text("stop_reminder"),
		MENU_STOP_REMINDER
	)

	activity_menu = _create_submenu("ActivityMenu")
	activity_menu.add_check_item(
		_text("activity_sensing"),
		MENU_ACTIVITY_SENSING
	)
	activity_menu.add_item(_activity_summary(), MENU_ACTIVITY_COUNTS)
	_set_menu_disabled(activity_menu, MENU_ACTIVITY_COUNTS, true)
	activity_menu.add_item(
		_activity_source_summary(),
		MENU_ACTIVITY_STATUS
	)
	_set_menu_disabled(activity_menu, MENU_ACTIVITY_STATUS, true)
	activity_menu.add_separator()
	activity_menu.add_item(_text("clear_activity"), MENU_CLEAR_ACTIVITY)

	pets_menu = _create_submenu("PetsMenu")
	for index in pet_definitions.size():
		var definition := pet_definitions[index]
		var menu_id := MENU_PET_BASE + index
		pet_menu_id_to_pet_id[menu_id] = definition.pet_id
		pets_menu.add_radio_check_item(
			definition.display_name,
			menu_id
		)

	window_menu = _create_submenu("WindowMenu")
	window_menu.add_check_item(_text("always_on_top"), MENU_ALWAYS_ON_TOP)
	window_menu.add_separator()
	window_menu.add_radio_check_item(_text("scale", [75]), MENU_SCALE_75)
	window_menu.add_radio_check_item(_text("scale", [100]), MENU_SCALE_100)
	window_menu.add_radio_check_item(_text("scale", [125]), MENU_SCALE_125)
	window_menu.add_radio_check_item(_text("scale", [150]), MENU_SCALE_150)

	settings_menu = _create_submenu("SettingsMenu")
	settings_menu.add_item(
		_text("duration_settings_menu"),
		MENU_DURATION_SETTINGS
	)
	settings_menu.add_item(
		_text("language_settings_menu"),
		MENU_LANGUAGE_SETTINGS
	)
	settings_menu.add_separator()
	settings_menu.add_item(
		_text("ambient_cards"),
		MENU_AMBIENT_CARDS
	)

	context_menu.add_submenu_node_item(
		_focus_menu_title(),
		focus_menu,
		MENU_FOCUS_SUBMENU
	)
	context_menu.add_submenu_node_item(
		_reminder_menu_title(),
		reminder_menu,
		MENU_REMINDERS_SUBMENU
	)
	context_menu.add_submenu_node_item(
		_text("activity"),
		activity_menu,
		MENU_ACTIVITY_SUBMENU
	)
	context_menu.add_submenu_node_item(
		_text("pets"),
		pets_menu,
		MENU_PETS_SUBMENU
	)
	context_menu.add_submenu_node_item(
		_text("window"),
		window_menu,
		MENU_WINDOW_SUBMENU
	)

	if OS.has_feature("editor"):
		developer_menu = _create_submenu("DeveloperMenu")
		developer_menu.add_item(
			_text("dev_focus"),
			MENU_DEV_FOCUS_1S
		)
		developer_menu.add_item(
			_text("dev_break"),
			MENU_DEV_BREAK_1S
		)
		developer_menu.add_separator()
		developer_menu.add_item(
			_text("dev_water"),
			MENU_DEV_WATER_1S
		)
		developer_menu.add_item(
			_text("dev_stand"),
			MENU_DEV_STAND_1S
		)
		developer_menu.add_separator()
		developer_menu.add_item(
			_text("dev_ambient_card"),
			MENU_DEV_AMBIENT_CARD
		)
		context_menu.add_submenu_node_item(
			_text("developer"),
			developer_menu,
			MENU_DEVELOPER_SUBMENU
		)

	context_menu.add_separator()
	context_menu.add_submenu_node_item(
		_text("settings"),
		settings_menu,
		MENU_SETTINGS_SUBMENU
	)
	context_menu.add_separator()
	context_menu.add_item(_text("exit"), MENU_EXIT)
	context_menu.id_pressed.connect(_handle_menu_item)


func _build_system_tray() -> void:
	tray_menu = PopupMenu.new()
	tray_menu.name = "TrayMenu"
	tray_menu.prefer_native_menu = true
	tray_menu.force_native = true
	tray_menu.add_item(_text("tray_hide_pet"), MENU_TRAY_TOGGLE_PET)
	tray_menu.add_separator()
	tray_menu.add_item(_focus_start_menu_text(), MENU_START_FOCUS)
	tray_menu.add_item(_text("ambient_cards"), MENU_AMBIENT_CARDS)
	tray_menu.add_separator()
	tray_menu.add_item(_text("exit"), MENU_EXIT)
	tray_menu.id_pressed.connect(_handle_menu_item)
	add_child(tray_menu)

	if not DisplayServer.has_feature(
		DisplayServer.FEATURE_STATUS_INDICATOR
	):
		return
	tray_indicator = StatusIndicator.new()
	tray_indicator.name = "DesktopPetTray"
	tray_indicator.icon = _load_svg_texture(TRAY_ICON_PATH)
	tray_indicator.tooltip = _text(
		"tray_tooltip",
		[pet.get_display_name()]
	)
	add_child(tray_indicator)
	tray_indicator.menu = tray_indicator.get_path_to(tray_menu)
	tray_indicator.visible = true


func _create_popup_menu(node_name: String) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.name = node_name
	menu.prefer_native_menu = false
	menu.force_native = false
	menu.transparent = false
	menu.transient = true
	menu.unresizable = true
	return menu


func _create_submenu(node_name: String) -> PopupMenu:
	var menu := _create_popup_menu(node_name)
	menu.id_pressed.connect(_handle_menu_item)
	context_menu.add_child(menu)
	return menu


func _menu_font_size_for_scale(scale_factor: float) -> int:
	return clampi(
		roundi(
			MENU_FONT_SIZE_BASE
			+ (clampf(scale_factor, 0.75, 1.5) - 1.0) * 8.0
		),
		MENU_FONT_SIZE_MIN,
		MENU_FONT_SIZE_MAX
	)


func _scalable_popup_menus() -> Array[PopupMenu]:
	var menus: Array[PopupMenu] = []
	for menu in [
		context_menu,
		focus_menu,
		reminder_menu,
		activity_menu,
		pets_menu,
		window_menu,
		settings_menu,
		developer_menu,
		reminder_action_menu,
	]:
		if menu != null and not menu.prefer_native_menu:
			menus.append(menu)
	return menus


func _apply_menu_scale() -> void:
	var font_size := _menu_font_size_for_scale(settings.display_scale)
	var menu_scale := float(font_size) / MENU_FONT_SIZE_BASE
	for menu in _scalable_popup_menus():
		menu.add_theme_font_size_override("font_size", font_size)
		menu.add_theme_constant_override(
			"v_separation",
			roundi(4.0 * menu_scale)
		)
		menu.add_theme_constant_override(
			"item_start_padding",
			roundi(8.0 * menu_scale)
		)
		menu.add_theme_constant_override(
			"item_end_padding",
			roundi(8.0 * menu_scale)
		)
		menu.add_theme_constant_override(
			"icon_max_width",
			roundi(18.0 * menu_scale)
		)
		menu.reset_size()


func _handle_mouse_button(button: InputEventMouseButton) -> void:
	if (
		_notification_is_actionable()
		and notification_panel.visible
		and Rect2(
			notification_panel.position,
			notification_panel.size
		).has_point(button.position)
	):
		# Let the Control buttons receive the click instead of starting a
		# pet drag in the scene-level input handler.
		return

	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		_open_context_menu(DisplayServer.mouse_get_position())
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


func _open_context_menu(screen_position: Vector2i) -> void:
	_update_menu_checks()
	context_menu.position = screen_position
	context_menu.popup()


func _handle_pet_tap(viewport_position: Vector2) -> void:
	if (
		reminder_manager != null
		and reminder_manager.current_due_kind()
		!= TimerManagerScript.Kind.NONE
		and not _focus_is_running()
		and not reminder_manager.is_quiet_now()
	):
		_show_pending_health_reminder()
		return
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
			_focus_duration_seconds()
		)
		_show_notification(
			_text(
				"focus_started",
				[
					_format_setting_duration(
						_focus_duration_seconds()
					)
				]
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
		MENU_TRAY_TOGGLE_PET:
			_set_pet_window_visible(not pet_window_visible)
			return
		MENU_LANGUAGE_SETTINGS:
			_open_language_settings()
			return
		MENU_AMBIENT_CARDS:
			_open_pet_notes_settings()
			return
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
				_focus_duration_seconds()
			)
		MENU_DEV_FOCUS_1S:
			_start_timer(
				TimerManagerScript.Kind.FOCUS,
				DEV_FOCUS_DURATION_SECONDS
			)
		MENU_START_BREAK:
			_start_timer(
				TimerManagerScript.Kind.BREAK,
				_break_duration_seconds()
			)
		MENU_DEV_BREAK_1S:
			_start_timer(
				TimerManagerScript.Kind.BREAK,
				DEV_BREAK_DURATION_SECONDS
			)
		MENU_WATER_REMINDER:
			_toggle_reminder(TimerManagerScript.Kind.WATER)
		MENU_STAND_REMINDER:
			_toggle_reminder(TimerManagerScript.Kind.STAND)
		MENU_DURATION_SETTINGS:
			_open_duration_settings()
			return
		MENU_QUIET_HOURS:
			_cycle_quiet_hours()
		MENU_COMPLETE_REMINDER:
			_handle_complete_reminder()
		MENU_SNOOZE_REMINDER:
			_handle_snooze_reminder()
		MENU_SKIP_REMINDER:
			_handle_skip_reminder()
		MENU_PAUSE_REMINDER_TODAY:
			_handle_pause_reminder_today()
		MENU_STOP_REMINDER:
			_handle_stop_reminder()
		MENU_DEV_WATER_1S:
			reminder_manager.start_test_reminder(
				TimerManagerScript.Kind.WATER,
				1.0
			)
			_hide_notification()
		MENU_DEV_STAND_1S:
			reminder_manager.start_test_reminder(
				TimerManagerScript.Kind.STAND,
				1.0
			)
			_hide_notification()
		MENU_DEV_AMBIENT_CARD:
			_show_ambient_card(
				_text("dev_ambient_card_message"),
				CheckInManagerScript.DEFAULT_DISPLAY_SECONDS
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


func _set_pet_window_visible(visible: bool) -> void:
	pet_window_visible = visible
	get_window().mode = (
		Window.MODE_WINDOWED
		if visible
		else Window.MODE_MINIMIZED
	)
	if visible:
		_schedule_taskbar_button_hide()
	_refresh_tray_ui()


func _refresh_tray_ui() -> void:
	if tray_menu != null:
		_set_menu_text(
			tray_menu,
			MENU_TRAY_TOGGLE_PET,
			_text(
				"tray_hide_pet"
				if pet_window_visible
				else "tray_show_pet"
			)
		)
		_set_menu_text(
			tray_menu,
			MENU_START_FOCUS,
			_focus_start_menu_text()
		)
		_set_menu_text(
			tray_menu,
			MENU_AMBIENT_CARDS,
			_text("ambient_cards")
		)
		_set_menu_text(tray_menu, MENU_EXIT, _text("exit"))
	if tray_indicator != null:
		tray_indicator.tooltip = _text(
			"tray_tooltip",
			[pet.get_display_name()]
		)


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
	_layout_notification_panel()
	notification_label.add_theme_font_size_override(
		"font_size",
		roundi(14 * settings.display_scale)
	)
	for button in [
		notification_done_button,
		notification_snooze_button,
		notification_more_button,
	]:
		button.custom_minimum_size = (
			Vector2(62, 28) * settings.display_scale
		)
		button.add_theme_font_size_override(
			"font_size",
			roundi(12 * settings.display_scale)
		)

	_apply_menu_scale()
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
	if (
		_notification_is_actionable()
		and notification_panel != null
		and notification_panel.visible
	):
		var bubble_rect := Rect2(
			notification_panel.position,
			notification_panel.size
		)
		scaled_polygon.append(bubble_rect.position)
		scaled_polygon.append(
			bubble_rect.position + Vector2(bubble_rect.size.x, 0)
		)
		scaled_polygon.append(bubble_rect.end)
		scaled_polygon.append(
			bubble_rect.position + Vector2(0, bubble_rect.size.y)
		)
		scaled_polygon = Geometry2D.convex_hull(scaled_polygon)
	get_window().mouse_passthrough_polygon = scaled_polygon


func _layout_notification_panel() -> void:
	if notification_panel == null:
		return
	var actionable := _notification_is_actionable()
	var target_position := Vector2.ZERO
	var target_size := Vector2.ZERO
	if actionable:
		target_position = (
			Vector2(48, 30) * settings.display_scale
		)
		target_size = (
			Vector2(264, 102) * settings.display_scale
		)
		notification_label.max_lines_visible = 3
	else:
		target_position = (
			Vector2(62, 52) * settings.display_scale
		)
		target_size = (
			Vector2(236, 60) * settings.display_scale
		)
		notification_label.max_lines_visible = 2
	# Give the wrapping label its final width before the first container
	# sort. Without this, Godot can calculate a one-character-wide
	# minimum size and produce an extremely tall first Pet Note.
	notification_label.custom_minimum_size = Vector2(
		target_size.x - 20.0 * settings.display_scale,
		0
	)
	notification_panel.position = target_position
	notification_panel.size = target_size


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

	_set_menu_checked(
		window_menu,
		MENU_ALWAYS_ON_TOP,
		settings.always_on_top
	)
	_set_menu_checked(
		activity_menu,
		MENU_ACTIVITY_SENSING,
		activity_monitor.listening
	)
	_set_menu_disabled(
		activity_menu,
		MENU_CLEAR_ACTIVITY,
		activity_stats.is_empty()
	)
	_set_menu_checked(
		window_menu,
		MENU_SCALE_75,
		is_equal_approx(settings.display_scale, 0.75)
	)
	_set_menu_checked(
		window_menu,
		MENU_SCALE_100,
		is_equal_approx(settings.display_scale, 1.0)
	)
	_set_menu_checked(
		window_menu,
		MENU_SCALE_125,
		is_equal_approx(settings.display_scale, 1.25)
	)
	_set_menu_checked(
		window_menu,
		MENU_SCALE_150,
		is_equal_approx(settings.display_scale, 1.5)
	)
	_update_timer_menu()
	_update_reminder_menu()
	for menu_id in pet_menu_id_to_pet_id:
		_set_menu_checked(
			pets_menu,
			int(menu_id),
			pet.get_pet_id() == pet_menu_id_to_pet_id[menu_id]
		)


func _update_reminder_menu() -> void:
	if (
		context_menu == null
		or reminder_menu == null
		or reminder_manager == null
	):
		return

	_set_menu_text(
		context_menu,
		MENU_REMINDERS_SUBMENU,
		_reminder_menu_title()
	)
	_set_menu_text(
		reminder_menu,
		MENU_REMINDER_STATUS,
		_reminder_status_summary()
	)
	for kind in [
		TimerManagerScript.Kind.WATER,
		TimerManagerScript.Kind.STAND,
	]:
		var menu_id := (
			MENU_WATER_REMINDER
			if kind == TimerManagerScript.Kind.WATER
			else MENU_STAND_REMINDER
		)
		_set_menu_text(
			reminder_menu,
			menu_id,
			_reminder_kind_status(kind)
		)
		_set_menu_checked(
			reminder_menu,
			menu_id,
			reminder_manager.is_enabled(kind)
		)
	_set_menu_text(
		reminder_menu,
		MENU_QUIET_HOURS,
		_quiet_hours_text()
	)

	var due_kind: int = reminder_manager.current_due_kind()
	var has_due := due_kind != TimerManagerScript.Kind.NONE
	var due_name := _reminder_kind_name(due_kind).to_lower()
	var snooze_duration := _format_setting_duration(
		reminder_manager.snooze_seconds()
	)
	_set_menu_text(
		reminder_menu,
		MENU_COMPLETE_REMINDER,
		_text("complete_named_reminder", [due_name])
		if has_due
		else _text("complete_reminder")
	)
	_set_menu_text(
		reminder_menu,
		MENU_SNOOZE_REMINDER,
		_text("snooze_named_reminder", [due_name, snooze_duration])
		if has_due
		else _text("snooze_reminder", [snooze_duration])
	)
	_set_menu_text(
		reminder_menu,
		MENU_SKIP_REMINDER,
		_text("skip_named_reminder", [due_name])
		if has_due
		else _text("skip_reminder")
	)
	_set_menu_text(
		reminder_menu,
		MENU_PAUSE_REMINDER_TODAY,
		_text("pause_named_reminder_today", [due_name])
		if has_due
		else _text("pause_reminder_today")
	)
	_set_menu_text(
		reminder_menu,
		MENU_STOP_REMINDER,
		_text("stop_named_reminder", [due_name])
		if has_due
		else _text("stop_reminder")
	)
	for menu_id in [
		MENU_COMPLETE_REMINDER,
		MENU_SNOOZE_REMINDER,
		MENU_SKIP_REMINDER,
		MENU_PAUSE_REMINDER_TODAY,
		MENU_STOP_REMINDER,
	]:
		_set_menu_disabled(reminder_menu, menu_id, not has_due)


func _reminder_menu_title() -> String:
	if reminder_manager == null:
		return _text("reminders_off")
	var due_count := 0
	var enabled_count := 0
	for kind in [
		TimerManagerScript.Kind.WATER,
		TimerManagerScript.Kind.STAND,
	]:
		if reminder_manager.is_enabled(kind):
			enabled_count += 1
		if reminder_manager.is_due(kind):
			due_count += 1
	if due_count > 0:
		if reminder_manager.is_quiet_now():
			return _text("reminders_quiet")
		return _text("reminders_due", [due_count])
	if enabled_count == 0:
		return _text("reminders_off")
	if reminder_manager.is_quiet_now():
		return _text("reminders_quiet")
	return _text("reminders_active")


func _reminder_status_summary() -> String:
	if reminder_manager == null:
		return _text("health_reminders_off")
	if reminder_manager.is_quiet_now():
		return _text("health_reminders_quiet")
	var due_kind: int = reminder_manager.current_due_kind()
	if due_kind != TimerManagerScript.Kind.NONE:
		return _text(
			"health_reminder_ready",
			[_reminder_kind_name(due_kind)]
		)
	var enabled_count := 0
	for kind in [
		TimerManagerScript.Kind.WATER,
		TimerManagerScript.Kind.STAND,
	]:
		if reminder_manager.is_enabled(kind):
			enabled_count += 1
	if enabled_count == 0:
		return _text("health_reminders_off")
	return _text("health_reminders_active", [enabled_count])


func _reminder_kind_status(kind: int) -> String:
	var name := _reminder_kind_name(kind)
	if reminder_manager == null or not reminder_manager.is_enabled(kind):
		return _text("reminder_off", [name])
	if reminder_manager.is_due(kind):
		return _text("reminder_due", [name])
	if reminder_manager.is_paused_today(kind):
		return _text("reminder_paused_today", [name])
	return _text("reminder_countdown", [
		name,
		_format_duration(reminder_manager.remaining_seconds(kind)),
	])


func _reminder_kind_name(kind: int) -> String:
	if kind == TimerManagerScript.Kind.WATER:
		return _text("water")
	if kind == TimerManagerScript.Kind.STAND:
		return _text("stand")
	return _text("health")


func _quiet_hours_text() -> String:
	if reminder_manager == null or not reminder_manager.quiet_hours_enabled():
		return _text("quiet_hours_off")
	return _text("quiet_hours_range", [
		reminder_manager.quiet_start_hour(),
		reminder_manager.quiet_end_hour(),
	])


func _format_setting_duration(duration_seconds: int) -> String:
	return _text("duration_minutes", [
		maxi(1, roundi(duration_seconds / 60.0)),
	])


func _focus_duration_seconds() -> int:
	return clampi(
		int(settings.get("focus_duration_seconds", FOCUS_DURATION_SECONDS)),
		60,
		240 * 60
	)


func _break_duration_seconds() -> int:
	return clampi(
		int(settings.get("break_duration_seconds", BREAK_DURATION_SECONDS)),
		60,
		120 * 60
	)


func _focus_start_menu_text() -> String:
	return _text(
		"start_focus",
		[_format_setting_duration(_focus_duration_seconds())]
	)


func _break_start_menu_text() -> String:
	return _text(
		"start_break",
		[_format_setting_duration(_break_duration_seconds())]
	)


func _update_timer_menu() -> void:
	if context_menu == null or focus_menu == null or timer_manager == null:
		return

	_set_menu_text(
		context_menu,
		MENU_FOCUS_SUBMENU,
		_focus_menu_title()
	)
	_set_menu_text(focus_menu, MENU_TIMER_STATUS, _timer_status_summary())
	_set_menu_text(
		focus_menu,
		MENU_START_FOCUS,
		_focus_start_menu_text()
	)
	_set_menu_text(
		focus_menu,
		MENU_START_BREAK,
		_break_start_menu_text()
	)
	var is_idle: bool = timer_manager.state == TimerManagerScript.State.IDLE
	var is_waiting: bool = (
		timer_manager.state == TimerManagerScript.State.WAITING_NEXT
	)
	var can_start: bool = is_idle or is_waiting
	_set_menu_disabled(focus_menu, MENU_START_FOCUS, not can_start)
	_set_menu_disabled(focus_menu, MENU_START_BREAK, not can_start)
	_set_menu_disabled(developer_menu, MENU_DEV_FOCUS_1S, not can_start)
	_set_menu_disabled(developer_menu, MENU_DEV_BREAK_1S, not can_start)
	_set_menu_disabled(
		focus_menu,
		MENU_PAUSE_RESUME_TIMER,
		timer_manager.state != TimerManagerScript.State.RUNNING
		and timer_manager.state != TimerManagerScript.State.PAUSED
	)
	_set_menu_disabled(
		focus_menu,
		MENU_CANCEL_TIMER,
		is_idle
	)
	_set_menu_disabled(
		focus_menu,
		MENU_CANCEL_AUTO_TRANSITION,
		not _has_auto_transition()
	)

	if timer_manager.state == TimerManagerScript.State.PAUSED:
		_set_menu_text(
			focus_menu,
			MENU_PAUSE_RESUME_TIMER,
			_text("resume_timer")
		)
	else:
		_set_menu_text(
			focus_menu,
			MENU_PAUSE_RESUME_TIMER,
			_text("pause_timer")
		)


func _focus_menu_title() -> String:
	if timer_manager == null or timer_manager.state == TimerManagerScript.State.IDLE:
		return _text("focus_idle")

	if timer_manager.state == TimerManagerScript.State.WAITING_NEXT:
		var completed_name := _timer_kind_name(timer_manager.kind)
		if _has_auto_transition():
			return _text("stage_complete_countdown", [
				completed_name,
				_format_duration(_auto_transition_remaining_seconds()),
			])
		return _text("stage_complete", [completed_name])

	var kind_name := _timer_kind_name(timer_manager.kind)
	if timer_manager.state == TimerManagerScript.State.PAUSED:
		return _text("stage_paused_countdown", [
			kind_name,
			_format_duration(timer_manager.remaining_seconds()),
		])
	return _text("stage_countdown", [
		kind_name,
		_format_duration(timer_manager.remaining_seconds()),
	])


func _timer_status_summary() -> String:
	if timer_manager == null or timer_manager.state == TimerManagerScript.State.IDLE:
		return _text("timer_idle")

	if timer_manager.state == TimerManagerScript.State.WAITING_NEXT:
		var completed_name := _timer_kind_name(timer_manager.kind)
		var next_name := _timer_kind_name(timer_manager.next_kind).to_lower()
		if _has_auto_transition():
			return _text("next_stage_countdown", [
				completed_name,
				next_name,
				_format_duration(_auto_transition_remaining_seconds()),
			])
		return _text("next_stage_ready", [
			completed_name,
			next_name,
		])

	var kind_name := _timer_kind_name(timer_manager.kind)
	if timer_manager.state == TimerManagerScript.State.PAUSED:
		return _text("timer_paused", [
			kind_name,
			_format_duration(timer_manager.remaining_seconds()),
		])
	return _text("timer_running", [
		kind_name,
		_format_duration(timer_manager.remaining_seconds()),
	])


func _timer_kind_name(timer_kind: int) -> String:
	if timer_kind == TimerManagerScript.Kind.FOCUS:
		return _text("focus")
	if timer_kind == TimerManagerScript.Kind.BREAK:
		return _text("break")
	return _text("timer")


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
		if kind == TimerManagerScript.Kind.BREAK:
			_show_pending_health_reminder()


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
	if _focus_is_running() and ambient_card_active:
		_hide_notification()
	_update_timer_menu()
	if context_menu != null and not restoring_saved_state:
		_save_settings()


func _handle_timer_tick(_remaining_seconds: int) -> void:
	_update_timer_menu()


func _handle_timer_completed(kind: int) -> void:
	pet.react_to_reminder()
	if kind == TimerManagerScript.Kind.FOCUS:
		if restoring_timer:
			_show_notification(
				_text("focus_complete_ready"),
				10.0
			)
		else:
			_begin_auto_break_countdown()
	elif kind == TimerManagerScript.Kind.BREAK:
		_show_notification(
			_text("break_complete"),
			10.0
		)


func _restore_reminders() -> void:
	restoring_reminders = true
	reminder_manager.restore(settings.reminder_snapshot)
	restoring_reminders = false
	_refresh_notification_action_texts()
	_update_reminder_menu()
	if not notification_panel.visible:
		_show_pending_health_reminder()


func _handle_reminder_changed() -> void:
	if reminder_manager == null:
		return
	settings.reminder_snapshot = reminder_manager.snapshot()
	_update_reminder_menu()
	if context_menu != null and not restoring_saved_state:
		_save_settings()


func _handle_reminder_tick(_kind: int, _remaining_seconds: int) -> void:
	_update_reminder_menu()


func _handle_reminder_due(_kind: int) -> void:
	_update_reminder_menu()
	if (
		restoring_reminders
		or _focus_is_running()
		or reminder_manager.is_quiet_now()
	):
		return
	_show_pending_health_reminder()


func _handle_quiet_state_changed(is_quiet: bool) -> void:
	_update_reminder_menu()
	if is_quiet:
		if _notification_is_actionable():
			_hide_notification()
		return
	_show_pending_health_reminder()


func _poll_check_ins() -> void:
	if check_in_manager == null or not check_in_manager.is_enabled():
		return
	if settings.calendar_notes_enabled:
		calendar_check_in_source.poll()
	_try_show_check_in()


func _handle_calendar_event_ready(event_data: Dictionary) -> void:
	if (
		check_in_manager == null
		or not check_in_manager.is_enabled()
		or not settings.calendar_notes_enabled
	):
		return
	var start_unix := float(event_data.get("start_unix", 0.0))
	var is_all_day := bool(event_data.get("is_all_day", false))
	var message := _text(
		"calendar_all_day_card",
		[str(event_data.get("title", ""))]
	)
	if not is_all_day:
		var remaining_minutes := maxi(
			1,
			ceili(
				(start_unix - Time.get_unix_time_from_system()) / 60.0
			)
		)
		message = _text("calendar_event_card", [
			str(event_data.get("title", "")),
			remaining_minutes,
		])
	check_in_manager.enqueue_card(
		"calendar:%s" % str(event_data.get("id", "")),
		"calendar",
		message,
		CheckInManagerScript.DEFAULT_DISPLAY_SECONDS,
		float(event_data.get("expires_unix", 0.0))
	)


func _handle_google_calendar_state_changed(
	_state: int,
	_message: String
) -> void:
	_refresh_google_calendar_status()


func _handle_google_calendar_refresh_token_received(
	refresh_token: String
) -> void:
	_set_google_calendar_explicit_disconnect(false)
	google_calendar_credential_busy = true
	google_calendar_credential_saved = false
	google_calendar_credential_error = ""
	google_calendar_credential_action = "write"
	if not google_calendar_credential_store.write_secret(
		_google_calendar_credential_target(),
		refresh_token
	):
		google_calendar_credential_busy = false
		google_calendar_credential_error = "write"
		google_calendar_credential_action = ""
	_refresh_google_calendar_status()


func _handle_google_calendar_refresh_token_invalidated() -> void:
	_set_google_calendar_explicit_disconnect(true)
	_start_google_calendar_credential_delete()


func _handle_google_calendar_credential_read(
	refresh_token: String,
	success: bool,
	_error: String
) -> void:
	google_calendar_credential_busy = false
	google_calendar_credential_action = ""
	if not success:
		google_calendar_credential_error = "read"
	elif refresh_token.is_empty():
		google_calendar_credential_saved = false
	else:
		google_calendar_credential_saved = true
		if not google_calendar_provider.restore_refresh_token(refresh_token):
			google_calendar_credential_error = "read"
	_refresh_google_calendar_status()


func _handle_google_calendar_credential_written(
	success: bool,
	_error: String
) -> void:
	google_calendar_credential_busy = false
	google_calendar_credential_action = ""
	google_calendar_credential_saved = success
	google_calendar_credential_error = "" if success else "write"
	_refresh_google_calendar_status()


func _handle_google_calendar_credential_deleted(
	success: bool,
	_error: String
) -> void:
	google_calendar_credential_busy = false
	google_calendar_credential_action = ""
	google_calendar_credential_saved = false
	google_calendar_credential_error = "" if success else "delete"
	_refresh_google_calendar_status()


func _handle_google_calendar_events_updated(
	events: Array[Dictionary]
) -> void:
	calendar_check_in_source.replace_events(events)
	if (
		settings.ambient_cards_enabled
		and settings.calendar_notes_enabled
	):
		calendar_check_in_source.poll()
		_try_show_check_in()


func _try_show_check_in() -> bool:
	if (
		check_in_manager == null
		or not check_in_manager.is_enabled()
		or _focus_is_running()
		or reminder_manager.is_quiet_now()
		or reminder_manager.current_due_kind()
		!= TimerManagerScript.Kind.NONE
		or notification_panel.visible
		or duration_settings_window.visible
		or language_settings_window.visible
		or pet_notes_settings_window.visible
	):
		return false
	var card: Dictionary = check_in_manager.take_next()
	if card.is_empty():
		return false
	_show_ambient_card(
		str(card.get("message", "")),
		int(
			card.get(
				"display_seconds",
				CheckInManagerScript.DEFAULT_DISPLAY_SECONDS
			)
		)
	)
	return true


func _toggle_reminder(kind: int) -> void:
	var enable: bool = not reminder_manager.is_enabled(kind)
	if not reminder_manager.set_enabled(kind, enable):
		return
	if enable:
		var enabled_key := (
			"water_enabled"
			if kind == TimerManagerScript.Kind.WATER
			else "stand_enabled"
		)
		_show_notification(
			_text(enabled_key, [
				_format_setting_duration(
					reminder_manager.interval_seconds(kind)
				),
			]),
			4.0
		)
	else:
		var disabled_key := (
			"water_disabled"
			if kind == TimerManagerScript.Kind.WATER
			else "stand_disabled"
		)
		_show_notification(
			_text(disabled_key),
			3.0
		)


func _cycle_quiet_hours() -> void:
	var current := Vector2i(-1, -1)
	if reminder_manager.quiet_hours_enabled():
		current = Vector2i(
			reminder_manager.quiet_start_hour(),
			reminder_manager.quiet_end_hour()
		)
	var current_index := QUIET_HOURS_PRESETS.find(current)
	var next_index := (
		0
		if current_index < 0
		else (current_index + 1) % QUIET_HOURS_PRESETS.size()
	)
	var next_hours: Vector2i = QUIET_HOURS_PRESETS[next_index]
	var enabled := next_hours.x >= 0
	var start_hour := 22 if not enabled else next_hours.x
	var end_hour := 8 if not enabled else next_hours.y
	if not reminder_manager.set_quiet_hours(
		enabled,
		start_hour,
		end_hour
	):
		return
	if enabled:
		_show_notification(
			_text("quiet_hours_updated", [start_hour, end_hour]),
			4.0
		)
	else:
		if reminder_manager.current_due_kind() != TimerManagerScript.Kind.NONE:
			_show_pending_health_reminder()
		else:
			_show_notification(_text("quiet_hours_disabled"), 3.0)


func _handle_complete_reminder() -> void:
	var kind: int = reminder_manager.current_due_kind()
	if reminder_manager.complete_due() == TimerManagerScript.Kind.NONE:
		return
	if not _show_pending_health_reminder():
		_show_notification(
			_text("completed_next", [
				_reminder_kind_name(kind).to_lower(),
				_format_setting_duration(
					reminder_manager.interval_seconds(kind)
				),
			]),
			5.0
		)


func _handle_snooze_reminder() -> void:
	var kind: int = reminder_manager.current_due_kind()
	if reminder_manager.snooze_due() == TimerManagerScript.Kind.NONE:
		return
	if not _show_pending_health_reminder():
		_show_notification(
			_text("snoozed", [
				_reminder_kind_name(kind),
				_format_setting_duration(
					reminder_manager.snooze_seconds()
				),
			]),
			4.0
		)


func _handle_skip_reminder() -> void:
	var kind: int = reminder_manager.current_due_kind()
	if reminder_manager.skip_due() == TimerManagerScript.Kind.NONE:
		return
	if not _show_pending_health_reminder():
		_show_notification(
			_text(
				"skipped",
				[_reminder_kind_name(kind).to_lower()]
			),
			4.0
		)


func _handle_pause_reminder_today() -> void:
	var kind: int = reminder_manager.current_due_kind()
	if (
		reminder_manager.pause_due_today()
		== TimerManagerScript.Kind.NONE
	):
		return
	if not _show_pending_health_reminder():
		_show_notification(
			_text(
				"paused_until_tomorrow",
				[_reminder_kind_name(kind)]
			),
			5.0
		)


func _handle_stop_reminder() -> void:
	var kind: int = reminder_manager.current_due_kind()
	if (
		reminder_manager.disable_due()
		== TimerManagerScript.Kind.NONE
	):
		return
	_hide_notification()
	if not _show_pending_health_reminder():
		_show_notification(
			_text("stopped_reminders", [
				_reminder_kind_name(kind),
			]),
			5.0
		)


func _show_pending_health_reminder() -> bool:
	if (
		reminder_manager == null
		or _focus_is_running()
		or reminder_manager.is_quiet_now()
	):
		return false
	var kind: int = reminder_manager.current_due_kind()
	if kind == TimerManagerScript.Kind.NONE:
		return false
	pet.react_to_reminder()
	if kind == TimerManagerScript.Kind.WATER:
		_show_actionable_notification(kind, _text("water_prompt"))
	else:
		_show_actionable_notification(kind, _text("stand_prompt"))
	return true


func _focus_is_running() -> bool:
	return (
		timer_manager != null
		and timer_manager.kind == TimerManagerScript.Kind.FOCUS
		and (
			timer_manager.state == TimerManagerScript.State.RUNNING
			or timer_manager.state == TimerManagerScript.State.PAUSED
		)
	)


func _begin_auto_break_countdown() -> void:
	_cancel_auto_transition(false)
	_set_notification_actions(TimerManagerScript.Kind.NONE)
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
			_break_duration_seconds()
		)
		return

	_cancel_auto_transition(true)


func _update_auto_break_countdown() -> void:
	var remaining := _auto_transition_remaining_seconds()
	notification_label.text = _text(
		"focus_break_countdown",
		[remaining]
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
			_text("focus_complete_ready"),
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
	_set_notification_actions(TimerManagerScript.Kind.NONE)
	notification_label.text = message
	notification_panel.visible = true
	notification_timer.start(maxf(1.0, duration_seconds))


func _show_ambient_card(message: String, duration_seconds: int) -> void:
	_clear_ambient_card_state()
	notification_panel.visible = false
	notification_action_kind = TimerManagerScript.Kind.NONE
	ambient_card_active = true
	var safe_duration := clampi(
		duration_seconds,
		CheckInManagerScript.MIN_DISPLAY_SECONDS,
		CheckInManagerScript.MAX_DISPLAY_SECONDS
	)
	ambient_card_deadline_unix = (
		Time.get_unix_time_from_system() + safe_duration
	)
	notification_label.text = message
	notification_actions.visible = true
	notification_done_button.visible = true
	notification_snooze_button.visible = false
	notification_more_button.visible = false
	notification_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_update_ambient_card_button()
	_layout_notification_panel()
	ambient_card_tick_timer.start()
	notification_timer.start(float(safe_duration))
	_present_ambient_card.call_deferred()


func _present_ambient_card() -> void:
	if not ambient_card_active:
		return
	_layout_notification_panel()
	notification_panel.visible = true
	_update_mouse_passthrough(get_window().size)


func _show_actionable_notification(kind: int, message: String) -> void:
	_set_notification_actions(kind)
	notification_label.text = message
	notification_panel.visible = true
	notification_timer.start(10.0)
	_update_mouse_passthrough(get_window().size)


func _set_notification_actions(kind: int) -> void:
	_clear_ambient_card_state()
	notification_action_kind = kind
	if notification_actions == null:
		return
	var actionable := kind != TimerManagerScript.Kind.NONE
	notification_actions.visible = actionable
	notification_done_button.visible = true
	notification_snooze_button.visible = true
	notification_more_button.visible = true
	notification_panel.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if actionable
		else Control.MOUSE_FILTER_IGNORE
	)
	_refresh_notification_action_texts()
	_layout_notification_panel()
	if get_window().size.x > 0:
		_update_mouse_passthrough(get_window().size)


func _handle_primary_notification_action() -> void:
	if ambient_card_active:
		_hide_notification()
		return
	_handle_complete_reminder()


func _handle_ambient_card_tick() -> void:
	if not ambient_card_active:
		ambient_card_tick_timer.stop()
		return
	if _ambient_card_remaining_seconds() <= 0:
		_hide_notification()
		return
	_update_ambient_card_button()


func _update_ambient_card_button() -> void:
	if not ambient_card_active:
		return
	notification_done_button.text = _text(
		"bubble_ok_countdown",
		[_ambient_card_remaining_seconds()]
	)


func _ambient_card_remaining_seconds() -> int:
	if ambient_card_deadline_unix <= 0.0:
		return 0
	return maxi(
		0,
		ceili(
			ambient_card_deadline_unix
			- Time.get_unix_time_from_system()
		)
	)


func _clear_ambient_card_state() -> void:
	ambient_card_active = false
	ambient_card_deadline_unix = 0.0
	if ambient_card_tick_timer != null:
		ambient_card_tick_timer.stop()


func _notification_is_actionable() -> bool:
	return (
		ambient_card_active
		or notification_action_kind != TimerManagerScript.Kind.NONE
	)


func _open_reminder_action_menu() -> void:
	if notification_action_kind == TimerManagerScript.Kind.NONE:
		return
	reminder_action_menu.position = DisplayServer.mouse_get_position()
	reminder_action_menu.popup()


func _hide_notification() -> void:
	if notification_timer != null:
		notification_timer.stop()
	if notification_panel != null:
		notification_panel.visible = false
	if reminder_action_menu != null:
		reminder_action_menu.hide()
	_clear_ambient_card_state()
	_set_notification_actions(TimerManagerScript.Kind.NONE)


func _update_activity_menu() -> void:
	if activity_menu == null:
		return

	var counts_index := activity_menu.get_item_index(MENU_ACTIVITY_COUNTS)
	if counts_index >= 0:
		activity_menu.set_item_text(counts_index, _activity_summary())
	var status_index := activity_menu.get_item_index(MENU_ACTIVITY_STATUS)
	if status_index >= 0:
		activity_menu.set_item_text(status_index, _activity_source_summary())
	_update_menu_checks()


func _activity_source_summary() -> String:
	if activity_adapter == null:
		return _text("activity_source", [_text("source_unavailable")])
	var status_key := "source_stopped"
	match activity_adapter.state:
		WindowsActivityAdapterScript.State.STARTING:
			status_key = "source_starting"
		WindowsActivityAdapterScript.State.RUNNING:
			status_key = "source_running"
		WindowsActivityAdapterScript.State.ERROR:
			status_key = "source_error"
	return _text("activity_source", [_text(status_key)])


func _activity_summary() -> String:
	return _text("session_activity", [
		activity_stats.keyboard_count,
		activity_stats.mouse_count,
	])


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
		_text("privacy_title"),
		_activity_privacy_message(),
		PackedStringArray([
			_text("privacy_enable"),
			_text("privacy_keep_off"),
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
	return _text("privacy_message")


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
			_text("activity_error", [message]),
			_text("activity_error_title")
		)


func _handle_activity_batch(batch) -> void:
	activity_stats.record(batch)

	if batch.keyboard_count > 0 and batch.keyboard_count >= batch.mouse_count:
		pet.react_to_keyboard(batch.keyboard_count)
	elif batch.mouse_count > 0:
		pet.react_to_mouse(batch.mouse_count)


func _set_menu_checked(menu: PopupMenu, id: int, checked: bool) -> void:
	if menu == null:
		return
	var index := menu.get_item_index(id)
	if index >= 0:
		menu.set_item_checked(index, checked)


func _set_menu_disabled(menu: PopupMenu, id: int, disabled: bool) -> void:
	if menu == null:
		return
	var index := menu.get_item_index(id)
	if index >= 0:
		menu.set_item_disabled(index, disabled)


func _set_menu_text(menu: PopupMenu, id: int, text: String) -> void:
	if menu == null:
		return
	var index := menu.get_item_index(id)
	if index >= 0:
		menu.set_item_text(index, text)


func _text(key: String, values: Array = []) -> String:
	return AppLocalizationScript.text(
		str(settings.get("language", AppLocalizationScript.ENGLISH)),
		key,
		values
	)


func _set_language(language: String) -> void:
	var normalized: String = AppLocalizationScript.normalize(language)
	if settings.language == normalized:
		return
	_hide_notification()
	settings.language = normalized
	_refresh_localized_ui()
	_save_settings()
	_show_pending_health_reminder()


func _refresh_localized_ui() -> void:
	hint_label.text = _text("hint")
	get_window().title = _text("window_title", [pet.get_display_name()])

	_set_menu_text(
		focus_menu,
		MENU_START_FOCUS,
		_focus_start_menu_text()
	)
	_set_menu_text(
		focus_menu,
		MENU_START_BREAK,
		_break_start_menu_text()
	)
	_set_menu_text(focus_menu, MENU_CANCEL_TIMER, _text("cancel_timer"))
	_set_menu_text(
		focus_menu,
		MENU_CANCEL_AUTO_TRANSITION,
		_text("cancel_auto_start")
	)
	_set_menu_text(
		activity_menu,
		MENU_ACTIVITY_SENSING,
		_text("activity_sensing")
	)
	_set_menu_text(
		activity_menu,
		MENU_CLEAR_ACTIVITY,
		_text("clear_activity")
	)
	_set_menu_text(
		window_menu,
		MENU_ALWAYS_ON_TOP,
		_text("always_on_top")
	)
	for scale_data in [
		[MENU_SCALE_75, 75],
		[MENU_SCALE_100, 100],
		[MENU_SCALE_125, 125],
		[MENU_SCALE_150, 150],
	]:
		_set_menu_text(
			window_menu,
			int(scale_data[0]),
			_text("scale", [int(scale_data[1])])
		)
	_set_menu_text(
		settings_menu,
		MENU_DURATION_SETTINGS,
		_text("duration_settings_menu")
	)
	_set_menu_text(
		settings_menu,
		MENU_LANGUAGE_SETTINGS,
		_text("language_settings_menu")
	)
	_set_menu_text(
		settings_menu,
		MENU_AMBIENT_CARDS,
		_text("ambient_cards")
	)
	_set_menu_text(context_menu, MENU_ACTIVITY_SUBMENU, _text("activity"))
	_set_menu_text(context_menu, MENU_PETS_SUBMENU, _text("pets"))
	_set_menu_text(context_menu, MENU_WINDOW_SUBMENU, _text("window"))
	_set_menu_text(context_menu, MENU_SETTINGS_SUBMENU, _text("settings"))
	_set_menu_text(context_menu, MENU_EXIT, _text("exit"))
	if developer_menu != null:
		_set_menu_text(
			developer_menu,
			MENU_DEV_FOCUS_1S,
			_text("dev_focus")
		)
		_set_menu_text(
			developer_menu,
			MENU_DEV_BREAK_1S,
			_text("dev_break")
		)
		_set_menu_text(
			developer_menu,
			MENU_DEV_WATER_1S,
			_text("dev_water")
		)
		_set_menu_text(
			developer_menu,
			MENU_DEV_STAND_1S,
			_text("dev_stand")
		)
		_set_menu_text(
			developer_menu,
			MENU_DEV_AMBIENT_CARD,
			_text("dev_ambient_card")
		)
		_set_menu_text(
			context_menu,
			MENU_DEVELOPER_SUBMENU,
			_text("developer")
		)
	_refresh_duration_settings_texts()
	_refresh_language_settings_texts()
	_refresh_pet_notes_settings_texts()
	_refresh_notification_action_texts()
	_refresh_tray_ui()
	_update_activity_menu()
	_update_menu_checks()


func _load_settings() -> void:
	settings.language = AppLocalizationScript.default_language()
	var config := ConfigFile.new()
	var settings_file := _settings_file_path()
	if config.load(settings_file) != OK:
		return
	recovered_legacy_test_settings = (
		settings_file == SETTINGS_FILE
		and _recover_legacy_test_settings(config)
	)
	if recovered_legacy_test_settings:
		config.save(settings_file)

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
	settings.ambient_cards_enabled = bool(
		config.get_value(
			"check_ins",
			"ambient_cards_enabled",
			false
		)
	)
	settings.calendar_notes_enabled = bool(
		config.get_value(
			"check_ins",
			"calendar_notes_enabled",
			false
		)
	)
	settings.google_calendar_explicitly_disconnected = bool(
		config.get_value(
			"check_ins",
			"google_calendar_explicitly_disconnected",
			false
		)
	)
	settings.language = AppLocalizationScript.normalize(
		str(
			config.get_value(
				"interface",
				"language",
				settings.language
			)
		)
	)
	settings.focus_duration_seconds = clampi(
		int(
			config.get_value(
				"timer_defaults",
				"focus_duration_seconds",
				FOCUS_DURATION_SECONDS
			)
		),
		60,
		240 * 60
	)
	settings.break_duration_seconds = clampi(
		int(
			config.get_value(
				"timer_defaults",
				"break_duration_seconds",
				BREAK_DURATION_SECONDS
			)
		),
		60,
		120 * 60
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
	var saved_reminders = config.get_value(
		"reminders",
		"snapshot",
		{}
	)
	settings.reminder_snapshot = (
		saved_reminders
		if saved_reminders is Dictionary
		else {}
	)
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
	if reminder_manager != null:
		settings.reminder_snapshot = reminder_manager.snapshot()

	var config := ConfigFile.new()
	config.set_value("window", "always_on_top", settings.always_on_top)
	config.set_value("window", "display_scale", settings.display_scale)
	config.set_value("pet", "selected_pet_id", settings.selected_pet_id)
	config.set_value("interface", "language", settings.language)
	config.set_value(
		"timer_defaults",
		"focus_duration_seconds",
		_focus_duration_seconds()
	)
	config.set_value(
		"timer_defaults",
		"break_duration_seconds",
		_break_duration_seconds()
	)
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
	config.set_value(
		"check_ins",
		"ambient_cards_enabled",
		settings.ambient_cards_enabled
	)
	config.set_value(
		"check_ins",
		"calendar_notes_enabled",
		settings.calendar_notes_enabled
	)
	config.set_value(
		"check_ins",
		"google_calendar_explicitly_disconnected",
		settings.google_calendar_explicitly_disconnected
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
	config.set_value(
		"reminders",
		"snapshot",
		settings.reminder_snapshot
	)
	config.set_value("window", "has_saved_position", settings.has_saved_position)
	config.set_value("window", "position_x", settings.window_position.x)
	config.set_value("window", "position_y", settings.window_position.y)
	config.save(_settings_file_path())


func _settings_file_path() -> String:
	var override_path := OS.get_environment(
		"DESKTOP_PET_SETTINGS_FILE"
	).strip_edges()
	if not override_path.is_empty():
		return override_path
	if not _is_automated_test_run():
		return SETTINGS_FILE
	if _test_settings_file.is_empty():
		_test_settings_file = TEST_SETTINGS_FILE_PATTERN % OS.get_process_id()
	if not _test_settings_initialized:
		_test_settings_initialized = true
		if FileAccess.file_exists(_test_settings_file):
			DirAccess.remove_absolute(
				ProjectSettings.globalize_path(_test_settings_file)
			)
	return _test_settings_file


func _is_automated_test_run() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	for argument in OS.get_cmdline_args():
		var normalized := str(argument).replace("\\", "/").to_lower()
		if (
			normalized.ends_with("_test.gd")
			and (
				normalized.begins_with("tests/")
				or "/tests/" in normalized
			)
		):
			return true
	return false


func _recover_legacy_test_settings(config: ConfigFile) -> bool:
	if (
		int(config.get_value(
			"timer_defaults",
			"focus_duration_seconds",
			0
		)) != 40 * 60
		or int(config.get_value(
			"timer_defaults",
			"break_duration_seconds",
			0
		)) != 8 * 60
	):
		return false
	var snapshot = config.get_value("reminders", "snapshot", {})
	if not snapshot is Dictionary:
		return false
	var preferences = snapshot.get("preferences", {})
	var water = snapshot.get("water", {})
	var stand = snapshot.get("stand", {})
	if (
		not preferences is Dictionary
		or not water is Dictionary
		or not stand is Dictionary
		or int(preferences.get("water_interval_seconds", 0)) != 75 * 60
		or int(preferences.get("stand_interval_seconds", 0)) != 35 * 60
		or int(preferences.get("snooze_seconds", 0)) != 15 * 60
		or not bool(preferences.get("quiet_enabled", false))
		or not bool(water.get("enabled", false))
		or not bool(stand.get("enabled", false))
	):
		return false

	config.set_value(
		"timer_defaults",
		"focus_duration_seconds",
		FOCUS_DURATION_SECONDS
	)
	config.set_value(
		"timer_defaults",
		"break_duration_seconds",
		BREAK_DURATION_SECONDS
	)
	config.set_value("timer", "state", TimerManagerScript.State.IDLE)
	config.set_value("timer", "kind", TimerManagerScript.Kind.NONE)
	config.set_value("timer", "next_kind", TimerManagerScript.Kind.NONE)
	config.set_value("timer", "end_unix", 0.0)
	config.set_value("timer", "paused_remaining", 0.0)
	config.set_value("reminders", "snapshot", {})
	return true


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
