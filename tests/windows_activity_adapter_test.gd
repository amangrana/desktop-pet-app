extends SceneTree

const WindowsActivityAdapterScript := preload(
	"res://src/platform/windows/windows_activity_adapter.gd"
)

var _adapter
var _keyboard_count := 0
var _mouse_count := 0
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_adapter = WindowsActivityAdapterScript.new()
	root.add_child(_adapter)

	_expect(_adapter.start(), "production adapter must start the helper")
	await create_timer(0.5).timeout
	_expect(
		_adapter.state == WindowsActivityAdapterScript.State.RUNNING,
		"helper must register Windows Raw Input and report ready"
	)
	_adapter.stop()
	_adapter.queue_free()
	await process_frame

	_adapter = WindowsActivityAdapterScript.new()
	_adapter.test_batch_mode = true
	_adapter.aggregate_received.connect(_handle_aggregate)
	root.add_child(_adapter)

	_expect(_adapter.start(), "adapter must start the helper")
	await create_timer(1.0).timeout
	_expect(_keyboard_count == 12, "helper keyboard batch must arrive")
	_expect(_mouse_count == 3, "helper mouse batch must arrive")

	_adapter.stop()
	if _failed:
		quit(1)
		return

	print("Windows activity adapter self-test passed.")
	quit(0)


func _handle_aggregate(keyboard_count: int, mouse_count: int) -> void:
	_keyboard_count += keyboard_count
	_mouse_count += mouse_count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Windows activity adapter self-test failed: %s" % message)
