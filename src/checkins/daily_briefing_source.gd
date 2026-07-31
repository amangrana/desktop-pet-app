class_name DailyBriefingSource
extends "res://src/checkins/pet_note_source.gd"

const WeatherCheckInSourceScript := preload(
	"res://src/checkins/weather_check_in_source.gd"
)

const SOURCE_ID := "daily_briefing"
const CARD_PRIORITY := -5
const CARD_DISPLAY_SECONDS := 12
const CALENDAR_REMINDER_LEAD_SECONDS := 60 * 60

const ENGLISH_MONTHS_SHORT := [
	"Jan",
	"Feb",
	"Mar",
	"Apr",
	"May",
	"Jun",
	"Jul",
	"Aug",
	"Sep",
	"Oct",
	"Nov",
	"Dec",
]
const ENGLISH_WEEKDAYS := [
	"Sun",
	"Mon",
	"Tue",
	"Wed",
	"Thu",
	"Fri",
	"Sat",
]
const CHINESE_WEEKDAYS := [
	"日",
	"一",
	"二",
	"三",
	"四",
	"五",
	"六",
]

var datetime_source := Callable()
var time_source := Callable()
var _preview_sequence := 0


func _init() -> void:
	super(SOURCE_ID)


func publish_today(
	weather: Dictionary = {},
	events: Array[Dictionary] = [],
	weather_note_id := "",
	force_preview := false
) -> bool:
	return publish_card(
		create_briefing_card(
			{},
			weather,
			events,
			weather_note_id,
			force_preview
		)
	)


func create_briefing_card(
	datetime: Dictionary = {},
	weather: Dictionary = {},
	events: Array[Dictionary] = [],
	weather_note_id := "",
	force_preview := false
) -> Dictionary:
	var local_datetime := (
		datetime.duplicate(true)
		if not datetime.is_empty()
		else _local_datetime()
	)
	var year := int(local_datetime.get("year", 0))
	var month := int(local_datetime.get("month", 0))
	var day := int(local_datetime.get("day", 0))
	var weekday := int(local_datetime.get("weekday", -1))
	var hour := int(local_datetime.get("hour", -1))
	if (
		year < 1
		or month < 1
		or month > 12
		or day < 1
		or day > 31
		or weekday < 0
		or weekday >= ENGLISH_WEEKDAYS.size()
		or hour < 0
		or hour > 23
	):
		return {}
	var date_key := "%04d-%02d-%02d" % [year, month, day]
	var card_id := "daily_briefing:%s" % date_key
	if force_preview:
		_preview_sequence += 1
		card_id += ":preview:%d" % _preview_sequence
	var messages := {
		"en": _message_for(
			"en",
			local_datetime,
			weather,
			events
		),
		"zh_CN": _message_for(
			"zh_CN",
			local_datetime,
			weather,
			events
		),
	}
	return PetNoteCardScript.normalize({
		"id": card_id,
		"source": SOURCE_ID,
		"localized_messages": messages,
		"display_seconds": CARD_DISPLAY_SECONDS,
		"expires_unix": _expiry_unix(local_datetime),
		"priority": CARD_PRIORITY,
		"metadata": {
			"date_key": date_key,
			"is_preview": force_preview,
			"includes_weather": not weather.is_empty(),
			"weather_note_id": str(weather_note_id),
		},
	})


func today_key() -> String:
	var local_datetime := _local_datetime()
	return "%04d-%02d-%02d" % [
		int(local_datetime.get("year", 0)),
		int(local_datetime.get("month", 0)),
		int(local_datetime.get("day", 0)),
	]


func _message_for(
	language: String,
	datetime: Dictionary,
	weather: Dictionary,
	events: Array[Dictionary]
) -> String:
	var lines: Array[String] = [
		_greeting_date_line(language, datetime),
	]
	var weather_line := _weather_line(language, weather)
	if not weather_line.is_empty():
		lines.append(weather_line)
	var event_line := _event_line(language, datetime, events)
	if not event_line.is_empty():
		lines.append(event_line)
	return "\n".join(lines.slice(0, 3))


