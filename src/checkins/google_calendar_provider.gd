class_name GoogleCalendarProvider
extends Node

signal state_changed(state: int, message: String)
signal events_updated(events: Array[Dictionary])
signal refresh_token_received(refresh_token: String)
signal refresh_token_invalidated

enum State {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	SYNCING,
	ERROR,
}

const AUTHORIZATION_ENDPOINT := "https://accounts.google.com/o/oauth2/v2/auth"
const TOKEN_ENDPOINT := "https://oauth2.googleapis.com/token"
const CALENDAR_LIST_ENDPOINT := (
	"https://www.googleapis.com/calendar/v3/users/me/calendarList"
)
const CALENDAR_API_ROOT := "https://www.googleapis.com/calendar/v3"
const SCOPES := [
	"https://www.googleapis.com/auth/calendar.calendarlist.readonly",
	"https://www.googleapis.com/auth/calendar.events.readonly",
]
const CALLBACK_PORT_MIN := 49152
const CALLBACK_PORT_MAX := 65535
const AUTO_SYNC_SECONDS := 15 * 60

var client_id := ""
var state := State.DISCONNECTED
var status_message := ""
var account_label := ""

var _client_secret := ""
var _callback_server: TCPServer
var _callback_peer: StreamPeerTCP
var _callback_request_buffer := ""
var _redirect_uri := ""
var _oauth_state := ""
var _code_verifier := ""
var _access_token := ""
var _refresh_token := ""
var _access_token_expires_unix := 0.0
var _request_mode := ""
var _calendar_queue: Array[Dictionary] = []
var _synced_events: Array[Dictionary] = []
var _active_calendar: Dictionary = {}
var _token_request: HTTPRequest
var _api_request: HTTPRequest
var _sync_timer: Timer


func _ready() -> void:
	_token_request = HTTPRequest.new()
	_token_request.request_completed.connect(_handle_token_response)
	add_child(_token_request)

	_api_request = HTTPRequest.new()
	_api_request.request_completed.connect(_handle_api_response)
	add_child(_api_request)

	_sync_timer = Timer.new()
	_sync_timer.wait_time = AUTO_SYNC_SECONDS
	_sync_timer.one_shot = false
	_sync_timer.timeout.connect(sync_events)
	add_child(_sync_timer)
	set_process(true)


func configure(
	oauth_client_id: String,
	oauth_client_secret: String = ""
) -> void:
	client_id = oauth_client_id.strip_edges()
	_client_secret = oauth_client_secret.strip_edges()


