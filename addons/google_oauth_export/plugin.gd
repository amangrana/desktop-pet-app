@tool
extends EditorPlugin

const OAuthExportPluginScript := preload(
	"res://addons/google_oauth_export/oauth_export_plugin.gd"
)

var oauth_export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	oauth_export_plugin = OAuthExportPluginScript.new()
	add_export_plugin(oauth_export_plugin)


func _exit_tree() -> void:
	if oauth_export_plugin == null:
		return
	remove_export_plugin(oauth_export_plugin)
	oauth_export_plugin = null
