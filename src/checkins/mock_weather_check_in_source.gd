class_name MockWeatherCheckInSource
extends "res://src/checkins/pet_note_source.gd"

const SOURCE_ID := "weather_mock"
const SAMPLE_LIFETIME_SECONDS := 15 * 60

var time_source := Callable()
var _sample_sequence := 0


func _init() -> void:
	super(SOURCE_ID)


func publish_sample() -> bool:
	_sample_sequence += 1
	return publish_card({
		"id": "weather-mock:%d" % _sample_sequence,
		"title": "Weather",
		"localized_messages": {
			"en": (
				"Toronto: 18°C and partly cloudy. "
				+ "A light jacket may help."
			),
			"zh_CN": (
				"多伦多：18°C，多云间晴。"
				+ "出门可以带件薄外套。"
			),
		},
		"display_seconds": 10,
		"expires_unix": _now() + SAMPLE_LIFETIME_SECONDS,
		"priority": 100,
		"metadata": {
			"city": "Toronto",
			"temperature_c": 18,
			"condition": "partly_cloudy",
			"is_mock": true,
		},
	})


func _now() -> float:
	if time_source.is_valid():
		return float(time_source.call())
	return Time.get_unix_time_from_system()