func load_client_credentials(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return false
	return _apply_client_credentials(parsed, true)


func has_client_secret() -> bool:
	return not _client_secret.is_empty()


func connect_account() -> bool:
	if client_id.is_empty():
		_set_state(State.ERROR, "missing_client_id")
		return false
	_stop_callback_server()
	_callback_server = TCPServer.new()
	var callback_port := _listen_on_available_port()
	if callback_port <= 0:
		_set_state(State.ERROR, "callback_port_unavailable")
		return false

	_redirect_uri = "http://127.0.0.1:%d" % callback_port
	_code_verifier = _random_base64_url(64)
	_oauth_state = _random_base64_url(32)
	var code_challenge := _sha256_base64_url(_code_verifier)
	var authorization_url := "%s?%s" % [
		AUTHORIZATION_ENDPOINT,
		_form_encode({
			"client_id": client_id,
			"redirect_uri": _redirect_uri,
			"response_type": "code",
			"scope": " ".join(SCOPES),
			"code_challenge": code_challenge,
			"code_challenge_method": "S256",
			"state": _oauth_state,
			"access_type": "offline",
			"prompt": "consent",
		}),
	]
	var open_result := OS.shell_open(authorization_url)
	if open_result != OK:
		_stop_callback_server()
		_set_state(State.ERROR, "browser_open_failed")
		return false
	_set_state(State.CONNECTING, "waiting_for_authorization")
	return true


func disconnect_account() -> void:
	_stop_callback_server()
	if _token_request != null:
		_token_request.cancel_request()
	if _api_request != null:
		_api_request.cancel_request()
	_access_token = ""
	_refresh_token = ""
	_access_token_expires_unix = 0.0
	account_label = ""
	_calendar_queue.clear()
	_synced_events.clear()
	if _sync_timer != null:
		_sync_timer.stop()
	_set_state(State.DISCONNECTED, "")


func sync_events() -> bool:
	if state == State.CONNECTING or state == State.SYNCING:
		return false
	if _access_token.is_empty():
		if _refresh_token.is_empty():
			_set_state(State.DISCONNECTED, "authorization_required")
			return false
		return _refresh_access_token()
	if Time.get_unix_time_from_system() >= _access_token_expires_unix - 60.0:
		return _refresh_access_token()
	_request_calendar_list()
	return true


func has_account_connection() -> bool:
	return not _access_token.is_empty() or not _refresh_token.is_empty()


func restore_refresh_token(refresh_token: String) -> bool:
	if (
		refresh_token.is_empty()
		or state == State.CONNECTING
		or state == State.SYNCING
	):
		return false
	_access_token = ""
	_access_token_expires_unix = 0.0
	_refresh_token = refresh_token
	return _refresh_access_token()


func _process(_delta: float) -> void:
	if _callback_server == null:
		return
	if _callback_peer == null and _callback_server.is_connection_available():
		_callback_peer = _callback_server.take_connection()
	if _callback_peer == null or _callback_peer.get_available_bytes() <= 0:
		return
	_callback_request_buffer += _callback_peer.get_utf8_string(
		_callback_peer.get_available_bytes()
	)
	if not "\r\n\r\n" in _callback_request_buffer:
		return
	_handle_oauth_callback(_callback_request_buffer)


func _listen_on_available_port() -> int:
	for _attempt in 32:
		var port := randi_range(CALLBACK_PORT_MIN, CALLBACK_PORT_MAX)
		if _callback_server.listen(port, "127.0.0.1") == OK:
			return port
	return 0


func _handle_oauth_callback(request_text: String) -> void:
	var request_line := request_text.get_slice("\r\n", 0)
	var request_parts := request_line.split(" ")
	if request_parts.size() < 2:
		_respond_to_browser(false)
		_stop_callback_server()
		_set_state(State.ERROR, "invalid_callback")
		return
	var callback_path := str(request_parts[1])
	var query_index := callback_path.find("?")
	var query := (
		callback_path.substr(query_index + 1)
		if query_index >= 0
		else ""
	)
	var parameters := _parse_query(query)
	var callback_state := str(parameters.get("state", ""))
	var authorization_code := str(parameters.get("code", ""))
	var error_code := str(parameters.get("error", ""))
	var valid := (
		error_code.is_empty()
		and not authorization_code.is_empty()
		and callback_state == _oauth_state
	)
	_respond_to_browser(valid)
	_stop_callback_server()
	if not valid:
		_set_state(
			State.ERROR,
			error_code if not error_code.is_empty() else "invalid_oauth_state"
		)
		return
	_exchange_authorization_code(authorization_code)


func _respond_to_browser(success: bool) -> void:
	if _callback_peer == null:
		return
	var heading := (
		"Authorization received / 已收到授权"
		if success
		else "Connection failed / 连接失败"
	)
	var detail := (
		"You can close this tab and return to Desktop Pet. "
		+ "你可以关闭此页面并返回桌面宠物。"
		if success
		else "Return to Desktop Pet and try again. "
		+ "请返回桌面宠物并重试。"
	)
	var html := (
		"<!doctype html><meta charset=\"utf-8\">"
		+ "<title>%s</title><body style=\"font-family:sans-serif;"
		% heading
		+ "max-width:520px;margin:64px auto;padding:24px\">"
		+ "<h1>%s</h1><p>%s</p></body>" % [heading, detail]
	)
	var response := (
		"HTTP/1.1 200 OK\r\n"
		+ "Content-Type: text/html; charset=utf-8\r\n"
		+ "Content-Length: %d\r\n"
		% html.to_utf8_buffer().size()
		+ "Connection: close\r\n\r\n"
		+ html
	)
	_callback_peer.put_data(response.to_utf8_buffer())
	_callback_peer.disconnect_from_host()


func _exchange_authorization_code(code: String) -> void:
	_request_mode = "authorization_code"
	var fields := {
		"client_id": client_id,
		"code": code,
		"code_verifier": _code_verifier,
		"grant_type": "authorization_code",
		"redirect_uri": _redirect_uri,
	}
	_add_optional_client_secret(fields)
	var body := _form_encode(fields)
	var result := _token_request.request(
		TOKEN_ENDPOINT,
		PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]),
		HTTPClient.METHOD_POST,
		body
	)
	if result != OK:
		_set_state(State.ERROR, "token_request_failed")


