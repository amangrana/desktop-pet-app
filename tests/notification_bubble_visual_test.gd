extends SceneTree

const MainScene := preload("res://scenes/Main.tscn")

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main._show_notification(
		"Short informational message.",
		main.INFORMATION_NOTIFICATION_SECONDS
	)
	_expect(
		is_equal_approx(
			main.notification_timer.wait_time,
			2.5
		)
		and not main.notification_actions.visible,
		"ordinary informational bubbles must auto-close after 2.5 seconds"
	)

	for scale_factor in [0.75, 1.0, 2.0, 3.0]:
		main._apply_scale(scale_factor, false)
		main._show_notification(
			"Focus complete! Start your break.",
			30.0
		)
		await process_frame
		var font_height: float = main.notification_label.get_theme_font(
			"font"
		).get_height(
			main.notification_label.get_theme_font_size("font_size")
		)
		_expect(
			main.notification_panel.visible
			and not main.notification_label.text.is_empty()
			and main.notification_label.size.y >= font_height,
			(
				"plain notification text must have at least one visible "
				+ "font line at %s%% scale (label=%s font_height=%s)"
				% [
					roundi(scale_factor * 100.0),
					main.notification_label.size,
					font_height,
				]
			)
		)
		_expect_bubble_inside_window_shape(
			main,
			"plain notification",
			scale_factor
		)

		main._show_actionable_notification(
			main.TimerManagerScript.Kind.WATER,
			"Time for a gentle water break."
		)
		await process_frame
		_expect(
			main.notification_label.size.y >= font_height
			and main.notification_actions.size.y
			>= 28.0 * scale_factor
			and main.notification_done_button.visible
			and main.notification_snooze_button.visible
			and main.notification_stop_button.visible
			and main.notification_stop_button.text == "Turn off",
			(
				"reminder bubble must allocate visible message and button "
				+ "rows at %s%% scale"
				% roundi(scale_factor * 100.0)
			)
		)
		_expect_bubble_inside_window_shape(
			main,
			"reminder",
			scale_factor
		)

		main._show_ambient_card("Planning starts soon.", 10)
		await process_frame
		await process_frame
		_expect(
			main.notification_label.size.y >= font_height
			and main.notification_done_button.visible
			and not main.notification_snooze_button.visible
			and not main.notification_stop_button.visible,
			(
				"Pet Notes bubble must allocate a visible message row "
				+ "above its countdown button at %s%% scale"
				% roundi(scale_factor * 100.0)
			)
		)
		_expect_bubble_inside_window_shape(
			main,
			"Pet Notes",
			scale_factor
		)

	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--capture-notification="):
			continue
		main._apply_scale(1.0, false)
		main._show_confirmation_notification(
			"Break complete! Ready for another focus session?",
			main.COMPLETION_NOTIFICATION_SECONDS
		)
		await process_frame
		await RenderingServer.frame_post_draw
		var output_path := argument.trim_prefix(
			"--capture-notification="
		)
		root.get_texture().get_image().save_png(output_path)

	main.shutting_down = true
	if _failed:
		quit(1)
		return
	print("Notification bubble visual-layout test passed.")
	quit()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)


func _expect_bubble_inside_window_shape(
	main,
	bubble_name: String,
	scale_factor: float
) -> void:
	var shape: PackedVector2Array = (
		main.get_window().mouse_passthrough_polygon
	)
	var rect := Rect2(
		main.notification_panel.position,
		main.notification_panel.size
	).grow(-1.0)
	for point in [
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.end,
		rect.position + Vector2(0, rect.size.y),
	]:
		_expect(
			Geometry2D.is_point_in_polygon(point, shape),
			(
				"%s bubble must remain inside the visible window shape "
				+ "at %s%% scale"
			) % [
				bubble_name,
				roundi(scale_factor * 100.0),
			]
		)
