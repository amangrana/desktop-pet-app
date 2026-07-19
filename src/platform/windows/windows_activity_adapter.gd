class_name WindowsActivityAdapter
extends Node

signal aggregate_received(keyboard_count: int, mouse_count: int)
signal state_changed(state: State, message: String)

enum State {
	STOPPED,
	STARTING,
	RUNNING,
	ERROR,
}

const HELPER_RESOURCE_PATH := (
	"res://platform/windows/activity_helper/DesktopPetActivityHelper.exe"
)
const PROTOCOL_PREFIX := "DPA1"
const PORT_MIN := 49152
const PORT_MAX := 65535
const PORT_ATTEMPTS := 24
const STARTUP_TIMEOUT_SECONDS := 3.0

var test_batch_mode := false
var state := State.STOPPED
var status_message := "stopped"

var _socket: PacketPeerUDP
var _helper_pid := -1
var _session_token := ""
var _startup_remaining := 0.0
var _received_test_batch := false


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
			_fail("helper startup timed out")
			return

	if _helper_pid > 0 and not OS.is_process_running(_helper_pid):
		_helper_pid = -1
		if test_batch_mode and _received_test_batch:
			_close_socket()
			_set_state(State.STOPPED, "test completed")
		else:
			_fail("helper stopped unexpectedly")


func start() -> bool:
	if state == State.STARTING or state == State.RUNNING:
		return true
	if OS.get_name() != "Windows":
		_fail("Windows activity sensing is only available on Windows")
		return false

	_stop_resources()
	_socket = PacketPeerUDP.new()
	var port := _bind_local_port()
	if port < 0:
		_fail("could not open a local activity port")
		return false

	var helper_path := _resolve_helper_path()
	if not FileAccess.file_exists(helper_path):
		_fail("activity helper is missing")
		return false

	_session_token = _create_session_token()
	_received_test_batch = false
	var arguments := PackedStringArray([
		"--port",
		str(port),
		"--token",
		_session_token,
		"--parent-pid",
		str(OS.get_process_id()),
	])
	if test_batch_mode:
		arguments.append("--test-batch")

	_helper_pid = OS.create_process(helper_path, arguments, false)
	if _helper_pid <= 0:
		_fail("could not start the activity helper")
		return false

	_startup_remaining = STARTUP_TIMEOUT_SECONDS
	set_process(true)
	_set_state(State.STARTING, "starting Windows activity sensing")
	return true


func stop() -> void:
	_stop_resources()
	_set_state(State.STOPPED, "stopped")


func _exit_tree() -> void:
	_stop_resources()


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
			_set_state(State.RUNNING, "Windows activity sensing is active")
		"BATCH":
			if parts.size() != 5:
				return
			var keyboard_count := maxi(0, int(parts[3]))
			var mouse_count := maxi(0, int(parts[4]))
			if keyboard_count == 0 and mouse_count == 0:
				return
			_received_test_batch = true
			aggregate_received.emit(keyboard_count, mouse_count)
		"ERROR":
			var code := parts[3] if parts.size() >= 4 else "unknown"
			_fail("activity helper error: %s" % code)


func _resolve_helper_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path(HELPER_RESOURCE_PATH)
	return OS.get_executable_path().get_base_dir().path_join(
		"DesktopPetActivityHelper.exe"
	)


func _create_session_token() -> String:
	var random_bytes := Crypto.new().generate_random_bytes(16)
	return random_bytes.hex_encode()


func _stop_resources() -> void:
	set_process(false)
	if _helper_pid > 0 and OS.is_process_running(_helper_pid):
		OS.kill(_helper_pid)
	_helper_pid = -1
	_close_socket()
	_session_token = ""
	_startup_remaining = 0.0


func _close_socket() -> void:
	if _socket != null:
		_socket.close()
	_socket = null


func _fail(message: String) -> void:
	_stop_resources()
	_set_state(State.ERROR, message)


func _set_state(value: State, message: String) -> void:
	if state == value and status_message == message:
		return
	state = value
	status_message = message
	state_changed.emit(state, status_message)