func _refresh_access_token() -> bool:
	if _refresh_token.is_empty():
		return false
	_request_mode = "refresh_token"
	var fields := {
		"client_id": client_id,
		"refresh_token": _refresh_token,
		"grant_type": "refresh_token",
	}
	_add_optional_client_secret(fields)
	var body := _form_encode(fields)
	var result := _token_request.request(
		TOKEN_ENDPOINT,
		PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]),
		HTTPClient.METHOD_POST,
		body
	)
	if result != OK:
		_set_state(State.ERROR, "token_refresh_failed")
		return false
	_set_state(State.CONNECTING, "refreshing_access")
	return true


func _handle_token_response(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_state(State.ERROR, "token_network_error")
		return
	if response_code != 200:
		var error_code := _google_error_code(
			body,
			"token_exchange_failed"
		)
		if _request_mode == "refresh_token" and error_code == "invalid_grant":
			_refresh_token = ""
			refresh_token_invalidated.emit()
		_set_state(State.ERROR, error_code)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_set_state(State.ERROR, "invalid_token_response")
		return
	_access_token = str(parsed.get("access_token", ""))
	var received_refresh_token := str(parsed.get("refresh_token", ""))
	_access_token_expires_unix = (
		Time.get_unix_time_from_system()
		+ float(parsed.get("expires_in", 3600))
	)
	if _access_token.is_empty():
		_set_state(State.ERROR, "missing_access_token")
		return
	if not received_refresh_token.is_empty():
		_refresh_token = received_refresh_token
		refresh_token_received.emit(_refresh_token)
	_set_state(State.CONNECTED, "")
	_request_calendar_list()


func _request_calendar_list() -> void:
	_request_mode = "calendar_list"
	_calendar_queue.clear()
	_synced_events.clear()
	account_label = ""
	_set_state(State.SYNCING, "loading_calendars")
	_request_api(
		"%s?showHidden=false&minAccessRole=reader" % CALENDAR_LIST_ENDPOINT
	)


func _request_next_calendar_events() -> void:
	if _calendar_queue.is_empty():
		_set_state(State.CONNECTED, "")
		_sync_timer.start()
		events_updated.emit(_synced_events.duplicate(true))
		return
	_active_calendar = _calendar_queue.pop_front()
	_request_mode = "events"
	var now := Time.get_unix_time_from_system()
	var time_min := (
		Time.get_datetime_string_from_unix_time(int(now)) + "Z"
	)
	var time_max := (
		Time.get_datetime_string_from_unix_time(
			int(now + 3 * 24 * 60 * 60)
		) + "Z"
	)
	var calendar_id := str(_active_calendar.get("id", "")).uri_encode()
	var url := "%s/calendars/%s/events?%s" % [
		CALENDAR_API_ROOT,
		calendar_id,
		_form_encode({
			"singleEvents": "true",
			"orderBy": "startTime",
			"showDeleted": "false",
			"maxResults": "2500",
			"timeZone": "UTC",
			"timeMin": time_min,
			"timeMax": time_max,
		}),
	]
	_request_api(url)


func _request_api(url: String) -> void:
	var result := _api_request.request(
		url,
		PackedStringArray([
			"Authorization: Bearer %s" % _access_token,
			"Accept: application/json",
		])
	)
	if result != OK:
		_set_state(State.ERROR, "calendar_request_failed")


func _handle_api_response(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_state(State.ERROR, "calendar_network_error")
		return
	if response_code != 200:
		if response_code == 401 and not _refresh_token.is_empty():
			_access_token = ""
			_refresh_access_token()
			return
		_set_state(
			State.ERROR,
			_google_error_code(body, "calendar_api_failed")
		)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_set_state(State.ERROR, "invalid_calendar_response")
		return
	if _request_mode == "calendar_list":
		_handle_calendar_list(parsed)
	elif _request_mode == "events":
		_handle_calendar_events(parsed)


func _handle_calendar_list(response: Dictionary) -> void:
	var items = response.get("items", [])
	if not items is Array:
		_set_state(State.ERROR, "invalid_calendar_list")
		return
	for item in items:
		if not item is Dictionary:
			continue
		var calendar_id := str(item.get("id", ""))
		if calendar_id.is_empty():
			continue
		var calendar_data := {
			"id": calendar_id,
			"name": str(item.get("summary", calendar_id)),
			"primary": bool(item.get("primary", false)),
		}
		_calendar_queue.append(calendar_data)
		if bool(calendar_data.primary):
			account_label = calendar_id
	_request_next_calendar_events()


func _handle_calendar_events(response: Dictionary) -> void:
	var items = response.get("items", [])
	if items is Array:
		for item in items:
			if item is Dictionary:
				var event_data := _standardize_event(
					_active_calendar,
					item
				)
				if not event_data.is_empty():
					_synced_events.append(event_data)
	_request_next_calendar_events()


func _standardize_event(
	calendar_data: Dictionary,
	event_data: Dictionary
) -> Dictionary:
	if str(event_data.get("status", "")) == "cancelled":
		return {}
	var event_id := str(event_data.get("id", ""))
	var title := str(event_data.get("summary", "")).strip_edges()
	var start = event_data.get("start", {})
	var end = event_data.get("end", {})
	if event_id.is_empty() or title.is_empty():
		return {}
	var standardized := {
		"id": "%s:%s" % [str(calendar_data.get("id", "")), event_id],
		"title": title,
		"is_all_day": false,
	}
	if start is Dictionary and start.has("date"):
		if not end is Dictionary or not end.has("date"):
			return {}
		standardized["is_all_day"] = true
		standardized["start_unix"] = _local_date_to_unix(
			str(start.get("date", ""))
		)
		standardized["end_unix"] = _local_date_to_unix(
			str(end.get("date", ""))
		)
		return standardized
	if not start is Dictionary or not start.has("dateTime"):
		return {}
	standardized["start_unix"] = _rfc3339_to_unix(
		str(start.get("dateTime", ""))
	)
	if end is Dictionary and end.has("dateTime"):
		standardized["end_unix"] = _rfc3339_to_unix(
			str(end.get("dateTime", ""))
		)
	return standardized


func _rfc3339_to_unix(value: String) -> float:
	var source := value.strip_edges()
	if source.is_empty():
		return 0.0
	var timezone_index := -1
	for marker in ["+", "-"]:
		var found := source.find(marker, 11)
		if found >= 0 and (
			timezone_index < 0 or found < timezone_index
		):
			timezone_index = found
	var offset_minutes := 0
	if source.ends_with("Z"):
		source = source.trim_suffix("Z")
	elif timezone_index >= 0:
		var offset_text := source.substr(timezone_index + 1)
		var sign := 1 if source[timezone_index] == "+" else -1
		var offset_parts := offset_text.split(":")
		if offset_parts.size() >= 2:
			offset_minutes = sign * (
				int(offset_parts[0]) * 60 + int(offset_parts[1])
			)
		source = source.substr(0, timezone_index)
	if source.length() > 19:
		source = source.substr(0, 19)
	return (
		float(Time.get_unix_time_from_datetime_string(source))
		- offset_minutes * 60.0
	)


func _local_date_to_unix(date: String) -> float:
	if date.length() != 10:
		return 0.0
	var utc_midnight := float(
		Time.get_unix_time_from_datetime_string("%sT00:00:00" % date)
	)
	var local_bias_minutes := int(
		Time.get_time_zone_from_system().get("bias", 0)
	)
	return utc_midnight - local_bias_minutes * 60.0


func _parse_query(query: String) -> Dictionary:
	var result := {}
	for pair in query.split("&", false):
		var separator := pair.find("=")
		var key := pair
		var value := ""
		if separator >= 0:
			key = pair.substr(0, separator)
			value = pair.substr(separator + 1)
		result[key.uri_decode()] = value.replace("+", " ").uri_decode()
	return result


func _form_encode(values: Dictionary) -> String:
	var fields := PackedStringArray()
	for key in values:
		fields.append(
			"%s=%s" % [
				str(key).uri_encode(),
				str(values[key]).uri_encode(),
			]
		)
	return "&".join(fields)


func _add_optional_client_secret(fields: Dictionary) -> void:
	if not _client_secret.is_empty():
		fields["client_secret"] = _client_secret


func _random_base64_url(byte_count: int) -> String:
	var random_bytes := Crypto.new().generate_random_bytes(byte_count)
	return _base64_url(Marshalls.raw_to_base64(random_bytes))


func _sha256_base64_url(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return _base64_url(Marshalls.raw_to_base64(context.finish()))


func _base64_url(value: String) -> String:
	return (
		value
		.replace("+", "-")
		.replace("/", "_")
		.replace("=", "")
	)


func _apply_client_credentials(
	data: Dictionary,
	allow_client_id_override := false
) -> bool:
	var credentials = data.get("installed", {})
	if not credentials is Dictionary:
		return false
	var loaded_client_id := str(
		credentials.get("client_id", "")
	).strip_edges()
	var loaded_client_secret := str(
		credentials.get("client_secret", "")
	).strip_edges()
	if loaded_client_id.is_empty():
		return false
	if (
		not allow_client_id_override
		and not client_id.is_empty()
		and loaded_client_id != client_id
	):
		return false
	configure(loaded_client_id, loaded_client_secret)
	return true


func _google_error_code(
	body: PackedByteArray,
	fallback: String
) -> String:
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return fallback
	var error = parsed.get("error", "")
	if error is String and not str(error).is_empty():
		var description := str(
			parsed.get("error_description", "")
		).to_lower()
		if (
			str(error).to_lower() == "invalid_request"
			and "client_secret" in description
		):
			return "client_secret_missing"
		return str(error).to_lower()
	if not error is Dictionary:
		return fallback
	var details = error.get("details", [])
	if details is Array:
		for detail in details:
			if not detail is Dictionary:
				continue
			var reason := str(detail.get("reason", ""))
			if not reason.is_empty():
				return reason.to_lower()
			var metadata = detail.get("metadata", {})
			if metadata is Dictionary:
				reason = str(metadata.get("reason", ""))
				if not reason.is_empty():
					return reason.to_lower()
	var status := str(error.get("status", ""))
	if not status.is_empty():
		return status.to_lower()
	return fallback


func _stop_callback_server() -> void:
	if _callback_peer != null:
		_callback_peer.disconnect_from_host()
	_callback_peer = null
	_callback_request_buffer = ""
	if _callback_server != null:
		_callback_server.stop()
	_callback_server = null


func _set_state(next_state: int, message: String) -> void:
	state = next_state
	status_message = message
	state_changed.emit(state, status_message)
