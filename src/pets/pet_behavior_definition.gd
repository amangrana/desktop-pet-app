class_name PetBehaviorDefinition
extends Resource

enum Trigger {
	RANDOM_IDLE,
	CLICK,
	KEYBOARD,
	MOUSE,
	FOCUS,
	REMINDER,
}

enum Playback {
	ONCE,
	LOOP,
	PING_PONG,
}

@export_category("Identity")
@export var behavior_id: StringName
@export var trigger := Trigger.RANDOM_IDLE

@export_category("Frames")
@export var frames: Array[Texture2D] = []
@export_range(1.0, 30.0, 0.5) var frames_per_second := 6.0
@export var playback := Playback.ONCE
@export_range(0.0, 30.0, 0.05) var play_duration_seconds := 0.0

@export_category("Selection")
@export_range(0.01, 100.0, 0.01) var weight := 1.0
@export_range(0.0, 3600.0, 0.5) var cooldown_seconds := 0.0
@export var allowed_during_focus := false


func is_configured() -> bool:
	if String(behavior_id).is_empty():
		return false
	if trigger < Trigger.RANDOM_IDLE or trigger > Trigger.REMINDER:
		return false
	if frames.is_empty() or frames_per_second <= 0.0:
		return false
	if trigger == Trigger.RANDOM_IDLE and weight <= 0.0:
		return false
	for frame in frames:
		if frame == null:
			return false
	return true


func natural_duration_seconds() -> float:
	if frames.is_empty() or frames_per_second <= 0.0:
		return 0.0
	return float(_sequence_step_count()) / frames_per_second


func runtime_duration_seconds() -> float:
	if play_duration_seconds > 0.0:
		return play_duration_seconds
	return natural_duration_seconds()


func texture_at(elapsed_seconds: float) -> Texture2D:
	if frames.is_empty():
		return null
	if frames.size() == 1 or frames_per_second <= 0.0:
		return frames[0]

	var step := maxi(0, floori(elapsed_seconds * frames_per_second))
	var frame_index := 0
	match playback:
		Playback.LOOP:
			frame_index = step % frames.size()
		Playback.PING_PONG:
			var period := frames.size() * 2 - 2
			var period_index := step % period
			frame_index = (
				period_index
				if period_index < frames.size()
				else period - period_index
			)
		_:
			frame_index = mini(step, frames.size() - 1)
	return frames[frame_index]


func _sequence_step_count() -> int:
	if playback == Playback.PING_PONG and frames.size() > 1:
		return frames.size() * 2 - 2
	return frames.size()
