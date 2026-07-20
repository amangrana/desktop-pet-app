extends SceneTree

const AppLocalizationScript := preload(
	"res://src/localization/app_localization.gd"
)

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var english: Dictionary = AppLocalizationScript.STRINGS[
		AppLocalizationScript.ENGLISH
	]
	var chinese: Dictionary = AppLocalizationScript.STRINGS[
		AppLocalizationScript.CHINESE
	]
	for key in english:
		_expect(
			chinese.has(key),
			"Chinese catalog must contain key: %s" % key
		)
	for key in chinese:
		_expect(
			english.has(key),
			"English catalog must contain key: %s" % key
		)

	_expect(
		AppLocalizationScript.normalize("zh_TW")
		== AppLocalizationScript.CHINESE,
		"Chinese system locales must select the Chinese interface"
	)
	_expect(
		AppLocalizationScript.normalize("en_CA")
		== AppLocalizationScript.ENGLISH,
		"non-Chinese locales must select English"
	)
	_expect(
		AppLocalizationScript.text(
			AppLocalizationScript.ENGLISH,
			"scale",
			[125]
		) == "Scale: 125%",
		"English formatting must preserve literal percent signs"
	)
	_expect(
		AppLocalizationScript.text(
			AppLocalizationScript.CHINESE,
			"water_prompt"
		) == "该喝点水啦，要不要喝几口？",
		"Chinese reminder copy must be available"
	)

	if _failed:
		quit(1)
		return
	print("Localization self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Localization self-test failed: %s" % message)
