class_name OpenMeteoWeatherProvider
extends Node

signal state_changed(state: int, message: String)
signal weather_updated(weather: Dictionary)

enum State {
	IDLE,
	RESOLVING_CITY,
	FETCHING_WEATHER,
	READY,
	ERROR,
}

const DEFAULT_GEOCODING_ENDPOINT := (
	"https://geocoding-api.open-meteo.com/v1/search"
)
const DEFAULT_FORECAST_ENDPOINT := (
	"https://api.open-meteo.com/v1/forecast"
)
const REQUEST_TIMEOUT_SECONDS := 15.0

var state := State.IDLE
var status_message := ""
var last_weather: Dictionary = {}
var geocoding_endpoint := DEFAULT_GEOCODING_ENDPOINT
var forecast_endpoint := DEFAULT_FORECAST_ENDPOINT

var _request: HTTPRequest
var _request_mode := ""
var _pending_city := ""
var _pending_language := "en"
var _resolved_location: Dictionary = {}


func _ready() -> void:
	_request = HTTPRequest.new()
	_request.timeout = REQUEST_TIMEOUT_SECONDS
	_request.request_completed.connect(_handle_request_completed)
	add_child(_request)


func fetch_weather(city: String, language := "en") -> bool:
	var safe_city := city.strip_edges()
	if safe_city.length() < 2:
		_set_state(State.ERROR, "city_required")
		return false
	if _request == null:
		_set_state(State.ERROR, "request_unavailable")
		return false
	if (
		state == State.RESOLVING_CITY
		or state == State.FETCHING_WEATHER
	):
		_request.cancel_request()
	_pending_city = safe_city
	_pending_language = _api_language(language)
	_resolved_location.clear()
	_request_mode = "geocoding"
	var url := "%s?name=%s&count=1&language=%s&format=json" % [
		geocoding_endpoint,
		safe_city.uri_encode(),
		_pending_language.uri_encode(),
	]
	var result := _request.request(
		url,
		PackedStringArray(["Accept: application/json"])
	)
	if result != OK:
		_set_state(State.ERROR, "request_failed")
		return false
	_set_state(State.RESOLVING_CITY, "")
	return true


func clear() -> void:
	if (
		_request != null
		and (
			state == State.RESOLVING_CITY
			or state == State.FETCHING_WEATHER
		)
	):
		_request.cancel_request()
	_request_mode = ""
	_pending_city = ""
	_resolved_location.clear()
	last_weather.clear()
	_set_state(State.IDLE, "")


func restore_cached_weather(weather: Dictionary) -> bool:
	if (
		str(
			weather.get(
				"display_name",
				weather.get("name", "")
			)
		).strip_edges().is_empty()
		or not weather.has("temperature_c")
		or not weather.has("temperature_max_c")
		or not weather.has("temperature_min_c")
		or not weather.has("weather_code")
	):
		return false
	last_weather = weather.duplicate(true)
	_set_state(State.READY, "cached")
	return true


func _handle_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_state(State.ERROR, "network_error")
		return
	if response_code != 200:
		_set_state(State.ERROR, "service_error")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_set_state(State.ERROR, "invalid_response")
		return
	if _request_mode == "geocoding":
		_handle_geocoding_response(parsed)
	elif _request_mode == "forecast":
		_handle_forecast_response(parsed)
	else:
		_set_state(State.ERROR, "invalid_response")


func _handle_geocoding_response(response: Dictionary) -> void:
	var location := parse_geocoding_response(response)
	if location.is_empty():
		_set_state(State.ERROR, "city_not_found")
		return
	_resolved_location = location
	_request_mode = "forecast"
	var url := (
		"%s?latitude=%s&longitude=%s"
		+ "&current=temperature_2m,weather_code"
		+ "&daily=temperature_2m_max,temperature_2m_min"
		+ "&temperature_unit=celsius&timezone=auto&forecast_days=1"
	) % [
		forecast_endpoint,
		str(location.get("latitude", 0.0)).uri_encode(),
		str(location.get("longitude", 0.0)).uri_encode(),
	]
	var result := _request.request(
		url,
		PackedStringArray(["Accept: application/json"])
	)
	if result != OK:
		_set_state(State.ERROR, "request_failed")
		return
	_set_state(State.FETCHING_WEATHER, "")


func _handle_forecast_response(response: Dictionary) -> void:
	var weather := parse_forecast_response(
		response,
		_resolved_location
	)
	if weather.is_empty():
		_set_state(State.ERROR, "invalid_response")
		return
	weather["requested_city"] = _pending_city
	weather["language"] = _pending_language
	weather["fetched_unix"] = Time.get_unix_time_from_system()
	last_weather = weather.duplicate(true)
	_request_mode = ""
	_set_state(State.READY, "")
	weather_updated.emit(last_weather.duplicate(true))


static func parse_geocoding_response(
	response: Dictionary
) -> Dictionary:
	var results = response.get("results", [])
	if not results is Array or results.is_empty():
		return {}
	var first = results[0]
	if not first is Dictionary:
		return {}
	var name := str(first.get("name", "")).strip_edges()
	var latitude := float(first.get("latitude", NAN))
	var longitude := float(first.get("longitude", NAN))
	if name.is_empty() or is_nan(latitude) or is_nan(longitude):
		return {}
	var country := str(first.get("country", "")).strip_edges()
	var admin1 := str(first.get("admin1", "")).strip_edges()
	var display_name := name
	if not admin1.is_empty() and admin1 != name:
		display_name += ", %s" % admin1
	if not country.is_empty() and country != admin1:
		display_name += ", %s" % country
	return {
		"id": int(first.get("id", 0)),
		"name": name,
		"display_name": display_name,
		"country": country,
		"country_code": str(first.get("country_code", "")),
		"latitude": latitude,
		"longitude": longitude,
		"timezone": str(first.get("timezone", "")),
	}


static func parse_forecast_response(
	response: Dictionary,
	location: Dictionary
) -> Dictionary:
	var current = response.get("current", {})
	var daily = response.get("daily", {})
	if not current is Dictionary or not daily is Dictionary:
		return {}
	var maximums = daily.get("temperature_2m_max", [])
	var minimums = daily.get("temperature_2m_min", [])
	if (
		not maximums is Array
		or not minimums is Array
		or maximums.is_empty()
		or minimums.is_empty()
	):
		return {}
	if (
		not current.has("temperature_2m")
		or not current.has("weather_code")
	):
		return {}
	var weather := location.duplicate(true)
	weather["temperature_c"] = float(
		current.get("temperature_2m", 0.0)
	)
	weather["weather_code"] = int(current.get("weather_code", -1))
	weather["temperature_max_c"] = float(maximums[0])
	weather["temperature_min_c"] = float(minimums[0])
	weather["observed_at"] = str(current.get("time", ""))
	return weather


func _set_state(next_state: int, message: String) -> void:
	state = next_state
	status_message = message
	state_changed.emit(state, status_message)


func _api_language(language: String) -> String:
	return "zh" if language.begins_with("zh") else "en"
