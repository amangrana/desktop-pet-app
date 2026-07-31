extends SceneTree

const PetDialogueManagerScript := preload(
	"res://src/pets/pet_dialogue_manager.gd"
)
const PetDialogueProfileScript := preload(
	"res://src/pets/pet_dialogue_profile.gd"
)
const LEO_DIALOGUE := preload("res://assets/pets/leo/dialogue.tres")
const BOBO_DIALOGUE := preload("res://assets/pets/bobo/dialogue.tres")
const MABLE_DIALOGUE := preload("res://assets/pets/mable/dialogue.tres")
const MILO_DIALOGUE := preload("res://assets/pets/milo/dialogue.tres")

var _fake_now := 10_000.0
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var profile: PetDialogueProfile = LEO_DIALOGUE
	_expect(
		profile.is_configured()
		and profile.validation_errors().is_empty()
		and profile.configured_contexts()
		== PetDialogueProfileScript.STANDARD_CONTEXT_ORDER,
		"Leo must provide a valid version-one dialogue profile"
	)
	for pet_profile in [
		BOBO_DIALOGUE,
		MABLE_DIALOGUE,
		MILO_DIALOGUE,
	]:
		_expect(
			pet_profile.is_configured()
			and pet_profile.validation_errors().is_empty()
			and pet_profile.configured_contexts()
			== PetDialogueProfileScript.STANDARD_CONTEXT_ORDER
			and pet_profile.available_locales()
			== PackedStringArray(["en", "zh_cn"]),
			"every pet must provide five contexts and English/Chinese locales"
		)
	_expect(
		BOBO_DIALOGUE.resolve_line(&"bobo.click.01", "en")
		== "Oh, hello. I'm glad you came by."
		and BOBO_DIALOGUE.resolve_line(&"bobo.click.01", "zh_CN")
		== "你好呀，很高兴你过来看看我。"
		and MABLE_DIALOGUE.resolve_line(&"mable.click.01", "en")
		== "Oh, there you are. Stay a moment."
		and MABLE_DIALOGUE.resolve_line(&"mable.click.01", "zh_CN")
		== "你来啦，再陪我一会儿吧。",
		"Bobo and Mable must retain their revised distinct personalities"
	)

	var manager = PetDialogueManagerScript.new()
	manager.time_source = func() -> float: return _fake_now
	manager.set_random_seed(7)
	manager.set_profile(profile, &"leo")
	root.add_child(manager)

	var click_lines := profile.lines_for_context(
		PetDialogueProfileScript.CONTEXT_CLICK,
		"en"
	)
	var first_click: String = manager.request_line(
		PetDialogueProfileScript.CONTEXT_CLICK,
		"en"
	)
	_expect(
		first_click in click_lines,
		"runtime dialogue must come from the configured English lines"
	)
	_expect(
		manager.request_line(
			PetDialogueProfileScript.CONTEXT_CLICK,
			"en"
		).is_empty(),
		"context and global cooldowns must suppress immediate repetition"
	)

	var preview_line: String = manager.request_line(
		PetDialogueProfileScript.CONTEXT_CLICK,
		"en",
		true
	)
	_expect(
		preview_line in click_lines
		and manager.request_line(
			PetDialogueProfileScript.CONTEXT_CLICK,
			"en"
		).is_empty(),
		"Developer previews must bypass but not consume runtime cooldowns"
	)

	_fake_now += 9.0
	var second_click: String = manager.request_line(
		PetDialogueProfileScript.CONTEXT_CLICK,
		"en"
	)
	_expect(
		second_click in click_lines
		and second_click != first_click,
		"successive eligible lines should avoid immediate repetition"
	)

	_fake_now += 9.0
	var chinese_click: String = manager.request_line(
		PetDialogueProfileScript.CONTEXT_CLICK,
		"zh_CN"
	)
	_expect(
		chinese_click in profile.lines_for_context(
			PetDialogueProfileScript.CONTEXT_CLICK,
			"zh_CN"
		),
		"the current interface language must select Chinese package lines"
	)
	_expect(
		profile.resolve_line(&"leo.click.01", "zh-CN")
		== "嗨，我正等你来看看我。"
		and profile.resolve_line(&"leo.click.01", "en_CA")
		== "Hi. I was hoping you'd stop by."
		and profile.resolve_line(&"leo.click.01", "fr_CA")
		== "Hi. I was hoping you'd stop by.",
		"locale lookup must normalize separators, try base language, and use English"
	)

	manager.set_profile(profile, &"leo")
	_fake_now += 481.0
	_expect(
		manager.idle_is_due(),
		"the configured low-frequency idle interval must eventually mature"
	)
	var idle_line: String = manager.request_line(
		PetDialogueProfileScript.CONTEXT_IDLE,
		"en"
	)
	_expect(
		not idle_line.is_empty() and not manager.idle_is_due(),
		"showing an idle line must schedule the next idle interval"
	)

	manager.set_enabled(false)
	_fake_now += 500.0
	_expect(
		manager.request_line(
			PetDialogueProfileScript.CONTEXT_CLICK,
			"en"
		).is_empty()
		and not manager.idle_is_due(),
		"disabling dialogue must suppress runtime click and idle lines"
	)
	manager.set_enabled(true)
	_expect(
		not manager.idle_is_due(),
		"re-enabling dialogue must start a fresh idle interval"
	)
	var invalid_profile = PetDialogueProfileScript.new()
	manager.set_profile(invalid_profile, &"invalid")
	_expect(
		manager.profile == null,
		"an invalid optional dialogue profile must fall back safely"
	)

	if _failed:
		quit(1)
		return
	print("Pet dialogue manager self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Pet dialogue manager self-test failed: %s" % message)
