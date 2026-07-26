extends SceneTree

const PetBehaviorDefinitionScript := preload(
	"res://src/pets/pet_behavior_definition.gd"
)
const PetDefinitionScript := preload("res://src/pets/pet_definition.gd")
const PetBehaviorProfileScript := preload(
	"res://src/pets/pet_behavior_profile.gd"
)
const PetVisualScript := preload("res://src/pets/pet_visual.gd")

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var leo_texture := load(
		"res://assets/pets/leo/leo-master.png"
	) as Texture2D
	var bobo_texture := load(
		"res://assets/pets/bobo/bobo-master.png"
	) as Texture2D

	_test_clip_validation_and_playback(leo_texture, bobo_texture)
	_test_definition_lookup_and_validation(leo_texture, bobo_texture)
	_test_standard_profile(leo_texture)
	_test_leo_pilot_pack()
	_test_runtime_priority_focus_and_fallback(leo_texture, bobo_texture)

	if _failed:
		quit(1)
		return
	print("Pet behavior system self-test passed.")
	quit(0)


func _test_clip_validation_and_playback(
	first_texture: Texture2D,
	second_texture: Texture2D
) -> void:
	var behavior := _behavior(
		&"idle_blink",
		PetBehaviorDefinition.Trigger.RANDOM_IDLE,
		[first_texture, second_texture]
	)
	behavior.frames_per_second = 2.0

	_expect(behavior.is_configured(), "A complete behavior must be valid.")
	_expect(
		is_equal_approx(behavior.natural_duration_seconds(), 1.0),
		"Two frames at 2 FPS must have a one-second natural duration."
	)
	_expect(
		behavior.texture_at(0.0) == first_texture
		and behavior.texture_at(0.6) == second_texture
		and behavior.texture_at(5.0) == second_texture,
		"Once playback must advance and hold its final frame."
	)

	behavior.playback = PetBehaviorDefinition.Playback.PING_PONG
	_expect(
		behavior.texture_at(1.0) == first_texture,
		"Ping-pong playback must return to its first frame."
	)
	behavior.play_duration_seconds = 2.5
	_expect(
		is_equal_approx(behavior.runtime_duration_seconds(), 2.5),
		"An explicit play duration must override the natural duration."
	)

	var invalid := PetBehaviorDefinitionScript.new()
	invalid.behavior_id = &"invalid"
	invalid.frames = [null]
	_expect(
		not invalid.is_configured(),
		"Null behavior frames must be rejected."
	)


func _test_definition_lookup_and_validation(
	idle_texture: Texture2D,
	action_texture: Texture2D
) -> void:
	var definition := _definition(idle_texture)
	var blink := _behavior(
		&"idle_blink",
		PetBehaviorDefinition.Trigger.RANDOM_IDLE,
		[idle_texture, action_texture]
	)
	var click := _behavior(
		&"click_happy",
		PetBehaviorDefinition.Trigger.CLICK,
		[action_texture]
	)
	definition.behaviors = [blink, click]

	_expect(
		definition.behavior_by_id(&"click_happy") == click,
		"Pet definitions must look up a configured behavior by stable id."
	)
	_expect(
		definition.behaviors_for_trigger(
			PetBehaviorDefinition.Trigger.RANDOM_IDLE
		) == [blink],
		"Pet definitions must group behaviors by trigger."
	)
	_expect(
		definition.behavior_validation_errors().is_empty(),
		"A valid behavior list must not report errors."
	)

	definition.behaviors.append(blink)
	var errors := definition.behavior_validation_errors()
	_expect(
		errors.size() == 1
		and errors[0].contains("Duplicate behavior id"),
		"Duplicate behavior ids must be reported without invalidating the pet."
	)

	var wrong_size_image := Image.create(2, 3, false, Image.FORMAT_RGBA8)
	wrong_size_image.fill(Color.WHITE)
	var wrong_size_texture := ImageTexture.create_from_image(wrong_size_image)
	var wrong_size_behavior := _behavior(
		&"idle_wrong_size",
		PetBehaviorDefinition.Trigger.RANDOM_IDLE,
		[wrong_size_texture]
	)
	definition.behaviors = [wrong_size_behavior]
	errors = definition.behavior_validation_errors()
	_expect(
		errors.size() == 1 and errors[0].contains("expected"),
		"Every behavior frame must match the idle canvas dimensions."
	)


