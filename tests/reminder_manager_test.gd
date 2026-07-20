extends SceneTree

const TimerManagerScript := preload("res://src/timers/timer_manager.gd")
const ReminderManagerScript := preload(
	"res://src/timers/reminder_manager.gd"
)

var _fake_now := 1000.0
var _fake_hour := 12
var _due_kinds: Array[int] = []
var _quiet_states: Array[bool] = []
var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var reminders = _new_manager()
	_expect(
		not reminders.is_enabled(TimerManagerScript.Kind.WATER),
		"health reminders must be off by default"
	)
	_expect(
		reminders.set_enabled(TimerManagerScript.Kind.WATER, true),
		"water reminder must enable"
	)
	_expect(
		reminders.remaining_seconds(TimerManagerScript.Kind.WATER)
		== ReminderManagerScript.WATER_INTERVAL_SECONDS,
		"water reminder must use its default interval"
	)

	_fake_now += ReminderManagerScript.WATER_INTERVAL_SECONDS + 0.1
	reminders._timer_for(TimerManagerScript.Kind.WATER)._process(0.0)
	_expect(
		_due_kinds == [TimerManagerScript.Kind.WATER],
		"water reminder must become due once"
	)
	_expect(
		reminders.current_due_kind() == TimerManagerScript.Kind.WATER,
		"due water reminder must wait for an explicit action"
	)

	_expect(
		reminders.snooze_due() == TimerManagerScript.Kind.WATER,
		"due reminder must snooze"
	)
	_expect(
		reminders.remaining_seconds(TimerManagerScript.Kind.WATER)
		== ReminderManagerScript.SNOOZE_SECONDS,
		"snooze must schedule ten minutes"
	)
	var snoozed_snapshot: Dictionary = reminders.snapshot()
	_fake_now += 100.0
	var restored = _new_manager()
	_expect(
		restored.restore(snoozed_snapshot),
		"enabled reminder snapshot must restore"
	)
	_expect(
		restored.remaining_seconds(TimerManagerScript.Kind.WATER)
		== ReminderManagerScript.SNOOZE_SECONDS - 100,
		"restored snooze must keep its absolute deadline"
	)

	_fake_now += ReminderManagerScript.SNOOZE_SECONDS - 100 + 0.1
	restored._timer_for(TimerManagerScript.Kind.WATER)._process(0.0)
	_expect(
		restored.is_due(TimerManagerScript.Kind.WATER),
		"restored snooze must become due"
	)
	var resume_at := _fake_now + 50.0
	_expect(
		restored.pause_kind_until(
			TimerManagerScript.Kind.WATER,
			resume_at
		) == TimerManagerScript.Kind.WATER,
		"due reminder must pause until a future time"
	)
	_expect(
		restored.is_paused_today(TimerManagerScript.Kind.WATER),
		"paused reminder must expose its state"
	)
	_fake_now = resume_at + 0.1
	restored._process(0.0)
	_expect(
		not restored.is_paused_today(TimerManagerScript.Kind.WATER),
		"daily pause must end at its deadline"
	)
	_expect(
		restored.remaining_seconds(TimerManagerScript.Kind.WATER)
		== ReminderManagerScript.WATER_INTERVAL_SECONDS,
		"resumed reminder must start a fresh interval"
	)

	_expect(
		restored.set_enabled(TimerManagerScript.Kind.STAND, true),
		"stand reminder must enable independently"
	)
	_expect(
		restored.remaining_seconds(TimerManagerScript.Kind.STAND)
		== ReminderManagerScript.STAND_INTERVAL_SECONDS,
		"stand reminder must use its own interval"
	)
	var active_stand_remaining: int = restored.remaining_seconds(
		TimerManagerScript.Kind.STAND
	)
	_expect(
		restored.set_interval_seconds(
			TimerManagerScript.Kind.STAND,
			30 * 60
		),
		"stand interval must be configurable"
	)
	_expect(
		restored.remaining_seconds(TimerManagerScript.Kind.STAND)
		== active_stand_remaining
		and restored.interval_seconds(TimerManagerScript.Kind.STAND)
		== 30 * 60,
		"changing a default interval must preserve the active schedule"
	)
	_expect(
		restored.set_snooze_seconds(5 * 60),
		"snooze duration must be configurable"
	)
	restored.start_test_reminder(TimerManagerScript.Kind.STAND, 1.0)
	_fake_now += 1.1
	restored._timer_for(TimerManagerScript.Kind.STAND)._process(0.0)
	_expect(
		restored.snooze_due() == TimerManagerScript.Kind.STAND
		and restored.remaining_seconds(TimerManagerScript.Kind.STAND)
		== 5 * 60,
		"configured snooze duration must apply to due reminders"
	)
	_fake_now += 5 * 60 + 0.1
	restored._timer_for(TimerManagerScript.Kind.STAND)._process(0.0)
	_expect(
		restored.disable_due() == TimerManagerScript.Kind.STAND
		and not restored.is_enabled(TimerManagerScript.Kind.STAND)
		and not restored.is_due(TimerManagerScript.Kind.STAND),
		"stopping a due reminder must disable that reminder type"
	)
	restored.set_enabled(TimerManagerScript.Kind.STAND, true)

	_fake_hour = 23
	_expect(
		restored.set_quiet_hours(true, 22, 8)
		and restored.is_quiet_now(),
		"cross-midnight quiet hours must activate at night"
	)
	_expect(
		_quiet_states == [true],
		"entering quiet hours must emit its state"
	)
	var configured_snapshot: Dictionary = restored.snapshot()
	_fake_hour = 9
	_fake_now += 2.0
	restored._next_boundary_check_unix = 0.0
	restored._process(0.0)
	_expect(
		not restored.is_quiet_now()
		and _quiet_states == [true, false],
		"leaving quiet hours must emit after the local hour changes"
	)
	var configured_restore = _new_manager()
	_expect(
		configured_restore.restore(configured_snapshot),
		"configured reminder preferences must restore"
	)
	_expect(
		configured_restore.interval_seconds(TimerManagerScript.Kind.STAND)
		== 30 * 60
		and configured_restore.snooze_seconds() == 5 * 60
		and configured_restore.quiet_hours_enabled(),
		"interval, snooze, and quiet-hour preferences must persist"
	)
	restored.set_enabled(TimerManagerScript.Kind.WATER, false)
	_expect(
		restored.is_enabled(TimerManagerScript.Kind.STAND),
		"disabling water must not disable stand"
	)

	if _failed:
		quit(1)
		return
	print("Reminder manager self-test passed.")
	quit(0)


func _new_manager():
	var manager = ReminderManagerScript.new()
	manager.time_source = func() -> float: return _fake_now
	manager.local_hour_source = func() -> int: return _fake_hour
	manager.reminder_due.connect(_due_kinds.append)
	manager.quiet_state_changed.connect(_quiet_states.append)
	root.add_child(manager)
	return manager


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Reminder manager self-test failed: %s" % message)
