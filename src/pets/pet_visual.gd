class_name PetVisual
extends Node2D

const INTERACTION_ALPHA_THRESHOLD := 0.08
const INTERACTION_SAFETY_MARGIN := 16.0
const INTERACTION_SIMPLIFY_EPSILON := 2.0

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
var _interaction_polygon := PackedVector2Array()


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
	_interaction_polygon = _calculate_interaction_polygon()
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
	if _interaction_polygon.size() >= 3:
		return _interaction_polygon
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


func _calculate_interaction_polygon() -> PackedVector2Array:
	if definition == null or definition.idle_texture == null:
		return PackedVector2Array()
	var image: Image = definition.idle_texture.get_image()
	if image == null or image.is_empty():
		return PackedVector2Array()

	var mask_image := image.duplicate()
	var mask_size := Vector2i(
		maxi(1, roundi(definition.display_size.x)),
		maxi(1, roundi(definition.display_size.y))
	)
	if mask_image.get_size() != mask_size:
		mask_image.resize(
			mask_size.x,
			mask_size.y,
			Image.INTERPOLATE_LANCZOS
		)
	var image_size: Vector2i = mask_image.get_size()
	if image_size.x <= 0 or image_size.y <= 0:
		return PackedVector2Array()
	var pixel_scale := Vector2(
		definition.display_size.x / float(image_size.x),
		definition.display_size.y / float(image_size.y)
	)
	var smallest_pixel_scale := minf(pixel_scale.x, pixel_scale.y)
	if smallest_pixel_scale <= 0.0:
		return PackedVector2Array()

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(
		mask_image,
		INTERACTION_ALPHA_THRESHOLD
	)
	var bitmap_rect := Rect2i(Vector2i.ZERO, image_size)
	bitmap.grow_mask(
		ceili(INTERACTION_SAFETY_MARGIN / smallest_pixel_scale),
		bitmap_rect
	)
	var source_polygons: Array[PackedVector2Array] = (
		bitmap.opaque_to_polygons(
			bitmap_rect,
			INTERACTION_SIMPLIFY_EPSILON
		)
	)
	var source_polygon := _largest_polygon(source_polygons)
	if source_polygon.size() < 3:
		return PackedVector2Array()

	var full_bounds := Rect2(
		definition.visual_offset - definition.display_size / 2.0,
		definition.display_size
	)
	var mapped_polygon := PackedVector2Array()
	for point in source_polygon:
		mapped_polygon.append(
			full_bounds.position + Vector2(point) * pixel_scale
		)
	if definition.show_click_heart:
		mapped_polygon = _include_click_heart(mapped_polygon)
	return mapped_polygon


func _include_click_heart(
	polygon: PackedVector2Array
) -> PackedVector2Array:
	if polygon.size() < 3:
		return polygon
	var heart_center := definition.heart_position
	var nearest := polygon[0]
	var nearest_distance := heart_center.distance_squared_to(nearest)
	for point in polygon:
		var distance := heart_center.distance_squared_to(point)
		if distance >= nearest_distance:
			continue
		nearest = point
		nearest_distance = distance

	var direction := heart_center - nearest
	if direction.length_squared() <= 0.001:
		return polygon
	var unit_direction := direction.normalized()
	var normal := Vector2(-unit_direction.y, unit_direction.x) * 3.0
	var corridor := PackedVector2Array([
		nearest - unit_direction * 4.0 - normal,
		nearest - unit_direction * 4.0 + normal,
		heart_center + normal,
		heart_center - normal,
	])
	var merged := _largest_polygon(
		Geometry2D.merge_polygons(polygon, corridor)
	)

	var heart_polygon := PackedVector2Array()
	var heart_radius := 24.0 * definition.heart_scale
	for index in 16:
		var angle := TAU * float(index) / 16.0
		heart_polygon.append(
			heart_center
			+ Vector2(cos(angle), sin(angle)) * heart_radius
		)
	return _largest_polygon(
		Geometry2D.merge_polygons(merged, heart_polygon)
	)


func _largest_polygon(
	polygons: Array[PackedVector2Array]
) -> PackedVector2Array:
	var largest := PackedVector2Array()
	var largest_area := 0.0
	for polygon in polygons:
		var area := absf(_polygon_signed_area(polygon))
		if area <= largest_area:
			continue
		largest = polygon
		largest_area = area
	return largest


func _polygon_signed_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var area := 0.0
	for index in polygon.size():
		var next_index := (index + 1) % polygon.size()
		area += (
			polygon[index].x * polygon[next_index].y
			- polygon[next_index].x * polygon[index].y
		)
	return area * 0.5
