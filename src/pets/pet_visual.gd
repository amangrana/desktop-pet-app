class_name PetVisual
extends Node2D

signal visual_shape_changed

const INTERACTION_ALPHA_THRESHOLD := 0.08
const INTERACTION_SAFETY_MARGIN := 16.0
const INTERACTION_SIMPLIFY_EPSILON := 2.0
const BEHAVIOR_PRIORITY_RANDOM := 10
const BEHAVIOR_PRIORITY_INPUT := 20
const BEHAVIOR_PRIORITY_CLICK := 30
const BEHAVIOR_PRIORITY_REMINDER := 40
const BEHAVIOR_PRIORITY_PREVIEW := 50

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
var _click_effect_remaining := 0.0
var _next_idle_motion := 0.0
var _idle_motion_remaining := 0.0
var _reaction := Reaction.NONE
var _active_behavior: PetBehaviorDefinition
var _active_behavior_elapsed := 0.0
var _active_behavior_remaining := 0.0
var _active_behavior_total_duration := 0.0
var _active_behavior_priority := 0
var _behavior_cooldowns: Dictionary = {}
var _alternate_side := false
var _focus_mode := false
var _focus_behavior_elapsed := 0.0
var _visible_bounds := Rect2()
var _interaction_polygon := PackedVector2Array()
var _interaction_texture: Texture2D


func _ready() -> void:
	_schedule_idle_motion()


