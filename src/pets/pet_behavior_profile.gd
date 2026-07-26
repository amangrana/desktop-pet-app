class_name PetBehaviorProfile
extends RefCounted

const PROFILE_ID := "desktop_pet_behavior_v1"
const MAX_FRAMES_PER_BEHAVIOR := 6
const MAX_UNIQUE_BEHAVIOR_TEXTURES := 24

const REQUIRED_BEHAVIORS := {
	&"idle_blink": PetBehaviorDefinition.Trigger.RANDOM_IDLE,
	&"click_happy": PetBehaviorDefinition.Trigger.CLICK,
	&"keyboard": PetBehaviorDefinition.Trigger.KEYBOARD,
	&"mouse": PetBehaviorDefinition.Trigger.MOUSE,
	&"focus_calm": PetBehaviorDefinition.Trigger.FOCUS,
	&"reminder_attention": PetBehaviorDefinition.Trigger.REMINDER,
}

const OPTIONAL_PERSONALITY_BEHAVIORS := {
	&"idle_look": PetBehaviorDefinition.Trigger.RANDOM_IDLE,
	&"idle_yawn": PetBehaviorDefinition.Trigger.RANDOM_IDLE,
	&"idle_stretch": PetBehaviorDefinition.Trigger.RANDOM_IDLE,
}


static func validation_errors(
	definition: PetDefinition,
	require_complete_profile: bool = true
) -> PackedStringArray:
	var errors := PackedStringArray()
	if definition == null:
		errors.append("Pet definition is missing.")
		return errors
	errors.append_array(definition.behavior_validation_errors())

	if require_complete_profile:
		for behavior_id in REQUIRED_BEHAVIORS:
			var behavior := definition.behavior_by_id(behavior_id)
			if behavior == null:
				errors.append(
					"Required behavior is missing: %s" % behavior_id
				)
				continue
			var expected_trigger: int = REQUIRED_BEHAVIORS[behavior_id]
			if behavior.trigger != expected_trigger:
				errors.append(
					"Behavior %s uses trigger %d; expected %d."
					% [
						behavior_id,
						behavior.trigger,
						expected_trigger,
					]
				)

	var unique_textures: Dictionary = {}
	for behavior in definition.behaviors:
		if behavior == null or not behavior.is_configured():
			continue
		if behavior.frames.size() > MAX_FRAMES_PER_BEHAVIOR:
			errors.append(
				"Behavior %s has %d frames; maximum is %d."
				% [
					behavior.behavior_id,
					behavior.frames.size(),
					MAX_FRAMES_PER_BEHAVIOR,
				]
			)
		for frame in behavior.frames:
			unique_textures[frame.get_instance_id()] = true

	var idle_texture_id := (
		definition.idle_texture.get_instance_id()
		if definition.idle_texture != null
		else 0
	)
	unique_textures.erase(idle_texture_id)
	if unique_textures.size() > MAX_UNIQUE_BEHAVIOR_TEXTURES:
		errors.append(
			"Pet has %d unique behavior textures; maximum is %d."
			% [
				unique_textures.size(),
				MAX_UNIQUE_BEHAVIOR_TEXTURES,
			]
		)

	var focus_behavior := definition.behavior_by_id(&"focus_calm")
	if (
		focus_behavior != null
		and focus_behavior.playback != PetBehaviorDefinition.Playback.LOOP
	):
		errors.append("Behavior focus_calm must use loop playback.")
	return errors
