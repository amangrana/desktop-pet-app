class_name ActivityCenterView
extends VBoxContainer

signal close_pressed
signal focus_action_pressed(action: String)
signal reminder_action_pressed(reminder: String, action: String)
signal durations_pressed
signal quiet_settings_pressed
signal clear_recent_pressed

const ActivityCenterViewStateScript := preload(
	"res://src/ui/activity_center_view_state.gd"
)

const COLOR_MUTED := Color("#8E839C")
const COLOR_NORMAL := Color("#B5A7C4")
const COLOR_ACTIVE := Color("#72C990")
const COLOR_ATTENTION := Color("#E58A8A")

var heading_label: Label
var note_label: Label
var pending_panel: PanelContainer
var pending_label: Label
var focus_title_label: Label
var focus_status_label: Label
var focus_dot: Label
var focus_actions: HBoxContainer
var focus_primary_button: Button
var focus_secondary_button: Button
var water_title_label: Label
var water_status_label: Label
var water_dot: Label
var water_inline_actions: HBoxContainer
var water_actions: HBoxContainer
var water_turn_on_button: Button
var water_running_turn_off_button: Button
var water_done_button: Button
var water_snooze_button: Button
var water_turn_off_button: Button
var stand_title_label: Label
var stand_status_label: Label
var stand_dot: Label
var stand_inline_actions: HBoxContainer
var stand_actions: HBoxContainer
var stand_turn_on_button: Button
var stand_running_turn_off_button: Button
var stand_done_button: Button
var stand_snooze_button: Button
var stand_turn_off_button: Button
var quiet_title_label: Label
var quiet_status_label: Label
var quiet_dot: Label
var quiet_inline_actions: HBoxContainer
var recent_title_label: Label
var recent_clear_button: Button
var recent_empty_label: Label
var recent_labels: Array[Label] = []
var duration_settings_button: Button
var quiet_settings_button: Button
var close_button: Button
var _built := false