func _process(delta: float) -> void:
	_elapsed += delta
	_reaction_remaining = maxf(0.0, _reaction_remaining - delta)
	_click_effect_remaining = maxf(0.0, _click_effect_remaining - delta)
	_idle_motion_remaining = maxf(0.0, _idle_motion_remaining - delta)
	_update_behavior_cooldowns(delta)
	if _focus_mode:
		_focus_behavior_elapsed += delta

	if _active_behavior != null:
		_active_behavior_elapsed += delta
		_active_behavior_remaining = maxf(
			0.0,
			_active_behavior_remaining - delta
		)
		if _active_behavior_remaining <= 0.0:
			_clear_active_behavior()

	if _reaction_remaining <= 0.0:
		_reaction = Reaction.NONE

	if _focus_mode:
		_idle_motion_remaining = 0.0
		if (
			_active_behavior != null
			and _active_behavior.trigger
				== PetBehaviorDefinition.Trigger.RANDOM_IDLE
			and not _active_behavior.allowed_during_focus
		):
			_clear_active_behavior()
	else:
		_next_idle_motion -= delta
		if (
			_next_idle_motion <= 0.0
			and _current_behavior_priority() <= BEHAVIOR_PRIORITY_RANDOM
		):
			if not _start_random_behavior():
				_idle_motion_remaining = 0.45
				_alternate_side = not _alternate_side
			_schedule_idle_motion()

	_refresh_interaction_shape()
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
	var draw_texture := _current_visual_texture()
	var configured_behavior := _configured_behavior_for_draw()

	if configured_behavior != null:
		if (
			configured_behavior.trigger
			== PetBehaviorDefinition.Trigger.CLICK
			and _active_behavior_total_duration > 0.0
		):
			var click_motion_duration := minf(
				_active_behavior_total_duration,
				0.8
			)
			if _active_behavior_elapsed < click_motion_duration:
				var click_progress := clampf(
					_active_behavior_elapsed / click_motion_duration,
					0.0,
					1.0
				)
				draw_position.y -= (
					sin(click_progress * PI) * definition.click_jump
				)
			draw_scale *= Vector2(1.02, 1.02)
	elif _reaction == Reaction.KEYBOARD:
		draw_position.y -= definition.keyboard_lift
		draw_rotation = 0.045 if _alternate_side else -0.045
		draw_scale = Vector2(1.02, 0.98)
	elif _reaction == Reaction.MOUSE:
		draw_position.y += definition.mouse_drop
		draw_scale = Vector2(1.04, 0.92)
	elif _reaction == Reaction.CLICK:
		draw_position.y -= definition.click_jump
		draw_scale = Vector2(1.025, 1.025)
	elif _reaction == Reaction.REMINDER:
		draw_position.y -= definition.click_jump * 0.45
		var reminder_pulse := 1.04 + sin(_elapsed * 8.0) * 0.02
		draw_scale = Vector2(reminder_pulse, reminder_pulse)
	elif not _focus_mode and _idle_motion_remaining > 0.0:
		var idle_progress := float(_idle_motion_remaining / 0.45)
		var direction := 1.0 if _alternate_side else -1.0
		draw_rotation = sin(idle_progress * PI) * 0.025 * direction

	draw_set_transform(draw_position, draw_rotation, draw_scale)
	draw_texture_rect(
		draw_texture,
		Rect2(-definition.display_size / 2.0, definition.display_size),
		false
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _click_effect_remaining > 0.0 and definition.show_click_heart:
		_draw_heart(
			definition.heart_position + Vector2(0, bob),
			definition.heart_scale,
			definition.heart_color
		)


func set_definition(value: PetDefinition) -> void:
	definition = value
	_visible_bounds = _calculate_visible_bounds()
	_interaction_texture = null
	_interaction_polygon = PackedVector2Array()
	_reaction = Reaction.NONE
	_reaction_remaining = 0.0
	_click_effect_remaining = 0.0
	_idle_motion_remaining = 0.0
	_clear_active_behavior()
	_behavior_cooldowns.clear()
	_focus_behavior_elapsed = 0.0
	_schedule_idle_motion()
	_refresh_interaction_shape()
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


func get_current_behavior_id() -> StringName:
	if _active_behavior != null:
		return _active_behavior.behavior_id
	if _focus_mode:
		var focus_behavior := _first_behavior_for_trigger(
			PetBehaviorDefinition.Trigger.FOCUS
		)
		if focus_behavior != null:
			return focus_behavior.behavior_id
	match _reaction:
		Reaction.KEYBOARD:
			return &"keyboard"
		Reaction.MOUSE:
			return &"mouse"
		Reaction.CLICK:
			return &"click"
		Reaction.REMINDER:
			return &"reminder"
	if _idle_motion_remaining > 0.0:
		return &"idle_motion"
	return &"idle"


func has_behavior(behavior_id: StringName) -> bool:
	return (
		definition != null
		and definition.behavior_by_id(behavior_id) != null
	)


func preview_behavior(
	behavior_id: StringName,
	duration_seconds: float = 0.0
) -> bool:
	if definition == null:
		return false
	var behavior := definition.behavior_by_id(behavior_id)
	if behavior == null or not behavior.is_configured():
		return false

	_clear_active_behavior()
	_active_behavior = behavior
	_active_behavior_elapsed = 0.0
	_active_behavior_remaining = maxf(
		0.05,
		duration_seconds
		if duration_seconds > 0.0
		else behavior.runtime_duration_seconds()
	)
	_active_behavior_total_duration = _active_behavior_remaining
	_active_behavior_priority = BEHAVIOR_PRIORITY_PREVIEW
	_reaction = Reaction.NONE
	_reaction_remaining = 0.0
	if behavior.trigger == PetBehaviorDefinition.Trigger.CLICK:
		_click_effect_remaining = minf(
			0.8,
			_active_behavior_remaining
		)
	_refresh_interaction_shape()
	queue_redraw()
	return true


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
	if _current_behavior_priority() > BEHAVIOR_PRIORITY_INPUT:
		return
	if _start_trigger_behavior(
		PetBehaviorDefinition.Trigger.KEYBOARD,
		BEHAVIOR_PRIORITY_INPUT,
		false,
		clampf(0.18 + event_count * 0.02, 0.18, 0.42)
	):
		_alternate_side = not _alternate_side
		return
	_reaction = Reaction.KEYBOARD
	_reaction_remaining = clampf(0.18 + event_count * 0.02, 0.18, 0.42)
	_alternate_side = not _alternate_side
	_refresh_interaction_shape()


func react_to_mouse(event_count: int = 1) -> void:
	if _current_behavior_priority() > BEHAVIOR_PRIORITY_INPUT:
		return
	if _start_trigger_behavior(
		PetBehaviorDefinition.Trigger.MOUSE,
		BEHAVIOR_PRIORITY_INPUT,
		false,
		clampf(0.20 + event_count * 0.025, 0.20, 0.48)
	):
		return
	_reaction = Reaction.MOUSE
	_reaction_remaining = clampf(0.20 + event_count * 0.025, 0.20, 0.48)
	_refresh_interaction_shape()


func react_to_click() -> void:
	if _current_behavior_priority() > BEHAVIOR_PRIORITY_CLICK:
		return
	_click_effect_remaining = 0.8
	if _start_trigger_behavior(
		PetBehaviorDefinition.Trigger.CLICK,
		BEHAVIOR_PRIORITY_CLICK,
		false,
		0.8
	):
		return
	_reaction = Reaction.CLICK
	_reaction_remaining = 0.8
	_refresh_interaction_shape()


func react_to_reminder() -> void:
	if _start_trigger_behavior(
		PetBehaviorDefinition.Trigger.REMINDER,
		BEHAVIOR_PRIORITY_REMINDER,
		false,
		2.4
	):
		return
	_clear_active_behavior()
	_reaction = Reaction.REMINDER
	_reaction_remaining = 2.4
	_refresh_interaction_shape()


func set_focus_mode(enabled: bool) -> void:
	if _focus_mode == enabled:
		return
	_focus_mode = enabled
	_focus_behavior_elapsed = 0.0
	_idle_motion_remaining = 0.0
	if (
		enabled
		and _active_behavior != null
		and _active_behavior.trigger
			== PetBehaviorDefinition.Trigger.RANDOM_IDLE
		and not _active_behavior.allowed_during_focus
	):
		_clear_active_behavior()
	if not enabled:
		_schedule_idle_motion()
	_refresh_interaction_shape()
	queue_redraw()


func _configured_behavior_for_draw() -> PetBehaviorDefinition:
	if _active_behavior != null:
		return _active_behavior
	if _focus_mode:
		return _first_behavior_for_trigger(
			PetBehaviorDefinition.Trigger.FOCUS
		)
	return null


func _current_visual_texture() -> Texture2D:
	if definition == null or definition.idle_texture == null:
		return null
	var configured_behavior := _configured_behavior_for_draw()
	if configured_behavior != null:
		var behavior_elapsed := (
			_active_behavior_elapsed
			if configured_behavior == _active_behavior
			else _focus_behavior_elapsed
		)
		var behavior_texture := configured_behavior.texture_at(
			behavior_elapsed
		)
		if behavior_texture != null:
			return behavior_texture

	var action := &"idle"
	match _reaction:
		Reaction.KEYBOARD:
			action = &"keyboard"
		Reaction.MOUSE:
			action = &"mouse"
		Reaction.CLICK:
			action = &"click"
		Reaction.REMINDER:
			action = &"reminder"
	return definition.texture_for_action(action)


func _refresh_interaction_shape() -> void:
	var texture := _current_visual_texture()
	if texture == _interaction_texture:
		return
	_interaction_texture = texture
	_interaction_polygon = _calculate_interaction_polygon(texture)
	visual_shape_changed.emit()


func _first_behavior_for_trigger(
	trigger: PetBehaviorDefinition.Trigger
) -> PetBehaviorDefinition:
	if definition == null:
		return null
	var candidates := definition.behaviors_for_trigger(trigger)
	return candidates[0] if not candidates.is_empty() else null


func _start_random_behavior() -> bool:
	return _start_trigger_behavior(
		PetBehaviorDefinition.Trigger.RANDOM_IDLE,
		BEHAVIOR_PRIORITY_RANDOM,
		true
	)


func _start_trigger_behavior(
	trigger: PetBehaviorDefinition.Trigger,
	priority: int,
	respect_cooldown: bool = false,
	minimum_duration_seconds: float = 0.0
) -> bool:
	if definition == null or priority < _current_behavior_priority():
		return false
	if (
		_active_behavior != null
		and _active_behavior.trigger == trigger
		and _active_behavior_priority == priority
	):
		var renewed_duration := maxf(
			maxf(0.05, minimum_duration_seconds),
			_active_behavior.runtime_duration_seconds()
		)
		_active_behavior_remaining = maxf(
			_active_behavior_remaining,
			renewed_duration
		)
		_active_behavior_total_duration = maxf(
			_active_behavior_total_duration,
			_active_behavior_elapsed + _active_behavior_remaining
		)
		return true
	var behavior := _choose_behavior(trigger, respect_cooldown)
	if behavior == null:
		return false

	_active_behavior = behavior
	_active_behavior_elapsed = 0.0
	_active_behavior_remaining = maxf(
		maxf(0.05, minimum_duration_seconds),
		behavior.runtime_duration_seconds()
	)
	_active_behavior_total_duration = _active_behavior_remaining
	_active_behavior_priority = priority
	_reaction = Reaction.NONE
	_reaction_remaining = 0.0
	if behavior.cooldown_seconds > 0.0:
		_behavior_cooldowns[behavior.behavior_id] = (
			behavior.cooldown_seconds
		)
	_refresh_interaction_shape()
	return true


func _choose_behavior(
	trigger: PetBehaviorDefinition.Trigger,
	respect_cooldown: bool
) -> PetBehaviorDefinition:
	var candidates := definition.behaviors_for_trigger(trigger)
	var eligible: Array[PetBehaviorDefinition] = []
	var total_weight := 0.0
	for behavior in candidates:
		if _focus_mode and not behavior.allowed_during_focus:
			continue
		if (
			respect_cooldown
			and float(_behavior_cooldowns.get(behavior.behavior_id, 0.0))
				> 0.0
		):
			continue
		eligible.append(behavior)
		total_weight += behavior.weight
	if eligible.is_empty():
		return null
	if eligible.size() == 1:
		return eligible[0]

	var roll := randf() * total_weight
	for behavior in eligible:
		roll -= behavior.weight
		if roll <= 0.0:
			return behavior
	return eligible[-1]


func _current_behavior_priority() -> int:
	if _active_behavior != null:
		return _active_behavior_priority
	match _reaction:
		Reaction.KEYBOARD, Reaction.MOUSE:
			return BEHAVIOR_PRIORITY_INPUT
		Reaction.CLICK:
			return BEHAVIOR_PRIORITY_CLICK
		Reaction.REMINDER:
			return BEHAVIOR_PRIORITY_REMINDER
	return 0


func _clear_active_behavior() -> void:
	_active_behavior = null
	_active_behavior_elapsed = 0.0
	_active_behavior_remaining = 0.0
	_active_behavior_total_duration = 0.0
	_active_behavior_priority = 0


func _update_behavior_cooldowns(delta: float) -> void:
	for behavior_id in _behavior_cooldowns.keys():
		var remaining := maxf(
			0.0,
			float(_behavior_cooldowns[behavior_id]) - delta
		)
		if remaining <= 0.0:
			_behavior_cooldowns.erase(behavior_id)
		else:
			_behavior_cooldowns[behavior_id] = remaining


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


func _calculate_interaction_polygon(
	source_texture: Texture2D = null
) -> PackedVector2Array:
	if definition == null:
		return PackedVector2Array()
	if source_texture == null:
		source_texture = definition.idle_texture
	if source_texture == null:
		return PackedVector2Array()
	var image: Image = source_texture.get_image()
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