func _test_runtime_priority_focus_and_fallback(
	idle_texture: Texture2D,
	action_texture: Texture2D
) -> void:
	var definition := _definition(idle_texture)
	definition.random_idle_interval_min = 100.0
	definition.random_idle_interval_max = 100.0
	definition.behaviors = [
		_behavior(
			&"idle_blink",
			PetBehaviorDefinition.Trigger.RANDOM_IDLE,
			[idle_texture, action_texture]
		),
		_behavior(
			&"click_happy",
			PetBehaviorDefinition.Trigger.CLICK,
			[action_texture]
		),
		_behavior(
			&"typing",
			PetBehaviorDefinition.Trigger.KEYBOARD,
			[action_texture]
		),
		_behavior(
			&"attention",
			PetBehaviorDefinition.Trigger.REMINDER,
			[action_texture]
		),
		_behavior(
			&"focus_calm",
			PetBehaviorDefinition.Trigger.FOCUS,
			[action_texture]
		),
	]

	var visual := PetVisualScript.new()
	root.add_child(visual)
	visual.set_definition(definition)

	visual.react_to_click()
	_expect(
		visual.get_current_behavior_id() == &"click_happy",
		"A configured click behavior must replace the legacy click pose."
	)
	visual.react_to_keyboard()
	_expect(
		visual.get_current_behavior_id() == &"click_happy",
		"Keyboard activity must not interrupt a click behavior."
	)
	visual.react_to_reminder()
	_expect(
		visual.get_current_behavior_id() == &"attention",
		"A reminder behavior must interrupt lower-priority behavior."
	)
	visual._process(2.5)
	_expect(
		visual.get_current_behavior_id() == &"idle",
		"A completed reminder behavior must return to idle."
	)

	visual.set_focus_mode(true)
	_expect(
		visual.get_current_behavior_id() == &"focus_calm",
		"Focus mode must use the configured looping focus behavior."
	)
	visual._process(10.0)
	_expect(
		visual.get_current_behavior_id() == &"focus_calm",
		"Random idle behavior must remain suppressed during focus."
	)

	visual.set_focus_mode(false)
	definition.random_idle_interval_min = 0.0
	definition.random_idle_interval_max = 0.0
	visual.set_definition(definition)
	visual._process(0.01)
	_expect(
		visual.get_current_behavior_id() == &"idle_blink",
		"A due random-idle slot must select a configured weighted behavior."
	)

	var legacy_definition := _definition(idle_texture)
	visual.set_definition(legacy_definition)
	visual.react_to_click()
	_expect(
		visual.get_current_behavior_id() == &"click",
		"Pets without behavior clips must retain the legacy safe fallback."
	)
	visual.queue_free()


