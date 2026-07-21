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
		"Chinese locale codes must normalize to the Chinese interface"
	)
	_expect(
		AppLocalizationScript.normalize("en_CA")
		== AppLocalizationScript.ENGLISH,
		"non-Chinese locales must select English"
	)
	_expect(
		AppLocalizationScript.normalize("")
		== AppLocalizationScript.ENGLISH,
		"missing locale information must default to English"
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
	_expect(
		AppLocalizationScript.text(
			AppLocalizationScript.ENGLISH,
			"duration_settings_saved"
		) == "Durations saved."
		and AppLocalizationScript.text(
			AppLocalizationScript.CHINESE,
			"duration_settings_saved"
		) == "时长已保存。",
		"duration save confirmation must not call user values defaults"
	)
	_expect(
		AppLocalizationScript.text(
			AppLocalizationScript.ENGLISH,
			"duration_settings_menu"
		) == "Set durations"
		and AppLocalizationScript.text(
			AppLocalizationScript.CHINESE,
			"duration_settings_menu"
		) == "设置时长",
		"duration settings menu must stay compact in both languages"
	)
	_expect(
		AppLocalizationScript.text(
			AppLocalizationScript.ENGLISH,
			"activity_center_menu"
		) == "Activity Center…"
		and AppLocalizationScript.text(
			AppLocalizationScript.CHINESE,
			"activity_center_menu"
		) == "活动中心…"
		and AppLocalizationScript.text(
			AppLocalizationScript.CHINESE,
			"activity_center_status_due_queued"
		) == "待处理 — 将在勿扰结束后显示",
		"Activity Center must provide complete English and Chinese text"
	)
	_expect(
		AppLocalizationScript.text(
			AppLocalizationScript.ENGLISH,
			"activity_center_pending_many",
			[2]
		) == "2 reminders need attention"
		and AppLocalizationScript.text(
			AppLocalizationScript.CHINESE,
			"activity_center_pending_many",
			[2]
		) == "有 2 项提醒待处理"
		and AppLocalizationScript.text(
			AppLocalizationScript.CHINESE,
			"activity_event_reminder_snoozed",
			["喝水"]
		) == "喝水提醒已延后",
		(
			"Activity Center pending and recent activity text must "
			+ "format in both languages"
		)
	)
	_expect(
		AppLocalizationScript.text(
			AppLocalizationScript.ENGLISH,
			"quiet_settings_menu"
		) == "Quiet hours…"
		and AppLocalizationScript.text(
			AppLocalizationScript.CHINESE,
			"quiet_settings_menu"
		) == "设置勿扰时段…"
		and AppLocalizationScript.text(
			AppLocalizationScript.ENGLISH,
			"quiet_hours_range",
			[22, 8]
		) == "Quiet hours: 22:00–08:00"
		and AppLocalizationScript.text(
			AppLocalizationScript.CHINESE,
			"quiet_hours_range",
			[22, 8]
		) == "勿扰时段：22:00–08:00"
		and AppLocalizationScript.text(
			AppLocalizationScript.CHINESE,
			"quiet_hours_inactive_tooltip"
		) == "当前不在勿扰时段内。",
		(
			"quiet-hours range and status tooltip must be compact and "
			+ "available in both languages"
		)
	)
	_expect(
		AppLocalizationScript.text(
			AppLocalizationScript.ENGLISH,
			"bubble_turn_off"
		) == "Turn off"
		and AppLocalizationScript.text(
			AppLocalizationScript.CHINESE,
			"bubble_turn_off"
		) == "关闭"
		and AppLocalizationScript.text(
			AppLocalizationScript.ENGLISH,
			"bubble_ok"
		) == "OK"
		and AppLocalizationScript.text(
			AppLocalizationScript.CHINESE,
			"bubble_ok"
		) == "知道了"
		and not english.has("bubble_more")
		and not english.has("bubble_skip")
		and not english.has("bubble_pause_today"),
		(
			"health reminder bubbles must expose a bilingual direct "
			+ "Turn off action without the removed More choices"
		)
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
