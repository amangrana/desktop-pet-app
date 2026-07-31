class_name PetNoteSource
extends Node

signal card_ready(card: Dictionary)

const PetNoteCardScript := preload(
	"res://src/checkins/pet_note_card.gd"
)

var source_id := ""


func _init(next_source_id := "") -> void:
	source_id = str(next_source_id).strip_edges()


func publish_card(data: Dictionary) -> bool:
	var source_card: Dictionary = data.duplicate(true)
	if str(source_card.get("source", "")).strip_edges().is_empty():
		source_card["source"] = source_id
	var normalized := PetNoteCardScript.normalize(source_card)
	if normalized.is_empty():
		return false
	if (
		not source_id.is_empty()
		and str(normalized.get("source", "")) != source_id
	):
		return false
	card_ready.emit(normalized)
	return true
