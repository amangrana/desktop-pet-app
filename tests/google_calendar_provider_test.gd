extends SceneTree

const GoogleCalendarProviderScript := preload(
	"res://src/checkins/google_calendar_provider.gd"
)

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var provider = GoogleCalendarProviderScript.new()
	root.add_child(provider)
	provider.configure("desktop-client-id")
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
