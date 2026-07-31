extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")
const PetDialogueProfileScript := preload(
	"res://src/pets/pet_dialogue_profile.gd"
)

const PET_DIALOGUE_MENU_ID := 61
const DEV_DIALOGUE_PREVIEW_MENU_ID := 68

var _fake_now := 10_000.0
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	main.settings.pet_dialogue_enabled = true
	main.settings.language = "en"
	main.pet_dialogue_manager.time_source = func() -> float:
		return _fake_now
	main.pet_dialogue_manager.set_random_seed(11)
	main.pet_dialogue_manager.set_enabled(true)
	main.pet_dialogue_manager.set_profile(
		main.pet.definition.dialogue_profile,
		main.pet.get_pet_id()
	)
	main._update_menu_checks()
	var profile: PetDialogueProfile = main.pet.definition.dialogue_profile
	_expect(
		main.pet.get_pet_id() == &"leo"
		and profile != null
		and profile.is_configured(),
		"Leo must load its dialogue profile through the pet package"
	)
	_expect(
		main.settings_menu.get_item_index(PET_DIALOGUE_MENU_ID) >= 0
		and main.settings_menu.is_item_checked(
			main.settings_menu.get_item_index(PET_DIALOGUE_MENU_ID)
		)
		and main.developer_menu.get_item_index(
			DEV_DIALOGUE_PREVIEW_MENU_ID
		) >= 0,
		"settings and Developer menus must expose dialogue controls"
	)

	main._hide_notification()
	main._handle_pet_tap(main.pet.position)
	var click_lines := profile.lines_for_context(
		PetDialogueProfileScript.CONTEXT_CLICK,
		"en"
	)
	_expect(
		main.notification_panel.visible
		and main.notification_label.text in click_lines,
		"an eligible normal click must show a configured Leo line"
	)
	main._hide_notification()
	main._handle_pet_tap(main.pet.position)
	_expect(
		not main.notification_panel.visible,
		"rapid repeated clicks must respect the dialogue cooldown"
	)

	_fake_now += 9.0
	main.settings.language = "zh_CN"
	main._handle_pet_tap(main.pet.position)
	_expect(
		main.notification_label.text in profile.lines_for_context(
			PetDialogueProfileScript.CONTEXT_CLICK,
			"zh_CN"
		),
		"click dialogue must follow the current Chinese interface language"
	)

	main._hide_notification()
	_fake_now += 9.0
	main.settings.language = "en"
	main._handle_focus_hotspot_tap()
	var focus_lines := profile.lines_for_context(
		PetDialogueProfileScript.CONTEXT_FOCUS_START,
		"en"
	)
	var focus_message_lines: PackedStringArray = (
		main.notification_label.text.split("\n")
	)
	_expect(
		focus_message_lines.size() == 2
		and "Focus started" in focus_message_lines[0]
		and focus_message_lines[1] in focus_lines,
		"focus confirmation must retain status and add one personality line"
	)
	main.timer_manager.cancel()
	main._hide_notification()

	_fake_now += 31.0
	var reminder_message: String = main._message_with_pet_dialogue(
		"Water reminder completed",
		PetDialogueProfileScript.CONTEXT_REMINDER_DONE
	)
	var reminder_message_lines: PackedStringArray = reminder_message.split(
		"\n"
	)
	_expect(
		reminder_message_lines.size() == 2
		and reminder_message_lines[1] in profile.lines_for_context(
			PetDialogueProfileScript.CONTEXT_REMINDER_DONE,
			"en"
		),
		"reminder completion must preserve status and add one pet line"
	)

	_fake_now += 31.0
	main.check_in_manager.set_enabled(true)
	main.check_in_manager.enqueue_card(
		"dialogue-priority-test",
		"calendar",
		"Higher-priority Pet Note",
		10
	)
	_expect(
		not main._try_show_pet_dialogue(
			PetDialogueProfileScript.CONTEXT_CLICK
		),
		"queued Pet Notes must prevent lower-priority pet dialogue"
	)
	main.check_in_manager.remove_source("calendar")

	main._handle_menu_item(PET_DIALOGUE_MENU_ID)
	_expect(
		not main.settings.pet_dialogue_enabled
		and not main.pet_dialogue_manager.is_enabled()
		and not main.settings_menu.is_item_checked(
			main.settings_menu.get_item_index(PET_DIALOGUE_MENU_ID)
		),
		"the settings toggle must disable and persist dialogue state"
	)
	var saved_config := ConfigFile.new()
	_expect(
		saved_config.load(main._settings_file_path()) == OK
		and not bool(
			saved_config.get_value("dialogue", "enabled", true)
		),
		"the disabled dialogue choice must be written to local settings"
	)

	main._handle_menu_item(DEV_DIALOGUE_PREVIEW_MENU_ID)
	_expect(
		main.dialogue_preview_window.visible
		and main.dialogue_preview_buttons.size() == 5,
		"Developer preview must list every configured Leo context"
	)
	main._preview_pet_dialogue(PetDialogueProfileScript.CONTEXT_IDLE)
	var idle_lines := profile.lines_for_context(
		PetDialogueProfileScript.CONTEXT_IDLE,
		"en"
	)
	_expect(
		main.notification_label.text in idle_lines,
		"Developer preview must work without consuming the disabled state"
	)
	main.dialogue_preview_window.hide()
	main._hide_notification()

	for pet_id in [&"bobo", &"mable", &"milo"]:
		main._select_pet(pet_id, false)
		var pet_profile: PetDialogueProfile = (
			main.pet.definition.dialogue_profile
		)
		_expect(
			pet_profile != null
			and pet_profile.is_configured()
			and main.pet_dialogue_manager.profile == pet_profile
			and main.dialogue_preview_buttons.size() == 5,
			"%s must load its own complete dialogue package" % pet_id
		)
		main._preview_pet_dialogue(PetDialogueProfileScript.CONTEXT_IDLE)
		var fitted_idle_lines := PackedStringArray()
		for line in pet_profile.lines_for_context(
			PetDialogueProfileScript.CONTEXT_IDLE,
			"en"
		):
			fitted_idle_lines.append(main._fit_pet_dialogue_line(line))
		_expect(
			main.notification_label.text in fitted_idle_lines,
			"%s preview lines must come from its own profile" % pet_id
		)
		main._hide_notification()

	main.shutting_down = true
	main.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("Pet dialogue integration self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Pet dialogue integration self-test failed: %s" % message)
