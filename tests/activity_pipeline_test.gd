extends SceneTree

const ActivityStatsScript := preload("res://src/Activity/activity_stats.gd")
const InputActivityMonitorScript := preload(
	"res://src/Activity/input_activity_monitor.gd"
)

var _monitor
var _stats
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_monitor = InputActivityMonitorScript.new()
	_monitor.flush_interval_seconds = 0.05
	root.add_child(_monitor)

	_stats = ActivityStatsScript.new()
	_monitor.activity_batch_ready.connect(_stats.record)

	_monitor.submit_aggregate(50, 50)
	await create_timer(0.08).timeout
	_expect(_stats.is_empty(), "disabled monitor must ignore activity")

	_monitor.set_listening(true)
	_monitor.submit_aggregate(12, 3)
	_monitor.submit_aggregate(8, 2)
	await create_timer(0.08).timeout
	_expect(_stats.keyboard_count == 20, "keyboard batches must aggregate")
	_expect(_stats.mouse_count == 5, "mouse batches must aggregate")

	_monitor.submit_aggregate(99, 99)
	_monitor.set_listening(false)
	await create_timer(0.08).timeout
	_expect(
		_stats.keyboard_count == 20 and _stats.mouse_count == 5,
		"pausing must discard pending activity"
	)

	_stats.clear()
	_expect(_stats.is_empty(), "clear must reset session counts")

	if _failed:
		quit(1)
		return
	print("Activity pipeline self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Activity pipeline self-test failed: %s" % message)
