extends HBoxContainer

signal slot_pressed(slot: int)

func setup(active_slot: int = 0) -> void:
	for child in get_children():
		child.queue_free()
	for i in range(5):
		var button := Button.new()
		button.custom_minimum_size = Vector2(48, 40)
		button.text = str(i + 1)
		button.tooltip_text = "Outfit slot %d" % (i + 1)
		button.pressed.connect(slot_pressed.emit.bind(i))
		add_child(button)
		if i == active_slot:
			button.grab_focus()
