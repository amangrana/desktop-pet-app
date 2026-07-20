class_name WindowsCredentialStore
extends Node

signal read_completed(secret: String, success: bool, error: String)
signal write_completed(success: bool, error: String)
signal delete_completed(success: bool, error: String)

enum Operation {
	NONE,
	READ,
	WRITE,
	DELETE,
}

const HELPER_RESOURCE_PATH := (
	"res://platform/windows/credential_helper/"
	+ "DesktopPetCredentialHelper.exe"
)
const PROTOCOL_PREFIX := "DPC1"
const PORT_MIN := 49152
const PORT_MAX := 65535
const PORT_ATTEMPTS := 24
const OPERATION_TIMEOUT_SECONDS := 4.0

var _server: TCPServer
var _peer: StreamPeerTCP
var _helper_pid := -1
var _session_token := ""
var _operation := Operation.NONE
var _pending_secret := ""
var _response_buffer := ""
var _remaining_seconds := 0.0


func _ready() -> void:
	set_process(false)


func read_secret(target: String) -> bool:
	return _start_operation(Operation.READ, target, "")


func write_secret(target: String, secret: String) -> bool:
	if secret.is_empty():
		return false
	return _start_operation(Operation.WRITE, target, secret)


func delete_secret(target: String) -> bool:
	return _start_operation(Operation.DELETE, target, "")


func is_busy() -> bool:
	return _operation != Operation.NONE


func _process(delta: float) -> void:
	_remaining_seconds -= delta
	if _remaining_seconds <= 0.0:
		_finish(false, "", "helper_timeout")
		return
	if _peer == null:
		if _server != null and _server.is_connection_available():
			_peer = _server.take_connection()
		return
	if _peer.get_status() == StreamPeerTCP.STATUS_ERROR:
		_finish(false, "", "helper_connection_failed")
		return
	var available := _peer.get_available_bytes()
	if available <= 0:
		return
	_response_buffer += _peer.get_utf8_string(available)
	while "\n" in _response_buffer:
		var newline_index := _response_buffer.find("\n")
		var line := _response_buffer.substr(0, newline_index).strip_edges()
		_response_buffer = _response_buffer.substr(newline_index + 1)
		_handle_response(line)
		if _operation == Operation.NONE:
			return


func _start_operation(
	operation: Operation,
	target: String,
	secret: String
) -> bool:
	if is_busy() or OS.get_name() != "Windows":
		return false
	var safe_target := target.strip_edges()
	if not safe_target.begins_with("DesktopPet."):
		return false
	var helper_path := _resolve_helper_path()
	if not FileAccess.file_exists(helper_path):
		return false

	_server = TCPServer.new()
	var port := _listen_on_available_port()
	if port <= 0:
		_clear_resources()
		return false

	_operation = operation
	_pending_secret = secret
	_session_token = _create_session_token()
	var arguments := PackedStringArray([
		"--port",
		str(port),
		"--session",
		_session_token,
		"--target",
		safe_target,
		"--operation",
		_operation_name(operation),
	])
	_helper_pid = OS.create_process(helper_path, arguments, false)
	if _helper_pid <= 0:
		_clear_resources()
		return false
	_remaining_seconds = OPERATION_TIMEOUT_SECONDS
	set_process(true)
	return true


func _handle_response(line: String) -> void:
	var parts := line.split("|", true, 3)
	if (
		parts.size() != 4
		or parts[0] != PROTOCOL_PREFIX
		or parts[1] != _session_token
	):
		return
	var response_kind := str(parts[2])
	var response_value := str(parts[3])
	if response_kind == "READY" and _operation == Operation.WRITE:
		_send_pending_secret()
		return
	if response_kind == "ERROR":
		_finish(false, "", response_value)
		return
	if _operation == Operation.READ:
		if response_kind == "EMPTY":
			_finish(true, "", "")
		elif response_kind == "VALUE":
			var decoded := Marshalls.base64_to_raw(response_value)
			_finish(true, decoded.get_string_from_utf8(), "")
		return
	if response_kind == "OK":
		_finish(true, "", "")


func _send_pending_secret() -> void:
	if _peer == null or _pending_secret.is_empty():
		_finish(false, "", "missing_secret")
		return
	var encoded := Marshalls.raw_to_base64(
		_pending_secret.to_utf8_buffer()
	)
	_peer.put_data(
		(
			"%s|%s|SECRET|%s\n"
			% [PROTOCOL_PREFIX, _session_token, encoded]
		).to_utf8_buffer()
	)


func _finish(success: bool, secret: String, error: String) -> void:
	var completed_operation := _operation
	_clear_resources()
	match completed_operation:
		Operation.READ:
			read_completed.emit(secret, success, error)
		Operation.WRITE:
			write_completed.emit(success, error)
		Operation.DELETE:
			delete_completed.emit(success, error)


func _clear_resources() -> void:
	set_process(false)
	if _peer != null:
		_peer.disconnect_from_host()
	_peer = null
	if _server != null:
		_server.stop()
	_server = null
	if _helper_pid > 0 and OS.is_process_running(_helper_pid):
		OS.kill(_helper_pid)
	_helper_pid = -1
	_session_token = ""
	_pending_secret = ""
	_response_buffer = ""
	_remaining_seconds = 0.0
	_operation = Operation.NONE


func _exit_tree() -> void:
	_clear_resources()


func _listen_on_available_port() -> int:
	for _attempt in PORT_ATTEMPTS:
		var port := randi_range(PORT_MIN, PORT_MAX)
		if _server.listen(port, "127.0.0.1") == OK:
			return port
	return 0


func _resolve_helper_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path(HELPER_RESOURCE_PATH)
	return OS.get_executable_path().get_base_dir().path_join(
		"DesktopPetCredentialHelper.exe"
	)


func _create_session_token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


func _operation_name(operation: Operation) -> String:
	match operation:
		Operation.READ:
			return "read"
		Operation.WRITE:
			return "write"
		Operation.DELETE:
			return "delete"
	return ""