func build() -> void:
	if _built:
		return
	_built = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)

	heading_label = Label.new()
	heading_label.add_theme_font_size_override("font_size", 22)
	heading_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(heading_label)

	note_label = Label.new()
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.custom_minimum_size = Vector2(0, 36)
	note_label.add_theme_font_size_override("font_size", 13)
	note_label.add_theme_color_override("font_color", Color("#C8BDD9"))
	add_child(note_label)

	pending_panel = PanelContainer.new()
	pending_panel.custom_minimum_size = Vector2(0, 34)
	pending_panel.add_theme_stylebox_override(
		"panel",
		_summary_style()
	)
	add_child(pending_panel)

	pending_label = Label.new()
	pending_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pending_label.add_theme_font_size_override("font_size", 12)
	pending_panel.add_child(pending_label)

	var focus_card := _create_status_card(0, 2)
	focus_title_label = focus_card.title
	focus_status_label = focus_card.status
	focus_dot = focus_card.dot
	focus_actions = focus_card.actions
	focus_primary_button = focus_card.buttons[0]
	focus_secondary_button = focus_card.buttons[1]
	focus_primary_button.pressed.connect(
		focus_action_pressed.emit.bind("primary")
	)
	focus_secondary_button.pressed.connect(
		focus_action_pressed.emit.bind("secondary")
	)
	_style_action_button(focus_primary_button, "primary")
	_style_action_button(focus_secondary_button, "secondary")
	add_child(focus_card.panel)

	var water_card := _create_status_card(2, 3)
	water_title_label = water_card.title
	water_status_label = water_card.status
	water_dot = water_card.dot
	water_inline_actions = water_card.inline_actions
	water_actions = water_card.actions
	water_turn_on_button = water_card.inline_buttons[0]
	water_running_turn_off_button = water_card.inline_buttons[1]
	water_done_button = water_card.buttons[0]
	water_snooze_button = water_card.buttons[1]
	water_turn_off_button = water_card.buttons[2]
	_connect_reminder_buttons(
		"water",
		water_turn_on_button,
		water_running_turn_off_button,
		water_done_button,
		water_snooze_button,
		water_turn_off_button
	)
	add_child(water_card.panel)

	var stand_card := _create_status_card(2, 3)
	stand_title_label = stand_card.title
	stand_status_label = stand_card.status
	stand_dot = stand_card.dot
	stand_inline_actions = stand_card.inline_actions
	stand_actions = stand_card.actions
	stand_turn_on_button = stand_card.inline_buttons[0]
	stand_running_turn_off_button = stand_card.inline_buttons[1]
	stand_done_button = stand_card.buttons[0]
	stand_snooze_button = stand_card.buttons[1]
	stand_turn_off_button = stand_card.buttons[2]
	_connect_reminder_buttons(
		"stand",
		stand_turn_on_button,
		stand_running_turn_off_button,
		stand_done_button,
		stand_snooze_button,
		stand_turn_off_button
	)
	add_child(stand_card.panel)

	var quiet_card := _create_status_card(1, 0)
	quiet_title_label = quiet_card.title
	quiet_status_label = quiet_card.status
	quiet_dot = quiet_card.dot
	quiet_inline_actions = quiet_card.inline_actions
	quiet_settings_button = quiet_card.inline_buttons[0]
	quiet_settings_button.pressed.connect(quiet_settings_pressed.emit)
	_style_action_button(quiet_settings_button, "secondary")
	quiet_inline_actions.visible = true
	add_child(quiet_card.panel)

	var recent_header := HBoxContainer.new()
	recent_header.add_theme_constant_override("separation", 8)
	add_child(recent_header)

	recent_title_label = Label.new()
	recent_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recent_title_label.add_theme_font_size_override("font_size", 14)
	recent_title_label.add_theme_color_override("font_color", Color.WHITE)
	recent_header.add_child(recent_title_label)

	recent_clear_button = Button.new()
	recent_clear_button.focus_mode = Control.FOCUS_NONE
	recent_clear_button.custom_minimum_size = Vector2(58, 25)
	recent_clear_button.add_theme_font_size_override("font_size", 11)
	recent_clear_button.pressed.connect(clear_recent_pressed.emit)
	_style_action_button(recent_clear_button, "secondary")
	recent_header.add_child(recent_clear_button)

	var recent_list := VBoxContainer.new()
	recent_list.add_theme_constant_override("separation", 3)
	add_child(recent_list)

	recent_empty_label = Label.new()
	recent_empty_label.add_theme_font_size_override("font_size", 12)
	recent_empty_label.add_theme_color_override(
		"font_color",
		Color("#9F93AE")
	)
	recent_list.add_child(recent_empty_label)

	for _index in ActivityCenterViewStateScript.MAX_RECENT_ROWS:
		var recent_label := Label.new()
		recent_label.add_theme_font_size_override("font_size", 12)
		recent_label.add_theme_color_override(
			"font_color",
			Color("#C8BDD9")
		)
		recent_label.visible = false
		recent_list.add_child(recent_label)
		recent_labels.append(recent_label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	add_child(footer)

	duration_settings_button = Button.new()
	duration_settings_button.focus_mode = Control.FOCUS_NONE
	duration_settings_button.custom_minimum_size = Vector2(98, 30)
	duration_settings_button.add_theme_font_size_override("font_size", 12)
	duration_settings_button.pressed.connect(durations_pressed.emit)
	_style_action_button(duration_settings_button, "secondary")
	footer.add_child(duration_settings_button)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_spacer)

	close_button = Button.new()
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.custom_minimum_size = Vector2(82, 30)
	close_button.add_theme_font_size_override("font_size", 12)
	close_button.pressed.connect(close_pressed.emit)
	_style_close_button(close_button)
	footer.add_child(close_button)


func apply_texts(texts: Dictionary) -> void:
	if not _built:
		build()
	heading_label.text = str(texts.get("heading", ""))
	note_label.text = str(texts.get("note", ""))
	focus_title_label.text = str(texts.get("focus", ""))
	water_title_label.text = str(texts.get("water", ""))
	stand_title_label.text = str(texts.get("stand", ""))
	quiet_title_label.text = str(texts.get("quiet", ""))
	water_turn_on_button.text = str(texts.get("turn_on", ""))
	recent_title_label.text = str(texts.get("recent_title", ""))
	recent_clear_button.text = str(texts.get("recent_clear", ""))
	recent_empty_label.text = str(texts.get("recent_empty", ""))
	water_done_button.text = str(texts.get("done", ""))
	water_snooze_button.text = str(texts.get("snooze", ""))
	water_turn_off_button.text = str(texts.get("turn_off", ""))
	water_running_turn_off_button.text = str(texts.get("turn_off", ""))
	stand_done_button.text = str(texts.get("done", ""))
	stand_snooze_button.text = str(texts.get("snooze", ""))
	stand_turn_off_button.text = str(texts.get("turn_off", ""))
	stand_running_turn_off_button.text = str(texts.get("turn_off", ""))
	stand_turn_on_button.text = str(texts.get("turn_on", ""))
	duration_settings_button.text = str(texts.get("durations", ""))
	quiet_settings_button.text = str(texts.get("quiet_settings", ""))
	close_button.text = str(texts.get("close", ""))


