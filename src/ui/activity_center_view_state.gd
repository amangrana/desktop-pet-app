class_name ActivityCenterViewState
extends RefCounted

const MAX_RECENT_ROWS := 5

enum Tone {
	MUTED,
	NORMAL,
	ACTIVE,
	ATTENTION,
}

enum ReminderActionMode {
	NONE,
	TURN_ON,
	TURN_OFF,
	DUE,
}

var focus_text := ""
var focus_tone := Tone.MUTED
var focus_primary_text := ""
var focus_primary_visible := false
var focus_secondary_text := ""
var focus_secondary_visible := false
var water_text := ""
var water_tone := Tone.MUTED
var water_action_mode := ReminderActionMode.NONE
var stand_text := ""
var stand_tone := Tone.MUTED
var stand_action_mode := ReminderActionMode.NONE
var quiet_text := ""
var quiet_tone := Tone.MUTED
var pending_text := ""
var pending_tone := Tone.MUTED
var recent_rows: Array[String] = []
