class_name PetRegistry
extends RefCounted

const PETS_ROOT := "res://assets/pets"
const DEFINITION_FILENAME := "pet.tres"


static func discover() -> Array[PetDefinition]:
	var definitions: Array[PetDefinition] = []
	var seen_ids: Dictionary = {}
	var directory := DirAccess.open(PETS_ROOT)

	if directory == null:
		push_error("Pet directory could not be opened: %s" % PETS_ROOT)
		return definitions

	var folder_names := directory.get_directories()
	folder_names.sort()

	for folder_name in folder_names:
		var definition_path := (
			"%s/%s/%s" % [PETS_ROOT, folder_name, DEFINITION_FILENAME]
		)
		if not ResourceLoader.exists(definition_path):
			continue

		var definition := load(definition_path) as PetDefinition
		if definition == null:
			push_warning("Pet definition could not be loaded: %s" % definition_path)
			continue
		if not definition.is_configured():
			push_warning("Pet definition is incomplete: %s" % definition_path)
			continue
		if seen_ids.has(definition.pet_id):
			push_warning("Duplicate pet id ignored: %s" % definition.pet_id)
			continue
		for error in definition.behavior_validation_errors():
			push_warning(
				"Optional pet behavior ignored in %s: %s"
				% [definition_path, error]
			)
		for error in definition.dialogue_validation_errors():
			push_warning(
				"Optional pet dialogue ignored in %s: %s"
				% [definition_path, error]
			)

		seen_ids[definition.pet_id] = true
		definitions.append(definition)

	definitions.sort_custom(
		func(left: PetDefinition, right: PetDefinition) -> bool:
			if left.sort_order != right.sort_order:
				return left.sort_order < right.sort_order
			return left.display_name.naturalnocasecmp_to(right.display_name) < 0
	)
	return definitions


static func find_by_id(
	definitions: Array[PetDefinition],
	pet_id: StringName
) -> PetDefinition:
	for definition in definitions:
		if definition.pet_id == pet_id:
			return definition
	return null
