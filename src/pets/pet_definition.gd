class_name PetDefinition
extends Resource

@export_category("Identity")
@export var pet_id: StringName
@export var display_name := ""
@export var species := ""
@export_multiline var description := ""
@export var sort_order := 0
@export var dialogue_profile: PetDialogueProfile

@export_category("Visuals")
@export var idle_texture: Texture2D
@export var click_texture: Texture2D
@export var keyboard_texture: Texture2D
@export var mouse_texture: Texture2D
@export var behaviors: Array[PetBehaviorDefinition] = []
@export var display_size := Vector2(224, 224)
@export var visual_offset := Vector2.ZERO

@export_category("Interaction Shape")
@export var interaction_polygon := PackedVector2Array([
	Vector2(-120, -132),
	Vector2(120, -132),
	Vector2(126, -28),
	Vector2(126, 116),
	Vector2(-126, 116),
	Vector2(-126, -28),
])

@export_category("Quick Actions")
@export var focus_hotspot_centers := PackedVector2Array()
@export_range(0.0, 64.0, 1.0) var focus_hotspot_radius := 0.0

@export_category("Click Effect")
@export var show_click_heart := true
@export var heart_position := Vector2(78, -86)
@export var heart_scale := 1.0
@export var heart_color := Color("#F28BA8")

@export_category("Motion")
@export var idle_bob_amount := 1.5
@export var breathing_amount := 0.008
@export var keyboard_lift := 5.0
@export var mouse_drop := 6.0
@export var click_jump := 12.0
@export var random_idle_interval_min := 4.0
@export var random_idle_interval_max := 8.0


func is_configured() -> bool:
	return (
		not String(pet_id).is_empty()
		and not display_name.is_empty()
		and idle_texture != null
		and display_size.x > 0.0
		and display_size.y > 0.0
		and interaction_polygon.size() >= 3
	)


func texture_for_action(action: StringName) -> Texture2D:
	match action:
		&"click":
			return click_texture if click_texture != null else idle_texture
		&"keyboard":
			return keyboard_texture if keyboard_texture != null else idle_texture
		&"mouse":
			return mouse_texture if mouse_texture != null else idle_texture
		_:
			return idle_texture


func behavior_by_id(behavior_id: StringName) -> PetBehaviorDefinition:
	for behavior in behaviors:
		if (
			behavior != null
			and behavior.behavior_id == behavior_id
			and behavior.is_configured()
		):
			return behavior
	return null


func behaviors_for_trigger(
	trigger: PetBehaviorDefinition.Trigger
) -> Array[PetBehaviorDefinition]:
	var matches: Array[PetBehaviorDefinition] = []
	var seen_ids: Dictionary = {}
	for behavior in behaviors:
		if (
			behavior == null
			or not behavior.is_configured()
			or behavior.trigger != trigger
			or seen_ids.has(behavior.behavior_id)
		):
			continue
		seen_ids[behavior.behavior_id] = true
		matches.append(behavior)
	return matches


func behavior_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary = {}
	for index in behaviors.size():
		var behavior := behaviors[index]
		if behavior == null:
			errors.append("Behavior %d is empty." % index)
			continue
		if not behavior.is_configured():
			errors.append(
				"Behavior %d (%s) is incomplete."
				% [index, behavior.behavior_id]
			)
			continue
		if seen_ids.has(behavior.behavior_id):
			errors.append(
				"Duplicate behavior id: %s" % behavior.behavior_id
			)
			continue
		seen_ids[behavior.behavior_id] = true
		if idle_texture == null:
			continue
		for frame_index in behavior.frames.size():
			var frame := behavior.frames[frame_index]
			if (
				frame.get_width() != idle_texture.get_width()
				or frame.get_height() != idle_texture.get_height()
			):
				errors.append(
					(
						"Behavior %s frame %d is %dx%d; expected %dx%d."
					)
					% [
						behavior.behavior_id,
						frame_index,
						frame.get_width(),
						frame.get_height(),
						idle_texture.get_width(),
						idle_texture.get_height(),
					]
				)
	return errors


func dialogue_validation_errors() -> PackedStringArray:
	if dialogue_profile == null:
		return PackedStringArray()
	return dialogue_profile.validation_errors()
