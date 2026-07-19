extends Node

const BASE_WINDOW_SIZE := 360
const DEFAULT_PET_ID := &"leo"

const MENU_ALWAYS_ON_TOP := 10
const MENU_DEMO_KEYBOARD := 20
const MENU_DEMO_MOUSE := 21
const MENU_SCALE_75 := 30
const MENU_SCALE_100 := 31
const MENU_SCALE_125 := 32
const MENU_SCALE_150 := 33
const MENU_EXIT := 90
const MENU_PET_BASE := 1000

const SETTINGS_FILE := "user://prototype-settings.cfg"

@onready var pet: PetVisual = $PetVisual

var context_menu: PopupMenu
var hint_label: Label
var pet_definitions: Array[PetDefinition] = []
var pet_menu_id_to_pet_id: Dictionary = {}
var settings := {
	"always_on_top": true,
	"display_scale": 1.0,
	"selected_pet_id": String(DEFAULT_PET_ID),
	"has_saved_position": false,
	"window_position": Vector2i.ZERO,
}

var dragging := false
var drag_moved := false
var drag_offset := Vector2i.ZERO
var drag_start := Vector2i.ZERO
var shutting_down := false


func _ready() -> void:
	_load_settings()
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
	_update_menu_checks()
	_start_preview_capture_if_requested()


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


func _build_context_menu() -> void:
	context_menu = PopupMenu.new()
	# Keep the menu outside the transparent pet window. Otherwise the main
	# window's mouse-passthrough polygon also clips the embedded popup.
	context_menu.prefer_native_menu = true
	context_menu.force_native = true
	context_menu.transparent = false
	context_menu.add_check_item("Always on top", MENU_ALWAYS_ON_TOP)
	context_menu.add_item("Preview keyboard reaction", MENU_DEMO_KEYBOARD)
	context_menu.add_item("Preview mouse reaction", MENU_DEMO_MOUSE)
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
			pet.react_to_click()
		_save_settings()

	get_viewport().set_input_as_handled()


func _handle_menu_item(id: int) -> void:
	if pet_menu_id_to_pet_id.has(id):
		_select_pet(StringName(pet_menu_id_to_pet_id[id]))
		return

	match id:
		MENU_ALWAYS_ON_TOP:
			settings.always_on_top = not settings.always_on_top
			get_window().always_on_top = settings.always_on_top
		MENU_DEMO_KEYBOARD:
			pet.react_to_keyboard(4)
		MENU_DEMO_MOUSE:
			pet.react_to_mouse(2)
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

	for screen in DisplayServer.get_screen_count():
		var usable := DisplayServer.screen_get_usable_rect(screen)
		var overlap_width := maxi(
			0,
			mini(position.x + window_size.x, usable.end.x)
			- maxi(position.x, usable.position.x)
		)
		var overlap_height := maxi(
			0,
			mini(position.y + window_size.y, usable.end.y)
			- maxi(position.y, usable.position.y)
		)
		var overlap_area := overlap_width * overlap_height
		if overlap_area > largest_overlap:
			largest_overlap = overlap_area
			selected_usable = usable

	var maximum_x := maxi(
		selected_usable.position.x,
		selected_usable.end.x - window_size.x
	)
	var maximum_y := maxi(
		selected_usable.position.y,
		selected_usable.end.y - window_size.y
	)
	return Vector2i(
		clampi(position.x, selected_usable.position.x, maximum_x),
		clampi(position.y, selected_usable.position.y, maximum_y)
	)


func _update_menu_checks() -> void:
	if context_menu == null:
		return

	_set_menu_checked(MENU_ALWAYS_ON_TOP, settings.always_on_top)
	_set_menu_checked(MENU_SCALE_75, is_equal_approx(settings.display_scale, 0.75))
	_set_menu_checked(MENU_SCALE_100, is_equal_approx(settings.display_scale, 1.0))
	_set_menu_checked(MENU_SCALE_125, is_equal_approx(settings.display_scale, 1.25))
	_set_menu_checked(MENU_SCALE_150, is_equal_approx(settings.display_scale, 1.5))
	for menu_id in pet_menu_id_to_pet_id:
		_set_menu_checked(
			int(menu_id),
			pet.get_pet_id() == pet_menu_id_to_pet_id[menu_id]
		)


func _set_menu_checked(id: int, checked: bool) -> void:
	var index := context_menu.get_item_index(id)
	if index >= 0:
		context_menu.set_item_checked(index, checked)


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

	var config := ConfigFile.new()
	config.set_value("window", "always_on_top", settings.always_on_top)
	config.set_value("window", "display_scale", settings.display_scale)
	config.set_value("pet", "selected_pet_id", settings.selected_pet_id)
	config.set_value("window", "has_saved_position", settings.has_saved_position)
	config.set_value("window", "position_x", settings.window_position.x)
	config.set_value("window", "position_y", settings.window_position.y)
	config.save(SETTINGS_FILE)


func _shutdown() -> void:
	if shutting_down:
		return

	shutting_down = true
	_save_settings()
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
