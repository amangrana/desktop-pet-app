class_name GoogleOAuthClientConfig
extends RefCounted

const DEFAULT_CLIENT_ID := (
	"1096439647356-f00etpkkj8g3chtcm7vq6qu75m08j18f"
	+ ".apps.googleusercontent.com"
)
const RELEASE_CONFIG_PATH := (
	"res://.desktop_pet_google_oauth_client.json"
)
const CLIENT_ID_ENV := "DESKTOP_PET_GOOGLE_CLIENT_ID"
const CLIENT_SECRET_ENV := "DESKTOP_PET_GOOGLE_CLIENT_SECRET"


static func normalize_credentials(
	data: Dictionary,
	expected_client_id := DEFAULT_CLIENT_ID,
	require_client_secret := true
) -> Dictionary:
	var installed = data.get("installed", {})
	if not installed is Dictionary:
		return {}
	var client_id := str(installed.get("client_id", "")).strip_edges()
	var client_secret := str(
		installed.get("client_secret", "")
	).strip_edges()
	if (
		client_id.is_empty()
		or (
			not expected_client_id.is_empty()
			and client_id != expected_client_id
		)
		or (require_client_secret and client_secret.is_empty())
	):
		return {}
	var normalized_installed := {
		"client_id": client_id,
		"client_secret": client_secret,
	}
	return {"installed": normalized_installed}


static func credentials_from_values(
	client_id: String,
	client_secret: String,
	expected_client_id := DEFAULT_CLIENT_ID
) -> Dictionary:
	return normalize_credentials(
		{
			"installed": {
				"client_id": client_id,
				"client_secret": client_secret,
			},
		},
		expected_client_id,
		true
	)


static func credentials_from_environment(
	expected_client_id := DEFAULT_CLIENT_ID
) -> Dictionary:
	return credentials_from_values(
		OS.get_environment(CLIENT_ID_ENV),
		OS.get_environment(CLIENT_SECRET_ENV),
		expected_client_id
	)


static func load_credentials(
	path: String,
	expected_client_id := DEFAULT_CLIENT_ID,
	require_client_secret := true
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return {}
	return normalize_credentials(
		parsed,
		expected_client_id,
		require_client_secret
	)
