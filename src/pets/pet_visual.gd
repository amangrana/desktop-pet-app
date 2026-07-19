class_name PetVisual
extends Node2D

enum Reaction {
	NONE,
	KEYBOARD,
	MOUSE,
	CLICK,
	REMINDER,
}

var definition: PetDefinition
var _elapsed := 0.0
var _reaction_remaining := 0.0
var _next_idle_motion := 0.0
var _idle_motion_remaining := 0.0
var _reaction := Reaction.NONE
var _alternate_side := false
var _focus_mode := false
var _visible_bounds := Rect2()


func _ready() -> void:
	_schedule_idle_motion()


func _process(delta: float) -> void:
	_elapsed += delta
	_reaction_remaining = maxf(0.0, _reaction_remaining - delta)
	_idle_motion_remaining = maxf(0.0, _idle_motion_remaining - delta)

	if _reaction_remaining <= 0.0:
		_reaction = Reaction.NONE

	if _focus_mode:
		_idle_motion_remaining = 0.0
	else:
		_next_idle_motion -= delta
		if _next_idle_motion <= 0.0:
			_idle_motion_remaining = 0.45
			_alternate_side = not _alternate_side
			_schedule_idle_motion()

	queue_redraw()


func _draw() -> void:
	if definition == null or definition.idle_texture == null:
		return

	var bob := sin(_elapsed * 2.0) * definition.idle_bob_amount
	var breathing := 1.0 + sin(_elapsed * 2.0) * definition.breathing_amount
	if _focus_mode:
		bob *= 0.35
		breathing = 1.0 + (breathing - 1.0) * 0.5
	var draw_position := definition.visual_offset + Vector2(0, bob)
	var draw_rotation := 0.0
	var draw_scale := Vector2(breathing, breathing)
	var action := &"idle"

	if _reaction == Reaction.KEYBOARD:
		action = &"keyboard"
		draw_position.y -= definition.keyboard_lift
		draw_rotation = 0.045 if _alternate_side else -0.045
		draw_scale = Vector2(1.02, 0.98)
	elif _reaction == Reaction.MOUSE:
		action = &"mouse"
		draw_position.y += definition.mouse_drop
		draw_scale = Vector2(1.04, 0.92)
	elif _reaction == Reaction.CLICK:
		action = &"click"
		draw_position.y -= definition.click_jump
		draw_scale = Vector2(1.025, 1.025)
	elif _reaction == Reaction.REMINDER:
		action = &"reminder"
		draw_position.y -= definition.click_jump * 0.45
		var reminder_pulse := 1.04 + sin(_elapsed * 8.0) * 0.02
		draw_scale = Vector2(reminder_pulse, reminder_pulse)
	elif _focus_mode:
		action = &"focus"
	elif _idle_motion_remaining > 0.0:
		var idle_progress := float(_idle_motion_remaining / 0.45)
		var direction := 1.0 if _alternate_side else -1.0
		draw_rotation = sin(idle_progress * PI) * 0.025 * direction

	draw_set_transform(draw_position, draw_rotation, draw_scale)
	draw_texture_rect(
		definition.texture_for_action(action),
		Rect2(-definition.display_size / 2.0, definition.display_size),
		false
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _reaction == Reaction.CLICK and definition.show_click_heart:
		_draw_heart(
			definition.heart_position + Vector2(0, bob),
			definition.heart_scale,
			definition.heart_color
		)


func set_definition(value: PetDefinition) -> void:
	definition = value
	_visible_bounds = _calculate_visible_bounds()
	_reaction = Reaction.NONE
	_reaction_remaining = 0.0
	_idle_motion_remaining = 0.0
	_schedule_idle_motion()
	queue_redraw()


func get_pet_id() -> StringName:
	return definition.pet_id if definition != null else StringName()


func get_display_name() -> String:
	return definition.display_name if definition != null else "Desktop Pet"


func get_interaction_polygon() -> PackedVector2Array:
	if definition == null:
		return PackedVector2Array()
	return definition.interaction_polygon


func get_visible_bounds() -> Rect2:
	return _visible_bounds


func has_focus_hotspot() -> bool:
	return (
		definition != null
		and not definition.focus_hotspot_centers.is_empty()
		and definition.focus_hotspot_radius > 0.0
	)


func get_focus_hotspot_centers() -> PackedVector2Array:
	if definition == null:
		return PackedVector2Array()
	return definition.focus_hotspot_centers


func get_focus_hotspot_radius() -> float:
	if definition == null:
		return 0.0
	return definition.focus_hotspot_radius


func is_focus_hotspot(local_position: Vector2) -> bool:
	if not has_focus_hotspot():
		return false
	var radius_squared := (
		definition.focus_hotspot_radius
		* definition.focus_hotspot_radius
	)
	for center in definition.focus_hotspot_centers:
		if local_position.distance_squared_to(center) <= radius_squared:
			return true
	return false


func react_to_keyboard(event_count: int = 1) -> void:
	if (
		_reaction in [Reaction.CLICK, Reaction.REMINDER]
		and _reaction_remaining > 0.0
	):
		return
	_reaction = Reaction.KEYBOARD
	_reaction_remaining = clampf(0.18 + event_count * 0.02, 0.18, 0.42)
	_alternate_side = not _alternate_side


func react_to_mouse(event_count: int = 1) -> void:
	if (
		_reaction in [Reaction.CLICK, Reaction.REMINDER]
		and _reaction_remaining > 0.0
	):
		return
	_reaction = Reaction.MOUSE
	_reaction_remaining = clampf(0.20 + event_count * 0.025, 0.20, 0.48)


func react_to_click() -> void:
	if _reaction == Reaction.REMINDER and _reaction_remaining > 0.0:
		return
	_reaction = Reaction.CLICK
	_reaction_remaining = 0.8


func react_to_reminder() -> void:
	_reaction = Reaction.REMINDER
	_reaction_remaining = 2.4


func set_focus_mode(enabled: bool) -> void:
	if _focus_mode == enabled:
		return
	_focus_mode = enabled
	_idle_motion_remaining = 0.0
	if not enabled:
		_schedule_idle_motion()
	queue_redraw()


func _draw_heart(
	position: Vector2,
	scale_factor: float,
	color: Color
) -> void:
	draw_circle(
		position + Vector2(-7, 0) * scale_factor,
		8 * scale_factor,
		color
	)
	draw_circle(
		position + Vector2(7, 0) * scale_factor,
		8 * scale_factor,
		color
	)
	var point := PackedVector2Array([
		position + Vector2(-14, 2) * scale_factor,
		position + Vector2(14, 2) * scale_factor,
		position + Vector2(0, 22) * scale_factor,
	])
	draw_colored_polygon(point, color)


func _schedule_idle_motion() -> void:
	if definition == null:
		_next_idle_motion = 5.0
		return

	var minimum := minf(
		definition.random_idle_interval_min,
		definition.random_idle_interval_max
	)
	var maximum := maxf(
		definition.random_idle_interval_min,
		definition.random_idle_interval_max
	)
	_next_idle_motion = randf_range(minimum, maximum)


func _calculate_visible_bounds() -> Rect2:
	if definition == null or definition.idle_texture == null:
		return Rect2()

	var full_bounds := Rect2(
		definition.visual_offset - definition.display_size / 2.0,
		definition.display_size
	)
	var image: Image = definition.idle_texture.get_image()
	if image == null or image.is_empty():
		return full_bounds

	var used_pixels: Rect2i = image.get_used_rect()
	if used_pixels.size.x <= 0 or used_pixels.size.y <= 0:
		return full_bounds

	var image_size := Vector2(image.get_size())
	var pixel_scale := Vector2(
		definition.display_size.x / image_size.x,
		definition.display_size.y / image_size.y
	)
	return Rect2(
		full_bounds.position + Vector2(used_pixels.position) * pixel_scale,
		Vector2(used_pixels.size) * pixel_scale
	)