func _test_leo_pilot_pack() -> void:
	var leo_definition := load(
		"res://assets/pets/leo/pet.tres"
	) as PetDefinition
	_expect(leo_definition != null, "Leo's pet package must load.")
	if leo_definition == null:
		return
	var blink := leo_definition.behavior_by_id(&"idle_blink")
	var click_happy := leo_definition.behavior_by_id(&"click_happy")
	var focus_calm := leo_definition.behavior_by_id(&"focus_calm")
	var reminder_attention := leo_definition.behavior_by_id(
		&"reminder_attention"
	)
	var keyboard := leo_definition.behavior_by_id(&"keyboard")
	var mouse := leo_definition.behavior_by_id(&"mouse")
	_expect(
		blink != null
		and blink.trigger == PetBehaviorDefinition.Trigger.RANDOM_IDLE
		and blink.frames.size() == 3
		and blink.frames[0] == leo_definition.idle_texture
		and blink.frames[2] == leo_definition.idle_texture,
		"Leo's blink must reuse the idle frame around one closed-eye frame."
	)
	if blink != null:
		_expect(
			blink.texture_at(0.2) == blink.frames[1]
			and blink.texture_at(0.3) == leo_definition.idle_texture,
			"Leo's blink must close and reopen on the configured timeline."
		)
	_expect(
		click_happy != null
		and click_happy.trigger == PetBehaviorDefinition.Trigger.CLICK
		and click_happy.frames.size() == 2
		and click_happy.frames[0] == leo_definition.idle_texture
		and is_equal_approx(
			click_happy.runtime_duration_seconds(),
			1.0
		),
		"Leo's click response must hold one happy frame for one second."
	)
	if click_happy != null:
		_expect(
			click_happy.texture_at(0.2) == click_happy.frames[1]
			and click_happy.texture_at(0.9) == click_happy.frames[1],
			"Leo's happy face must remain visible after its short entrance."
		)
	_expect(
		focus_calm != null
		and focus_calm.trigger == PetBehaviorDefinition.Trigger.FOCUS
		and focus_calm.playback == PetBehaviorDefinition.Playback.LOOP
		and focus_calm.frames.size() == 6
		and focus_calm.frames[0] == focus_calm.frames[4]
		and focus_calm.frames[5] != focus_calm.frames[0],
		"Leo's focus loop must hold calm for five beats before blinking."
	)
	if focus_calm != null:
		_expect(
			focus_calm.texture_at(0.2) == focus_calm.frames[0]
			and focus_calm.texture_at(5.2) == focus_calm.frames[5]
			and focus_calm.texture_at(6.2) == focus_calm.frames[0],
			"Leo's six-second focus loop must repeat without ending."
		)
	_expect(
		reminder_attention != null
		and reminder_attention.trigger
			== PetBehaviorDefinition.Trigger.REMINDER
		and reminder_attention.playback
			== PetBehaviorDefinition.Playback.PING_PONG
		and reminder_attention.frames.size() == 2
		and reminder_attention.frames[1] == leo_definition.idle_texture
		and reminder_attention.allowed_during_focus,
		"Leo's reminder must react immediately and remain available in focus."
	)
	if reminder_attention != null:
		_expect(
			reminder_attention.texture_at(0.2)
				== reminder_attention.frames[0]
			and reminder_attention.texture_at(0.6)
				== leo_definition.idle_texture
			and reminder_attention.texture_at(1.1)
				== reminder_attention.frames[0],
			"Leo's reminder attention frame must use a gentle two-Hz pulse."
		)
	_expect(
		keyboard != null
		and keyboard.trigger == PetBehaviorDefinition.Trigger.KEYBOARD
		and keyboard.playback == PetBehaviorDefinition.Playback.LOOP
		and keyboard.frames.size() == 2
		and keyboard.frames[0] != keyboard.frames[1]
		and is_equal_approx(keyboard.runtime_duration_seconds(), 0.5)
		and keyboard.allowed_during_focus,
		"Leo's keyboard behavior must alternate two paws and work in focus."
	)
	if keyboard != null:
		_expect(
			keyboard.texture_at(0.05) == keyboard.frames[0]
			and keyboard.texture_at(0.20) == keyboard.frames[1]
			and keyboard.texture_at(0.35) == keyboard.frames[0],
			"Leo's keyboard loop must alternate left and right paw taps."
		)
	_expect(
		mouse != null
		and mouse.trigger == PetBehaviorDefinition.Trigger.MOUSE
		and mouse.playback == PetBehaviorDefinition.Playback.LOOP
		and mouse.frames.size() == 2
		and mouse.frames[0] != mouse.frames[1]
		and is_equal_approx(mouse.runtime_duration_seconds(), 0.5)
		and mouse.allowed_during_focus,
		"Leo's mouse behavior must alternate two curious focus-safe tilts."
	)
	if mouse != null:
		_expect(
			mouse.texture_at(0.10) == mouse.frames[0]
			and mouse.texture_at(0.30) == mouse.frames[1]
			and mouse.texture_at(0.55) == mouse.frames[0],
			"Leo's mouse loop must alternate its two head tilts."
		)
	_expect(
		leo_definition.behavior_validation_errors().is_empty(),
		"Leo's pilot behavior must satisfy canvas and resource validation."
	)
	_expect(
		PetBehaviorProfileScript.validation_errors(
			leo_definition,
			true
		).is_empty(),
		"Leo's completed version-one behavior profile must pass validation."
	)

	var visual := PetVisualScript.new()
	root.add_child(visual)
	visual.set_definition(leo_definition)
	visual._process(10.0)
	_expect(
		visual.get_current_behavior_id() == &"idle_blink",
		"Leo must automatically start the blink when its idle slot is due."
	)
	visual.react_to_click()
	_expect(
		visual.get_current_behavior_id() == &"click_happy",
		"Clicking Leo must interrupt the blink with his happy response."
	)
	visual._process(0.81)
	_expect(
		visual.get_current_behavior_id() == &"click_happy",
		"Leo's smile must outlast the short click jump."
	)
	visual._process(0.20)
	_expect(
		visual.get_current_behavior_id() == &"idle",
		"Leo must return to idle after his click response."
	)
	visual.set_focus_mode(true)
	_expect(
		visual.get_current_behavior_id() == &"focus_calm",
		"Starting focus must switch Leo to his configured calm loop."
	)
	visual._process(6.2)
	_expect(
		visual.get_current_behavior_id() == &"focus_calm",
		"Leo's calm behavior must remain active throughout focus."
	)
	visual.react_to_keyboard(5)
	visual._process(0.2)
	var keyboard_elapsed_before_repeat := visual._active_behavior_elapsed
	visual.react_to_keyboard(5)
	_expect(
		visual.get_current_behavior_id() == &"keyboard"
		and is_equal_approx(
			visual._active_behavior_elapsed,
			keyboard_elapsed_before_repeat
		),
		"Repeated keyboard batches must extend, not restart, the paw loop."
	)
	visual._process(0.51)
	_expect(
		visual.get_current_behavior_id() == &"focus_calm",
		"Leo must return to his focus loop after keyboard activity stops."
	)
	visual.react_to_mouse(5)
	visual._process(0.2)
	var mouse_elapsed_before_repeat := visual._active_behavior_elapsed
	visual.react_to_mouse(5)
	_expect(
		visual.get_current_behavior_id() == &"mouse"
		and is_equal_approx(
			visual._active_behavior_elapsed,
			mouse_elapsed_before_repeat
		),
		"Repeated mouse batches must extend, not restart, the tilt loop."
	)
	visual._process(0.51)
	_expect(
		visual.get_current_behavior_id() == &"focus_calm",
		"Leo must return to his focus loop after mouse activity stops."
	)
	_expect(
		visual.preview_behavior(&"idle_blink"),
		"The developer preview API must accept a configured behavior."
	)
	_expect(
		visual.get_current_behavior_id() == &"idle_blink",
		"Developer preview must start the requested behavior immediately."
	)
	visual._process(0.5)
	_expect(
		visual.get_current_behavior_id() == &"focus_calm",
		"Developer preview must restore the prior focus base state."
	)
	_expect(
		not visual.preview_behavior(&"missing_behavior"),
		"Developer preview must safely reject an unavailable behavior."
	)
	visual.react_to_reminder()
	_expect(
		visual.get_current_behavior_id() == &"reminder_attention",
		"Leo's reminder must visibly override his focus loop."
	)
	visual._process(2.41)
	_expect(
		visual.get_current_behavior_id() == &"focus_calm",
		"Leo must return to his calm loop after a focus-time reminder."
	)
	visual.set_focus_mode(false)
	_expect(
		visual.get_current_behavior_id() == &"idle",
		"Ending focus must return Leo to his normal idle state."
	)
	visual.queue_free()


