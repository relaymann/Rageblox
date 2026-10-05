extends HBoxContainer


@export var settings_icon: Texture2D = null

signal page_button_pressed(page_name: StringName)


# Populates the main menu with buttons
func populate_page_buttons(page_names: Array, whitelisted_page_names: Array) -> void:
	# Platform navigation is keyboard/controller friendly by default.
	# Keep focus order deterministic so gamepad and keyboard users can traverse the shell.
	for page_name in page_names:
		var button := Button.new()
		button.name = page_name
		var button_text = str(page_name).replacen("_", " ")
		button.text = button_text.to_upper()
		if button.name == "Settings":
			button.icon = settings_icon
			button.text = ""
		self.add_child(button)
		if get_child_count() > 1:
			var previous: Control = get_child(get_child_count() - 2)
			previous.focus_neighbor_right = previous.get_path_to(button)
			button.focus_neighbor_left = button.get_path_to(previous)
		button.pressed.connect(_on_button_pressed.bind(button.name))
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = button_text.capitalize()
		button.set_meta("platform_nav_index", get_child_count())
		button.visible = (
			whitelisted_page_names.is_empty()
			or page_name in whitelisted_page_names
		)


# Triggers when a button gets pressed
func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()


func _on_button_pressed(button_name: StringName) -> void:
	print("Pressed %s button" % str(button_name))
	emit_signal("page_button_pressed", button_name)
