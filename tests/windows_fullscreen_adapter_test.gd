extends SceneTree

const WindowsFullscreenAdapterScript := preload(
	"res://src/platform/windows/windows_fullscreen_adapter.gd"
)

var _failed := false
var _received := false
var _reported := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _expect_helper_state(1, true)
	await _expect_helper_state(0, false)

	if _failed:
		quit(1)
		return
	print("Windows fullscreen adapter self-test passed.")
	quit(0)


func _expect_helper_state(test_state: int, expected: bool) -> void:
	var adapter = WindowsFullscreenAdapterScript.new()
	adapter.test_reported_state = test_state
	_received = false
	_reported = false
	adapter.fullscreen_changed.connect(func(active: bool) -> void:
		_received = true
		_reported = active
	)
	root.add_child(adapter)
	_expect(
		adapter.helper_exists() and adapter.start(),
		"the packaged fullscreen helper must start in test mode"
	)
	var deadline := Time.get_ticks_msec() + 4000
	while not _received and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	_expect(
		_received and _reported == expected,
		"the helper must report only the requested anonymous boolean state"
	)
	adapter.stop()
	adapter.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Windows fullscreen adapter self-test failed: %s" % message)
