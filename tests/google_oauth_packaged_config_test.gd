extends SceneTree

const GoogleOAuthClientConfigScript := preload(
	"res://src/checkins/google_oauth_client_config.gd"
)


func _initialize() -> void:
	var credentials := GoogleOAuthClientConfigScript.load_credentials(
		GoogleOAuthClientConfigScript.RELEASE_CONFIG_PATH
	)
	if credentials.is_empty():
		push_error("Packaged Google OAuth configuration self-test failed.")
		quit(1)
		return
	print("Packaged Google OAuth configuration self-test passed.")
	quit(0)
