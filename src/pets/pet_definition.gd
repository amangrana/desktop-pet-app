class_name PetDefinition
extends Resource

@export_category("Identity")
@export var pet_id: StringName
@export var display_name := ""
@export var species := ""
@export_multiline var description := ""
@export var sort_order := 0

@export_category("Visuals")
@export var idle_texture: Texture2D
@export var click_texture: Texture2D
@export var keyboard_texture: Texture2D
@export var mouse_texture: Texture2D
@export var display_size := Vector2(224, 224)
@export var visual_offset := Vector2.ZERO

@export_category("Interaction Shape")
@export var interaction_polygon := PackedVector2Array([
	Vector2(-120, -132),
	Vector2(120, -132),
	Vector2(126, -28),
	Vector2(126, 116),
	Vector2(-126, 116),
	Vector2(-126, -28),
])

@export_category("Quick Actions")
@export var focus_hotspot_centers := PackedVector2Array()
@export_range(0.0, 64.0, 1.0) var focus_hotspot_radius := 0.0

@export_category("Click Effect")
@export var show_click_heart := true
@export var heart_position := Vector2(78, -86)
@export var heart_scale := 1.0
@export var heart_color := Color("#F28BA8")

@export_category("Motion")
@export var idle_bob_amount := 1.5
@export var breathing_amount := 0.008
@export var keyboard_lift := 5.0
@export var mouse_drop := 6.0
@export var click_jump := 12.0
@export var random_idle_interval_min := 4.0
@export var random_idle_interval_max := 8.0


func is_configured() -> bool:
	return (
		not String(pet_id).is_empty()
		and not display_name.is_empty()
		and idle_texture != null
		and display_size.x > 0.0
		and display_size.y > 0.0
		and interaction_polygon.size() >= 3
	)


func texture_for_action(action: StringName) -> Texture2D:
	match action:
		&"click":
			return click_texture if click_texture != null else idle_texture
		&"keyboard":
			return keyboard_texture if keyboard_texture != null else idle_texture
		&"mouse":
			return mouse_texture if mouse_texture != null else idle_texture
		_:
			return idle_texture
