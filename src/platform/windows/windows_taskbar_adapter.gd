class_name WindowsTaskbarAdapter
extends RefCounted

const HELPER_RESOURCE_PATH := (
	"res://platform/windows/taskbar_helper/DesktopPetTaskbarHelper.exe"
)


func hide_button(window_id := DisplayServer.MAIN_WINDOW_ID) -> bool:
	if OS.get_name() != "Windows":
		return true
	if DisplayServer.get_name() == "headless":
		return false

	var helper_path := _resolve_helper_path()
	if not FileAccess.file_exists(helper_path):
		push_warning("Windows taskbar helper is missing.")
		return false

	var native_handle := DisplayServer.window_get_native_handle(
		DisplayServer.WINDOW_HANDLE,
		window_id
	)
	if native_handle == 0:
		push_warning("Could not obtain the native pet window handle.")
		return false

	var exit_code := OS.execute(
		helper_path,
		PackedStringArray([
			"--delete-tab",
			str(native_handle),
		]),
		[],
		false,
		false
	)
	if exit_code != 0:
		push_warning(
			"Could not remove the pet taskbar button "
			+ "(helper exit code %d)." % exit_code
		)
		return false
	return true


func helper_exists() -> bool:
	return FileAccess.file_exists(_resolve_helper_path())


func _resolve_helper_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path(HELPER_RESOURCE_PATH)
	return OS.get_executable_path().get_base_dir().path_join(
		"DesktopPetTaskbarHelper.exe"
	)
