class_name SingleInstanceCoordinator
extends Node

signal activation_requested

enum StartResult {
	PRIMARY,
	SECONDARY,
}

const DEFAULT_PORT := 48231
const LOOPBACK_ADDRESS := "127.0.0.1"
const ACTIVATE_PACKET := "DPSI1|desktop-pet|ACTIVATE"

var _listener: PacketPeerUDP
var _listening_port := -1


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if _listener == null:
		return

	var should_activate := false
	while _listener.get_available_packet_count() > 0:
		var packet := _listener.get_packet()
		if _listener.get_packet_error() != OK:
			continue
		if _listener.get_packet_ip() != LOOPBACK_ADDRESS:
			continue
		if packet.get_string_from_ascii() == ACTIVATE_PACKET:
			should_activate = true

	if should_activate:
		activation_requested.emit()


func start(port := DEFAULT_PORT) -> StartResult:
	stop()
	var candidate := PacketPeerUDP.new()
	if candidate.bind(port, LOOPBACK_ADDRESS) == OK:
		_listener = candidate
		_listening_port = _listener.get_local_port()
		set_process(true)
		return StartResult.PRIMARY

	_send_activation_request(port)
	return StartResult.SECONDARY


func stop() -> void:
	set_process(false)
	if _listener != null:
		_listener.close()
	_listener = null
	_listening_port = -1


func get_listening_port() -> int:
	return _listening_port


func _exit_tree() -> void:
	stop()


func _send_activation_request(port: int) -> void:
	var sender := PacketPeerUDP.new()
	if sender.set_dest_address(LOOPBACK_ADDRESS, port) == OK:
		sender.put_packet(ACTIVATE_PACKET.to_ascii_buffer())
	sender.close()
