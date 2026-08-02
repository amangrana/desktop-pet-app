class_name WindowsFullscreenAdapter
extends Node

signal fullscreen_changed(active: bool)
signal state_changed(state: State, message: String)

enum State {
	STOPPED,
	STARTING,
	RUNNING,
	ERROR,
}

const HELPER_RESOURCE_PATH := (
	"res://platform/windows/fullscreen_helper/DesktopPetFullscreenHelper.exe"
)
const PROTOCOL_PREFIX := "DPF1"
const PORT_MIN := 49152
const PORT_MAX := 65535
const PORT_ATTEMPTS := 24
const STARTUP_TIMEOUT_SECONDS := 3.0

var test_reported_state := -1
var state := State.STOPPED
var status_message := "stopped"

var _socket: PacketPeerUDP
var _helper_pid := -1
var _session_token := ""
var _startup_remaining := 0.0
var _received_state := false
var _fullscreen_active := false


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if _socket == null:
		return

	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		if _socket.get_packet_error() != OK:
			continue
		_handle_packet(packet.get_string_from_ascii())

	if state == State.STARTING:
		_startup_remaining -= delta
		if _startup_remaining <= 0.0:
			_fail("fullscreen helper startup timed out")
			return

	if _helper_pid > 0 and not OS.is_process_running(_helper_pid):
		_helper_pid = -1
		if test_reported_state >= 0 and _received_state:
			_close_socket()
			_set_state(State.STOPPED, "test completed")
		else:
			_fail("fullscreen helper stopped unexpectedly")


func start(window_id := DisplayServer.MAIN_WINDOW_ID) -> bool:
	if state == State.STARTING or state == State.RUNNING:
		return true
	if OS.get_name() != "Windows":
		_fail("fullscreen detection is only available on Windows")
		return false
	if DisplayServer.get_name() == "headless" and test_reported_state < 0:
		_fail("fullscreen detection needs a Windows display")
		return false

	_stop_resources(false)
	_socket = PacketPeerUDP.new()
	var port := _bind_local_port()
	if port < 0:
		_fail("could not open a local fullscreen state port")
		return false

	var helper_path := _resolve_helper_path()
	if not FileAccess.file_exists(helper_path):
		_fail("fullscreen helper is missing")
		return false

	_session_token = _create_session_token()
	_received_state = false
	var arguments := PackedStringArray([
		"--port",
		str(port),
		"--token",
		_session_token,
		"--parent-pid",
		str(OS.get_process_id()),
	])
	if test_reported_state >= 0:
		arguments.append("--test-state")
		arguments.append(str(test_reported_state))
	else:
		var native_handle := DisplayServer.window_get_native_handle(
			DisplayServer.WINDOW_HANDLE,
			window_id
		)
		if native_handle == 0:
			_fail("could not obtain the native pet window handle")
			return false
		arguments.append("--pet-window-handle")
		arguments.append(str(native_handle))

	_helper_pid = OS.create_process(helper_path, arguments, false)
	if _helper_pid <= 0:
		_fail("could not start the fullscreen helper")
		return false

	_startup_remaining = STARTUP_TIMEOUT_SECONDS
	set_process(true)
	_set_state(State.STARTING, "starting Windows fullscreen detection")
	return true


func stop() -> void:
	_stop_resources(true)
	_set_state(State.STOPPED, "stopped")


func is_fullscreen_active() -> bool:
	return _fullscreen_active


func helper_exists() -> bool:
	return FileAccess.file_exists(_resolve_helper_path())


func enforce_topmost(window_id := DisplayServer.MAIN_WINDOW_ID) -> bool:
	if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
		return false
	var helper_path := _resolve_helper_path()
	if not FileAccess.file_exists(helper_path):
		return false
	var native_handle := DisplayServer.window_get_native_handle(
		DisplayServer.WINDOW_HANDLE,
		window_id
	)
	if native_handle == 0:
		return false
	return OS.create_process(
		helper_path,
		PackedStringArray([
			"--set-z-order",
			"topmost",
			"--pet-window-handle",
			str(native_handle),
		]),
		false
	) > 0


func _exit_tree() -> void:
	_stop_resources(false)


func _bind_local_port() -> int:
	for attempt in PORT_ATTEMPTS:
		var port := randi_range(PORT_MIN, PORT_MAX)
		if _socket.bind(port, "127.0.0.1") == OK:
			return port
	return -1


func _handle_packet(packet: String) -> void:
	var parts := packet.split("|", false)
	if parts.size() < 3:
		return
	if parts[0] != PROTOCOL_PREFIX or parts[1] != _session_token:
		return

	match parts[2]:
		"READY":
			_set_state(State.RUNNING, "Windows fullscreen detection is active")
		"STATE":
			if parts.size() != 4 or parts[3] not in ["0", "1"]:
				return
			_set_fullscreen_active(parts[3] == "1")
		"ERROR":
			var code := parts[3] if parts.size() >= 4 else "unknown"
			_fail("fullscreen helper error: %s" % code)


func _set_fullscreen_active(active: bool) -> void:
	var should_emit := not _received_state or _fullscreen_active != active
	_received_state = true
	_fullscreen_active = active
	if should_emit:
		fullscreen_changed.emit(_fullscreen_active)


func _resolve_helper_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path(HELPER_RESOURCE_PATH)
	return OS.get_executable_path().get_base_dir().path_join(
		"DesktopPetFullscreenHelper.exe"
	)


func _create_session_token() -> String:
	var random_bytes := Crypto.new().generate_random_bytes(16)
	return random_bytes.hex_encode()


func _stop_resources(emit_inactive: bool) -> void:
	set_process(false)
	if _helper_pid > 0 and OS.is_process_running(_helper_pid):
		OS.kill(_helper_pid)
	_helper_pid = -1
	_close_socket()
	_session_token = ""
	_startup_remaining = 0.0
	_received_state = false
	if emit_inactive:
		_set_fullscreen_active(false)
	else:
		_fullscreen_active = false


func _close_socket() -> void:
	if _socket != null:
		_socket.close()
	_socket = null


func _fail(message: String) -> void:
	_stop_resources(true)
	_set_state(State.ERROR, message)


func _set_state(value: State, message: String) -> void:
	if state == value and status_message == message:
		return
	state = value
	status_message = message
	state_changed.emit(state, status_message)
