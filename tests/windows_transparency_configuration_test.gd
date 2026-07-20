extends SceneTree

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_expect(
		bool(ProjectSettings.get_setting(
			"display/window/size/transparent",
			false
		)),
		"The main Windows overlay must request a transparent window"
	)
	_expect(
		bool(ProjectSettings.get_setting(
			"display/window/per_pixel_transparency/allowed",
			false
		)),
		"Per-pixel window transparency must remain enabled"
	)
	_expect(
		bool(ProjectSettings.get_setting(
			"rendering/viewport/transparent_background",
			false
		)),
		"The root viewport must clear transparently"
	)
	_expect(
		ProjectSettings.get_setting(
			"rendering/environment/defaults/default_clear_color",
			Color.BLACK
		) == Color(0, 0, 0, 0),
		"The renderer clear color must have zero alpha"
	)
	_expect(
		str(ProjectSettings.get_setting(
			"rendering/gl_compatibility/driver.windows",
			""
		)) == "opengl3_angle",
		"Windows must prefer ANGLE over native OpenGL for transparent overlays"
	)
	_expect(
		bool(ProjectSettings.get_setting(
			"rendering/gl_compatibility/fallback_to_native",
			false
		)),
		"Windows must retain a native OpenGL fallback"
	)

	if _failed:
		quit(1)
		return
	print("Windows transparency configuration self-test passed.")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(
		"Windows transparency configuration self-test failed: %s"
		% message
	)
