extends SceneTree

const OpenMeteoWeatherProviderScript := preload(
	"res://src/checkins/open_meteo_weather_provider.gd"
)
const WeatherCheckInSourceScript := preload(
	"res://src/checkins/weather_check_in_source.gd"
)

var _fake_now := 50_000.0
var _weather_cards: Array[Dictionary] = []
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var provider = OpenMeteoWeatherProviderScript.new()
	root.add_child(provider)

	var location := provider.parse_geocoding_response({
		"results": [{
			"id": 6167865,
			"name": "Toronto",
			"latitude": 43.70011,
			"longitude": -79.4163,
			"country": "Canada",
			"country_code": "CA",
			"admin1": "Ontario",
			"timezone": "America/Toronto",
		}],
	})
	_expect(
		location.get("display_name", "")
		== "Toronto, Ontario, Canada"
		and is_equal_approx(
			float(location.get("latitude", 0.0)),
			43.70011
		)
		and provider.parse_geocoding_response({}).is_empty(),
		"geocoding responses must normalize one valid city safely"
	)

	var weather := provider.parse_forecast_response(
		{
			"current": {
				"time": "2026-07-31T14:00",
				"temperature_2m": 18.4,
				"weather_code": 2,
			},
			"daily": {
				"temperature_2m_max": [23.1],
				"temperature_2m_min": [14.2],
			},
		},
		location
	)
	_expect(
		not weather.is_empty()
		and int(weather.get("weather_code", -1)) == 2
		and is_equal_approx(
			float(weather.get("temperature_max_c", 0.0)),
			23.1
		)
		and provider.parse_forecast_response(
			{"current": {}, "daily": {}},
			location
		).is_empty(),
		"forecast responses must require current and daily temperatures"
	)

	var source = WeatherCheckInSourceScript.new()
	source.time_source = func() -> float: return _fake_now
	source.card_ready.connect(_weather_cards.append)
	root.add_child(source)
	weather["fetched_unix"] = _fake_now
	_expect(
		source.publish_weather(weather),
		"a fresh forecast must publish a standard weather card"
	)
	_expect(
		not source.publish_weather(weather)
		and source.publish_weather(weather, true),
		(
			"automatic weather cards must deduplicate within a six-hour "
			+ "bucket while explicit previews remain repeatable"
		)
	)
	var direct_preview := source.create_weather_card(weather)
	_expect(
		not direct_preview.is_empty()
		and direct_preview.get("source", "") == "weather"
		and _weather_cards.size() == 2,
		(
			"manual weather must be able to create a standard preview "
			+ "card without publishing it into the automatic queue"
		)
	)
	var card: Dictionary = _weather_cards[0]
	var messages = card.get("localized_messages", {})
	var metadata = card.get("metadata", {})
	_expect(
		card.get("source", "") == "weather"
		and int(card.get("priority", 0)) == -10
		and float(card.get("expires_unix", 0.0))
		== _fake_now + WeatherCheckInSourceScript.CARD_LIFETIME_SECONDS
		and card.get("action_url", "")
		== WeatherCheckInSourceScript.ATTRIBUTION_URL
		and messages is Dictionary
		and "partly cloudy" in str(messages.get("en", ""))
		and "多云" in str(messages.get("zh_CN", ""))
		and "Open-Meteo" in str(messages.get("en", ""))
		and metadata is Dictionary
		and metadata.get("provider", "") == "open_meteo"
		and not metadata.has("latitude")
		and not metadata.has("longitude"),
		(
			"weather cards must be bilingual, attributed, expiring, "
			+ "low priority, and free of precise-location side effects"
		)
	)
	var no_provider_id := weather.duplicate(true)
	no_provider_id["id"] = 0
	_fake_now += WeatherCheckInSourceScript.CARD_INTERVAL_SECONDS
	_expect(
		source.publish_weather(no_provider_id)
		and "," not in str(
			_weather_cards.back()
			.get("metadata", {})
			.get("location_id", "")
		),
		(
			"weather cards without a provider location ID must use an "
			+ "opaque city key instead of derived coordinates"
		)
	)

	_expect(
		not provider.fetch_weather("x"),
		"city validation must fail before any network request"
	)
	_expect(
		provider.state == OpenMeteoWeatherProviderScript.State.ERROR
		and provider.status_message == "city_required",
		"short city names must return a stable safe error code"
	)
	provider.last_weather = weather.duplicate(true)
	provider._handle_request_completed(
		HTTPRequest.RESULT_CANT_CONNECT,
		0,
		PackedStringArray(),
		PackedByteArray()
	)
	_expect(
		provider.status_message == "network_error"
		and not provider.last_weather.is_empty(),
		"network failures must preserve the last successful weather cache"
	)
	var cache_provider = OpenMeteoWeatherProviderScript.new()
	root.add_child(cache_provider)
	var cache := weather.duplicate(true)
	cache.erase("latitude")
	cache.erase("longitude")
	_expect(
		cache_provider.restore_cached_weather(cache)
		and cache_provider.state
		== OpenMeteoWeatherProviderScript.State.READY
		and cache_provider.last_weather.get("display_name", "")
		== "Toronto, Ontario, Canada",
		(
			"a sanitized last result must restore without stored "
			+ "coordinates or a network request"
		)
	)

	if _failed:
		quit(1)
		return
	print("Weather provider self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Weather provider self-test failed: %s" % message)