func apply_state(state) -> void:
	if not _built:
		build()
	_apply_status(
		focus_status_label,
		focus_dot,
		state.focus_text,
		state.focus_tone
	)
	focus_primary_button.text = state.focus_primary_text
	focus_primary_button.visible = state.focus_primary_visible
	focus_secondary_button.text = state.focus_secondary_text
	focus_secondary_button.visible = state.focus_secondary_visible
	focus_actions.visible = (
		state.focus_primary_visible
		or state.focus_secondary_visible
	)
	_apply_status(
		water_status_label,
		water_dot,
		state.water_text,
		state.water_tone
	)
	_apply_reminder_action_mode(
		water_inline_actions,
		water_actions,
		water_turn_on_button,
		water_running_turn_off_button,
		water_done_button,
		water_snooze_button,
		water_turn_off_button,
		state.water_action_mode
	)
	_apply_status(
		stand_status_label,
		stand_dot,
		state.stand_text,
		state.stand_tone
	)
	_apply_reminder_action_mode(
		stand_inline_actions,
		stand_actions,
		stand_turn_on_button,
		stand_running_turn_off_button,
		stand_done_button,
		stand_snooze_button,
		stand_turn_off_button,
		state.stand_action_mode
	)
	_apply_status(
		quiet_status_label,
		quiet_dot,
		state.quiet_text,
		state.quiet_tone
	)
	pending_label.text = state.pending_text
	pending_label.add_theme_color_override(
		"font_color",
		_tone_color(state.pending_tone)
	)
	for index in recent_labels.size():
		var has_row: bool = index < state.recent_rows.size()
		recent_labels[index].visible = has_row
		if has_row:
			recent_labels[index].text = state.recent_rows[index]
	recent_empty_label.visible = state.recent_rows.is_empty()
	recent_clear_button.disabled = state.recent_rows.is_empty()


func _create_status_card(
	inline_action_count := 0,
	action_count := 0
) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 58)
	panel.add_theme_stylebox_override("panel", _card_style())

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	content.add_child(row)

	var dot := Label.new()
	dot.text = "●"
	dot.custom_minimum_size = Vector2(16, 0)
	dot.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dot.add_theme_font_size_override("font_size", 15)
	row.add_child(dot)

	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_theme_constant_override("separation", 2)
	row.add_child(labels)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	labels.add_child(title)

	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Color("#C8BDD9"))
	labels.add_child(status)

	var inline_actions := HBoxContainer.new()
	inline_actions.alignment = BoxContainer.ALIGNMENT_END
	inline_actions.add_theme_constant_override("separation", 6)
	inline_actions.visible = false
	row.add_child(inline_actions)

	var inline_buttons: Array[Button] = []
	for _index in inline_action_count:
		var button := _create_card_action_button()
		inline_actions.add_child(button)
		inline_buttons.append(button)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 6)
	actions.visible = false
	content.add_child(actions)

	var buttons: Array[Button] = []
	for _index in action_count:
		var button := _create_card_action_button()
		actions.add_child(button)
		buttons.append(button)

	return {
		"panel": panel,
		"title": title,
		"status": status,
		"dot": dot,
		"inline_actions": inline_actions,
		"inline_buttons": inline_buttons,
		"actions": actions,
		"buttons": buttons,
	}


func _create_card_action_button() -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(76, 27)
	button.add_theme_font_size_override("font_size", 11)
	return button


