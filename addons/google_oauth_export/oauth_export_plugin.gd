@tool
extends EditorExportPlugin

const GoogleOAuthClientConfigScript := preload(
	"res://src/checkins/google_oauth_client_config.gd"
)
const LOCAL_CREDENTIAL_PREFIX := "client_secret"


func _get_name() -> String:
	return "DesktopPetGoogleOAuthExport"


func _export_begin(
	features: PackedStringArray,
	_is_debug: bool,
	_path: String,
	_flags: int
) -> void:
	if not features.has("windows"):
		return
	var credentials := _load_export_credentials()
	if credentials.is_empty():
		push_error(
			(
				"Google OAuth export configuration is missing. "
				+ "Set %s and %s, or keep an ignored "
				+ "client_secret*.json in the project root."
			) % [
				GoogleOAuthClientConfigScript.CLIENT_ID_ENV,
				GoogleOAuthClientConfigScript.CLIENT_SECRET_ENV,
			]
		)
		return
	add_file(
		GoogleOAuthClientConfigScript.RELEASE_CONFIG_PATH,
		JSON.stringify(credentials).to_utf8_buffer(),
		false
	)


func _load_export_credentials() -> Dictionary:
	var environment_client_id := OS.get_environment(
		GoogleOAuthClientConfigScript.CLIENT_ID_ENV
	)
	var environment_client_secret := OS.get_environment(
		GoogleOAuthClientConfigScript.CLIENT_SECRET_ENV
	)
	var environment_credentials := (
		GoogleOAuthClientConfigScript.credentials_from_environment()
	)
	if not environment_credentials.is_empty():
		return environment_credentials
	if (
		not environment_client_id.is_empty()
		or not environment_client_secret.is_empty()
	):
		return {}
	var project_directory := DirAccess.open("res://")
	if project_directory == null:
		return {}
	var filenames := project_directory.get_files()
	filenames.sort()
	for filename in filenames:
		if (
			filename.begins_with(LOCAL_CREDENTIAL_PREFIX)
			and filename.ends_with(".json")
		):
			var credentials := (
				GoogleOAuthClientConfigScript.load_credentials(
					"res://%s" % filename
				)
			)
			if not credentials.is_empty():
				return credentials
	return {}
