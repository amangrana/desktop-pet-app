extends SceneTree

const GoogleCalendarProviderScript := preload(
	"res://src/checkins/google_calendar_provider.gd"
)
const GoogleOAuthClientConfigScript := preload(
	"res://src/checkins/google_oauth_client_config.gd"
)

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var normalized_credentials: Dictionary = (
		GoogleOAuthClientConfigScript.normalize_credentials(
			{
				"installed": {
					"client_id": (
						GoogleOAuthClientConfigScript.DEFAULT_CLIENT_ID
					),
					"client_secret": "release-client-value",
				},
			}
		)
	)
	_expect(
		not normalized_credentials.is_empty()
		and str(
			normalized_credentials.installed.client_secret
		) == "release-client-value",
		"release credentials must validate for the built-in Desktop client"
	)
	_expect(
		GoogleOAuthClientConfigScript.normalize_credentials(
			{
				"installed": {
					"client_id": "different-client-id",
					"client_secret": "release-client-value",
				},
			}
		).is_empty()
		and GoogleOAuthClientConfigScript.normalize_credentials(
			{
				"installed": {
					"client_id": (
						GoogleOAuthClientConfigScript.DEFAULT_CLIENT_ID
					),
					"client_secret": "",
				},
			}
		).is_empty(),
		"release credentials must reject mismatched IDs and empty secrets"
	)
	var previous_environment_client_id := OS.get_environment(
		GoogleOAuthClientConfigScript.CLIENT_ID_ENV
	)
	var previous_environment_client_secret := OS.get_environment(
		GoogleOAuthClientConfigScript.CLIENT_SECRET_ENV
	)
	OS.set_environment(
		GoogleOAuthClientConfigScript.CLIENT_ID_ENV,
		GoogleOAuthClientConfigScript.DEFAULT_CLIENT_ID
	)
	OS.set_environment(
		GoogleOAuthClientConfigScript.CLIENT_SECRET_ENV,
		"export-plugin-test-value"
	)
	_expect(
		not GoogleOAuthClientConfigScript.credentials_from_environment(
		).is_empty(),
		"release credentials must load from process-local CI values"
	)
	OS.set_environment(
		GoogleOAuthClientConfigScript.CLIENT_ID_ENV,
		"different-client-id"
	)
	_expect(
		GoogleOAuthClientConfigScript.credentials_from_environment(
		).is_empty(),
		"release credentials must reject an unexpected CI client ID"
	)
	_restore_environment(
		GoogleOAuthClientConfigScript.CLIENT_ID_ENV,
		previous_environment_client_id
	)
	_restore_environment(
		GoogleOAuthClientConfigScript.CLIENT_SECRET_ENV,
		previous_environment_client_secret
	)

	var provider = GoogleCalendarProviderScript.new()
	root.add_child(provider)
	provider.configure("desktop-client-id")
	var timeout_provider = GoogleCalendarProviderScript.new()
	root.add_child(timeout_provider)
	timeout_provider._callback_server = TCPServer.new()
	timeout_provider._authorization_deadline_ticks_msec = (
		Time.get_ticks_msec() - 1
	)
	timeout_provider._process(0.0)
	_expect(
		timeout_provider.state
		== GoogleCalendarProviderScript.State.ERROR
		and timeout_provider.status_message == "authorization_timeout"
		and timeout_provider._callback_server == null
		and timeout_provider._authorization_deadline_ticks_msec == 0,
		(
			"an abandoned browser authorization must time out and release "
			+ "the loopback callback server"
		)
	)
	_expect(
		provider._apply_client_credentials({
			"installed": {
				"client_id": "desktop-client-id",
				"client_secret": "local-development-secret",
			},
		})
		and provider.has_client_secret(),
		"Desktop OAuth credentials must load without exposing the secret"
	)
	var public_client = GoogleCalendarProviderScript.new()
	root.add_child(public_client)
	public_client.configure("built-in-client-id")
	_expect(
		public_client._apply_client_credentials(
			{
				"installed": {
					"client_id": "development-client-id",
				},
			},
			true
		)
		and public_client.client_id == "development-client-id"
		and not public_client.has_client_secret(),
		"Development credentials may override the built-in public client"
	)
	var public_token_fields := {
		"client_id": public_client.client_id,
		"code": "authorization-code",
	}
	public_client._add_optional_client_secret(public_token_fields)
	_expect(
		not public_token_fields.has("client_secret"),
		"Public PKCE token requests must omit an empty client secret"
	)
	var confidential_token_fields := {
		"client_id": provider.client_id,
		"code": "authorization-code",
	}
	provider._add_optional_client_secret(confidential_token_fields)
	_expect(
		confidential_token_fields.get("client_secret", "")
		== "local-development-secret",
		"Development overrides must still attach a configured client secret"
	)
	var required_client = GoogleCalendarProviderScript.new()
	root.add_child(required_client)
	required_client.configure("desktop-client-id", "", true)
	_expect(
		not required_client.connect_account()
		and required_client.state
		== GoogleCalendarProviderScript.State.ERROR
		and required_client.status_message == "missing_client_secret",
		(
			"a build missing its required Desktop client value must fail "
			+ "before opening the browser"
		)
	)

	var query: Dictionary = provider._parse_query(
		"code=a%2Fb&state=test-state"
	)
	_expect(
		query.get("code", "") == "a/b"
		and query.get("state", "") == "test-state",
		"OAuth callback query must decode safely"
	)
	var verifier: String = provider._random_base64_url(64)
	_expect(
		not verifier.is_empty()
		and not "=" in verifier
		and not "+" in verifier
		and not "/" in verifier,
		"PKCE verifier must use unpadded base64url encoding"
	)
	_expect(
		provider._sha256_base64_url(
			"dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
		) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
		"PKCE challenge must match the RFC 7636 S256 test vector"
	)
	_expect(
		provider._google_error_code(
			'{"error":"invalid_grant","error_description":"Bad Request"}'
			.to_utf8_buffer(),
			"fallback"
		) == "invalid_grant",
		"token errors must retain Google's safe error code"
	)
	_expect(
		provider._google_error_code(
			(
				'{"error":"invalid_request","error_description":'
				+ '"client_secret is missing."}'
			).to_utf8_buffer(),
			"fallback"
		) == "client_secret_missing",
		"missing Desktop OAuth client secret must be diagnosed clearly"
	)
	_expect(
		provider._google_error_code(
			(
				'{"error":{"status":"PERMISSION_DENIED","details":'
				+ '[{"reason":"SERVICE_DISABLED"}]}}'
			).to_utf8_buffer(),
			"fallback"
		) == "service_disabled",
		"Calendar API errors must expose their structured reason"
	)
	var invalidation_count := [0]
	provider.refresh_token_invalidated.connect(
		func() -> void: invalidation_count[0] += 1
	)
	provider._request_mode = "refresh_token"
	provider._refresh_token = "temporary-test-token"
	provider._handle_token_response(
		HTTPRequest.RESULT_SUCCESS,
		400,
		PackedStringArray(),
		(
			'{"error":"invalid_grant","error_description":"revoked"}'
		).to_utf8_buffer()
	)
	_expect(
		provider._refresh_token.is_empty()
		and invalidation_count[0] == 1,
		"revoked saved logins must clear the refresh token"
	)
	_expect(
		provider._rfc3339_to_unix("2026-07-19T12:00:00Z")
		== provider._rfc3339_to_unix("2026-07-19T08:00:00-04:00"),
		"RFC3339 timestamps must normalize timezone offsets"
	)

	var timed_event: Dictionary = provider._standardize_event(
		{"id": "primary"},
		{
			"id": "timed-1",
			"status": "confirmed",
			"summary": "Design review",
			"start": {"dateTime": "2026-07-19T12:00:00Z"},
			"end": {"dateTime": "2026-07-19T13:00:00Z"},
		}
	)
	_expect(
		not timed_event.is_empty()
		and not bool(timed_event.is_all_day)
		and float(timed_event.start_unix) > 0.0,
		"timed Google event must standardize for the calendar source"
	)
	var all_day_event: Dictionary = provider._standardize_event(
		{"id": "primary"},
		{
			"id": "day-1",
			"status": "confirmed",
			"summary": "Holiday",
			"start": {"date": "2026-07-19"},
			"end": {"date": "2026-07-20"},
		}
	)
	_expect(
		bool(all_day_event.is_all_day)
		and float(all_day_event.end_unix)
		> float(all_day_event.start_unix),
		"all-day Google event must preserve its exclusive end date"
	)

	if _failed:
		quit(1)
		return
	print("Google Calendar provider self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Google Calendar provider self-test failed: %s" % message)


func _restore_environment(name: String, value: String) -> void:
	if value.is_empty():
		OS.unset_environment(name)
		return
	OS.set_environment(name, value)