func _connect_reminder_buttons(
	reminder: String,
	turn_on_button: Button,
	running_turn_off_button: Button,
	done_button: Button,
	snooze_button: Button,
	turn_off_button: Button
) -> void:
	turn_on_button.pressed.connect(
		reminder_action_pressed.emit.bind(reminder, "turn_on")
	)
	running_turn_off_button.pressed.connect(
		reminder_action_pressed.emit.bind(reminder, "turn_off")
	)
	done_button.pressed.connect(
		reminder_action_pressed.emit.bind(reminder, "done")
	)
	snooze_button.pressed.connect(
		reminder_action_pressed.emit.bind(reminder, "snooze")
	)
	turn_off_button.pressed.connect(
		reminder_action_pressed.emit.bind(reminder, "turn_off")
	)
	_style_action_button(turn_on_button, "primary")
	_style_action_button(running_turn_off_button, "danger")
	_style_action_button(done_button, "done")
	_style_action_button(snooze_button, "secondary")
	_style_action_button(turn_off_button, "danger")


func _apply_reminder_action_mode(
	inline_row: HBoxContainer,
	due_row: HBoxContainer,
	turn_on_button: Button,
	running_turn_off_button: Button,
	done_button: Button,
	snooze_button: Button,
	turn_off_button: Button,
	mode: int
) -> void:
	turn_on_button.visible = (
		mode == ActivityCenterViewStateScript.ReminderActionMode.TURN_ON
	)
	running_turn_off_button.visible = (
		mode == ActivityCenterViewStateScript.ReminderActionMode.TURN_OFF
	)
	done_button.visible = (
		mode == ActivityCenterViewStateScript.ReminderActionMode.DUE
	)
	snooze_button.visible = (
		mode == ActivityCenterViewStateScript.ReminderActionMode.DUE
	)
	turn_off_button.visible = (
		mode == ActivityCenterViewStateScript.ReminderActionMode.DUE
	)
	inline_row.visible = mode in [
		ActivityCenterViewStateScript.ReminderActionMode.TURN_ON,
		ActivityCenterViewStateScript.ReminderActionMode.TURN_OFF,
	]
	due_row.visible = (
		mode == ActivityCenterViewStateScript.ReminderActionMode.DUE
	)


func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#3A3045")
	style.border_color = Color("#50425F")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 11
	style.content_margin_right = 11
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _summary_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#32293C")
	style.border_color = Color("#493C56")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 11
	style.content_margin_right = 11
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _style_close_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state_data in [
		["normal", Color("#4A4055")],
		["hover", Color("#5A4D68")],
		["pressed", Color("#403649")],
	]:
		var style := StyleBoxFlat.new()
		style.bg_color = state_data[1]
		style.border_color = Color("#5F526E")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		button.add_theme_stylebox_override(str(state_data[0]), style)


func _style_action_button(button: Button, variant: String) -> void:
	var normal := Color("#4A4055")
	var hover := Color("#5A4D68")
	var pressed := Color("#403649")
	var border := Color("#5F526E")
	if variant == "primary":
		normal = Color("#604D72")
		hover = Color("#715B84")
		pressed = Color("#514160")
		border = Color("#78628C")
	elif variant == "done":
		normal = Color("#3F614C")
		hover = Color("#4C745B")
		pressed = Color("#355140")
		border = Color("#568064")
	elif variant == "danger":
		normal = Color("#5A3D48")
		hover = Color("#6C4856")
		pressed = Color("#4B333C")
		border = Color("#76505E")
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state_data in [
		["normal", normal],
		["hover", hover],
		["pressed", pressed],
	]:
		var style := StyleBoxFlat.new()
		style.bg_color = state_data[1]
		style.border_color = border
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 8
		style.content_margin_right = 8
		button.add_theme_stylebox_override(str(state_data[0]), style)


func _apply_status(
	label: Label,
	dot: Label,
	text: String,
	tone: int
) -> void:
	label.text = text
	dot.add_theme_color_override("font_color", _tone_color(tone))


func _tone_color(tone: int) -> Color:
	match tone:
		ActivityCenterViewStateScript.Tone.ACTIVE:
			return COLOR_ACTIVE
		ActivityCenterViewStateScript.Tone.ATTENTION:
			return COLOR_ATTENTION
		ActivityCenterViewStateScript.Tone.NORMAL:
			return COLOR_NORMAL
		_:
			return COLOR_MUTED