func _test_standard_profile(texture: Texture2D) -> void:
	var definition := _definition(texture)
	for behavior_id in PetBehaviorProfileScript.REQUIRED_BEHAVIORS:
		var behavior := _behavior(
			behavior_id,
			PetBehaviorProfileScript.REQUIRED_BEHAVIORS[behavior_id],
			[texture]
		)
		if behavior_id == &"focus_calm":
			behavior.playback = PetBehaviorDefinition.Playback.LOOP
		definition.behaviors.append(behavior)

	_expect(
		PetBehaviorProfileScript.validation_errors(
			definition,
			true
		).is_empty(),
		"A complete version-one behavior profile must pass validation."
	)

	var remaining_behaviors: Array[PetBehaviorDefinition] = []
	for behavior in definition.behaviors:
		if behavior.behavior_id != &"reminder_attention":
			remaining_behaviors.append(behavior)
	definition.behaviors = remaining_behaviors
	var errors := PetBehaviorProfileScript.validation_errors(
		definition,
		true
	)
	var missing_reminder_reported := false
	for error in errors:
		if error.contains("reminder_attention"):
			missing_reminder_reported = true
			break
	_expect(
		missing_reminder_reported,
		"Complete-profile validation must report a missing core behavior."
	)


func _definition(idle_texture: Texture2D) -> PetDefinition:
	var definition := PetDefinitionScript.new()
	definition.pet_id = &"behavior_test"
	definition.display_name = "Behavior Test"
	definition.idle_texture = idle_texture
	definition.display_size = Vector2(224, 224)
	definition.interaction_polygon = PackedVector2Array([
		Vector2(-100, -100),
		Vector2(100, -100),
		Vector2(100, 100),
		Vector2(-100, 100),
	])
	return definition


func _behavior(
	behavior_id: StringName,
	trigger: PetBehaviorDefinition.Trigger,
	frames: Array[Texture2D]
) -> PetBehaviorDefinition:
	var behavior := PetBehaviorDefinitionScript.new()
	behavior.behavior_id = behavior_id
	behavior.trigger = trigger
	behavior.frames = frames
	behavior.frames_per_second = 4.0
	behavior.playback = PetBehaviorDefinition.Playback.ONCE
	return behavior


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
