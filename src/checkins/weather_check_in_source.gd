class_name WeatherCheckInSource
extends "res://src/checkins/pet_note_source.gd"

const SOURCE_ID := "weather"
const CARD_INTERVAL_SECONDS := 6 * 60 * 60
const CARD_LIFETIME_SECONDS := 6 * 60 * 60
const ATTRIBUTION_URL := "https://open-meteo.com/"

var time_source := Callable()
var _published_ids: Dictionary = {}
var _preview_sequence := 0


func _init() -> void:
	super(SOURCE_ID)


func publish_weather(
	weather: Dictionary,
	force_preview := false
) -> bool:
	var card := create_weather_card(weather, force_preview)
	if card.is_empty():
		return false
	var published := publish_card(card)
	if published and not force_preview:
		_published_ids[str(card.get("id", ""))] = true
	return published


func create_weather_card(
	weather: Dictionary,
	force_preview := true
) -> Dictionary:
	var location := str(
		weather.get("display_name", weather.get("name", ""))
	).strip_edges()
	if location.is_empty():
		return {}
	var now := _now()
	var card_id := card_id_for(weather)
	var location_id := card_id.split(":")[1]
	if force_preview:
		_preview_sequence += 1
		card_id += ":preview:%d" % _preview_sequence
	elif _published_ids.has(card_id):
		return {}
	var current := int(round(float(weather.get("temperature_c", 0.0))))
	var maximum := int(
		round(float(weather.get("temperature_max_c", 0.0)))
	)
	var minimum := int(
		round(float(weather.get("temperature_min_c", 0.0)))
	)
	var weather_code := int(weather.get("weather_code", -1))
	var messages := {
		"en": (
			"%s: %d°C, %s. Today %d–%d°C. Data: Open-Meteo."
			% [
				location,
				current,
				condition_text(weather_code, "en"),
				minimum,
				maximum,
			]
		),
		"zh_CN": (
			"%s：%d°C，%s。今天 %d–%d°C。数据：Open-Meteo。"
			% [
				location,
				current,
				condition_text(weather_code, "zh_CN"),
				minimum,
				maximum,
			]
		),
	}
	return PetNoteCardScript.normalize({
		"id": card_id,
		"source": SOURCE_ID,
		"title": location,
		"localized_messages": messages,
		"display_seconds": 12,
		"expires_unix": now + CARD_LIFETIME_SECONDS,
		"priority": -10,
		"action_url": ATTRIBUTION_URL,
		"metadata": {
			"provider": "open_meteo",
			"location_id": location_id,
			"weather_code": weather_code,
			"temperature_c": current,
			"temperature_max_c": maximum,
			"temperature_min_c": minimum,
			"fetched_unix": float(
				weather.get("fetched_unix", now)
			),
			"is_preview": force_preview,
		},
	})


func card_id_for(weather: Dictionary) -> String:
	var location := str(
		weather.get("display_name", weather.get("name", ""))
	).strip_edges()
	if location.is_empty():
		return ""
	var location_id := str(weather.get("id", "")).strip_edges()
	if location_id.is_empty() or location_id == "0":
		location_id = location.to_lower().sha256_text().substr(0, 16)
	var bucket := int(floor(_now() / CARD_INTERVAL_SECONDS))
	return "weather:%s:%d" % [location_id, bucket]


func reset_history() -> void:
	_published_ids.clear()


static func condition_text(code: int, language: String) -> String:
	var condition := "unknown"
	if code == 0:
		condition = "clear"
	elif code >= 1 and code <= 3:
		condition = "cloudy"
	elif code == 45 or code == 48:
		condition = "fog"
	elif (
		(code >= 51 and code <= 67)
		or (code >= 80 and code <= 82)
	):
		condition = "rain"
	elif (
		(code >= 71 and code <= 77)
		or code == 85
		or code == 86
	):
		condition = "snow"
	elif code >= 95 and code <= 99:
		condition = "storm"
	var translations := {
		"en": {
			"clear": "clear",
			"cloudy": "partly cloudy",
			"fog": "foggy",
			"rain": "rain",
			"snow": "snow",
			"storm": "thunderstorms",
			"unknown": "current conditions available",
		},
		"zh_CN": {
			"clear": "晴朗",
			"cloudy": "多云",
			"fog": "有雾",
			"rain": "有雨",
			"snow": "有雪",
			"storm": "有雷暴",
			"unknown": "天气状况已更新",
		},
	}
	var safe_language := (
		language if translations.has(language) else "en"
	)
	return str(translations[safe_language][condition])


func _now() -> float:
	if time_source.is_valid():
		return float(time_source.call())
	return Time.get_unix_time_from_system()
