extends SceneTree

const SingleInstanceCoordinatorScript := preload(
	"res://src/platform/single_instance_coordinator.gd"
)

var _failed := false
var _activation_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var primary = SingleInstanceCoordinatorScript.new()
	primary.activation_requested.connect(func() -> void:
		_activation_count += 1
	)
	root.add_child(primary)
	_expect(
		primary.start(0)
		== SingleInstanceCoordinatorScript.StartResult.PRIMARY,
		"the first coordinator must own its loopback port"
	)
	var port := primary.get_listening_port()
	_expect(port > 0, "the first coordinator must expose its bound test port")

	var invalid_sender := PacketPeerUDP.new()
	invalid_sender.set_dest_address("127.0.0.1", port)
	invalid_sender.put_packet("DPSI1|desktop-pet|INVALID".to_ascii_buffer())
	invalid_sender.close()
	await process_frame
	_expect(
		_activation_count == 0,
		"unrecognized local packets must not activate the app"
	)

	var secondary = SingleInstanceCoordinatorScript.new()
	root.add_child(secondary)
	_expect(
		secondary.start(port)
		== SingleInstanceCoordinatorScript.StartResult.SECONDARY,
		"a second coordinator must not claim the same port"
	)
	var deadline := Time.get_ticks_msec() + 1000
	while _activation_count == 0 and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	_expect(
		_activation_count == 1,
		"the second coordinator must request activation from the first"
	)

	secondary.queue_free()
	primary.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("Single-instance coordinator self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Single-instance coordinator self-test failed: %s" % message)