func _greeting_date_line(
	language: String,
	datetime: Dictionary
) -> String:
	var month := int(datetime.get("month", 1))
	var day := int(datetime.get("day", 1))
	var weekday := int(datetime.get("weekday", 0))
	var hour := int(datetime.get("hour", 0))
	if language == "zh_CN":
		var greeting := (
			"早上好！"
			if hour < 12
			else ("下午好！" if hour < 18 else "晚上好！")
		)
		return "%s%d月%d日，星期%s。" % [
			greeting,
			month,
			day,
			CHINESE_WEEKDAYS[weekday],
		]
	var greeting := (
		"Good morning!"
		if hour < 12
		else ("Good afternoon!" if hour < 18 else "Good evening!")
	)
	return "%s %s, %s %d." % [
		greeting,
		ENGLISH_WEEKDAYS[weekday],
		ENGLISH_MONTHS_SHORT[month - 1],
		day,
	]


func _weather_line(language: String, weather: Dictionary) -> String:
	if (
		weather.is_empty()
		or not weather.has("temperature_c")
		or not weather.has("weather_code")
	):
		return ""
	var location := str(
		weather.get("name", weather.get("display_name", ""))
	).strip_edges()
	if location.is_empty():
		return ""
	return "%s · %d°C · %s" % [
		_compact_text(location, 18),
		int(round(float(weather.get("temperature_c", 0.0)))),
		WeatherCheckInSourceScript.condition_text(
			int(weather.get("weather_code", -1)),
			language
		),
	]


func _event_line(
	language: String,
	datetime: Dictionary,
	events: Array[Dictionary]
) -> String:
	var now := _now()
	var day_end := _expiry_unix(datetime)
	var candidates: Array[Dictionary] = []
	for event_data in events:
		var title := str(event_data.get("title", "")).strip_edges()
		var start_unix := float(event_data.get("start_unix", 0.0))
		var end_unix := float(event_data.get("end_unix", 0.0))
		var is_all_day := bool(event_data.get("is_all_day", false))
		if title.is_empty():
			continue
		if is_all_day:
			if start_unix <= now and end_unix > now:
				candidates.append(event_data)
			continue
		if (
			start_unix > now + CALENDAR_REMINDER_LEAD_SECONDS
			and start_unix < day_end
		):
			candidates.append(event_data)
	if candidates.is_empty():
		return ""
	candidates.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			var left_all_day := bool(left.get("is_all_day", false))
			var right_all_day := bool(right.get("is_all_day", false))
			if left_all_day != right_all_day:
				return left_all_day
			return (
				float(left.get("start_unix", 0.0))
				< float(right.get("start_unix", 0.0))
			)
	)
	var event_data: Dictionary = candidates[0]
	var title := _compact_text(
		str(event_data.get("title", "")),
		28
	)
	if bool(event_data.get("is_all_day", false)):
		return (
			"全天 · %s" % title
			if language == "zh_CN"
			else "All day · %s" % title
		)
	var remaining_seconds := maxi(
		60,
		int(float(event_data.get("start_unix", now)) - now)
	)
	var remaining_text := _relative_time(
		language,
		remaining_seconds
	)
	return (
		"下一项 · %s · %s" % [title, remaining_text]
		if language == "zh_CN"
		else "Next · %s · %s" % [title, remaining_text]
	)


func _relative_time(language: String, seconds: int) -> String:
	var minutes := maxi(1, ceili(seconds / 60.0))
	if minutes < 120:
		return (
			"%d分钟后" % minutes
			if language == "zh_CN"
			else "%d min" % minutes
		)
	var hours := maxi(2, roundi(minutes / 60.0))
	return (
		"约%d小时后" % hours
		if language == "zh_CN"
		else "~%d hr" % hours
	)


func _compact_text(value: String, max_characters: int) -> String:
	var compact := value.strip_edges().replace("\n", " ")
	if compact.length() <= max_characters:
		return compact
	return compact.left(maxi(1, max_characters - 1)) + "…"


func _local_datetime() -> Dictionary:
	if datetime_source.is_valid():
		var value = datetime_source.call()
		if value is Dictionary:
			return value.duplicate(true)
	return Time.get_datetime_dict_from_system(false)


func _expiry_unix(local_datetime: Dictionary) -> float:
	var elapsed_seconds := (
		int(local_datetime.get("hour", 0)) * 60 * 60
		+ int(local_datetime.get("minute", 0)) * 60
		+ int(local_datetime.get("second", 0))
	)
	return _now() + maxi(1, 24 * 60 * 60 - elapsed_seconds)


func _now() -> float:
	if time_source.is_valid():
		return float(time_source.call())
	return Time.get_unix_time_from_system()
